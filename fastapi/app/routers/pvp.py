import copy
import random
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_, func
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import SessionLocal, get_db
from ..errors import ApiError, ok
from ..models import (
    Friend,
    MatchHistory,
    MatchQueue,
    Notification,
    Question,
    Room,
    User,
)
from ..pvp_realtime import publish_queue_state, publish_room
from ..schemas import PvpAnswerIn

router = APIRouter()
QUESTION_COUNT = 10
QUESTION_SECONDS = 15
QUESTION_POINTS = 10
ROOM_INACTIVITY_TIMEOUT = timedelta(minutes=2)
ACTIVE_ROOM_STATUSES = ("waiting", "playing")


def _new_room_questions(db: Session) -> list[dict]:
    questions = db.query(Question).filter(Question.is_active.is_(True)).all()
    valid_questions = [
        question for question in questions
        if question.options and 2 <= len(question.options) <= 8
        and 0 <= question.correct_index < len(question.options)
    ]
    random.shuffle(valid_questions)
    if len(valid_questions) < QUESTION_COUNT:
        raise ApiError(
            400,
            "VALIDATION",
            f"Cần ít nhất {QUESTION_COUNT} câu hỏi hợp lệ để bắt đầu trận đấu.",
        )

    snapshots = []
    for question in valid_questions[:QUESTION_COUNT]:
        order = list(range(len(question.options)))
        random.shuffle(order)
        snapshots.append({
            "id": question.id,
            "content": question.content,
            "options": [question.options[index] for index in order],
            "correctIndex": order.index(question.correct_index),
            "answers": {},
        })
    return snapshots


def _expire_stale_room(db: Session, room: Room, now: datetime) -> bool:
    last_activity = (
        room.created_at if room.status == "waiting" else room.question_start_time
    )
    if room.status not in ACTIVE_ROOM_STATUSES:
        return False
    if last_activity is not None and last_activity.tzinfo is not None:
        last_activity = last_activity.astimezone(timezone.utc).replace(tzinfo=None)
    if (
        last_activity is not None
        and now - last_activity < ROOM_INACTIVITY_TIMEOUT
    ):
        return False

    room.status = "cancelled"
    room.question_start_time = None
    db.query(Notification).filter(
        Notification.type == "match_invite",
        Notification.ref_id == room.id,
    ).update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    _publish_room(db, room)
    return True


def _active_room(db: Session, uid: str) -> Room | None:
    room = (
        db.query(Room)
        .filter(
            or_(Room.host_id == uid, Room.guest_id == uid),
            Room.status.in_(ACTIVE_ROOM_STATUSES),
        )
        .order_by(Room.created_at.desc())
        .with_for_update(skip_locked=True)
        .first()
    )
    if room is not None and _expire_stale_room(db, room, datetime.utcnow()):
        return None
    return room


def cleanup_expired_rooms() -> None:
    db = SessionLocal()
    try:
        rooms = (
            db.query(Room)
            .filter(Room.status.in_(ACTIVE_ROOM_STATUSES))
            .with_for_update(skip_locked=True)
            .all()
        )
        now = datetime.utcnow()
        for room in rooms:
            _expire_stale_room(db, room, now)
    finally:
        db.close()


def _create_history(db: Session, room: Room) -> MatchHistory:
    history = MatchHistory(
        room_id=room.id,
        player1_id=room.host_id,
        player2_id=room.guest_id,
        score1=0,
        score2=0,
        details=[
            {
                "questionId": question["id"],
                "hostSelectedIndex": None,
                "guestSelectedIndex": None,
                "hostCorrect": False,
                "guestCorrect": False,
            }
            for question in room.question_ids
        ],
    )
    db.add(history)
    return history


def _sync_history_question(history: MatchHistory, room: Room, index: int) -> None:
    details = list(history.details or [])
    answers = room.question_ids[index].get("answers", {})
    detail = dict(details[index])
    host_answer = answers.get(room.host_id)
    guest_answer = answers.get(room.guest_id)
    detail["hostSelectedIndex"] = (
        host_answer.get("selectedIndex") if host_answer else None
    )
    detail["guestSelectedIndex"] = (
        guest_answer.get("selectedIndex") if guest_answer else None
    )
    detail["hostCorrect"] = bool(host_answer and host_answer["isCorrect"])
    detail["guestCorrect"] = bool(guest_answer and guest_answer["isCorrect"])
    details[index] = detail
    history.details = details


def _advance_room(room: Room, history: MatchHistory, now: datetime) -> None:
    index = room.current_question_index
    if index < len(room.question_ids):
        _sync_history_question(history, room, index)

    next_index = index + 1
    if next_index < len(room.question_ids):
        room.current_question_index = next_index
        room.question_start_time = now
        return

    room.status = "finished"
    room.question_start_time = None
    history.score1 = room.host_score or 0
    history.score2 = room.guest_score or 0
    if history.score1 > history.score2:
        history.winner_id = room.host_id
    elif history.score2 > history.score1:
        history.winner_id = room.guest_id
    else:
        history.winner_id = None


def _advance_if_due(room: Room, history: MatchHistory | None, now: datetime) -> None:
    if room.status != "playing" or room.question_start_time is None or history is None:
        return
    question = room.question_ids[room.current_question_index]
    answers = question.get("answers", {})
    both_answered = room.host_id in answers and room.guest_id in answers
    timed_out = now >= room.question_start_time + timedelta(seconds=QUESTION_SECONDS)
    if both_answered or timed_out:
        _advance_room(room, history, now)


def _room_payload(db: Session, room: Room, uid: str) -> dict:
    host = db.query(User).filter(User.uid == room.host_id).first()
    guest = db.query(User).filter(User.uid == room.guest_id).first()
    payload = {
        "id": room.id,
        "status": room.status,
        "hostId": room.host_id,
        "guestId": room.guest_id,
        "hostName": host.display_name if host else "Người chơi",
        "guestName": guest.display_name if guest else "Người chơi",
        "hostScore": room.host_score or 0,
        "guestScore": room.guest_score or 0,
        "questionIndex": room.current_question_index,
        "questionCount": len(room.question_ids or []),
        "questionSeconds": QUESTION_SECONDS,
        "questionStartTime": (
            room.question_start_time.replace(tzinfo=timezone.utc).isoformat()
            if room.question_start_time else None
        ),
    }
    if room.status == "playing" and room.current_question_index < len(room.question_ids):
        question = room.question_ids[room.current_question_index]
        answers = question.get("answers", {})
        opponent_id = room.guest_id if uid == room.host_id else room.host_id
        payload.update({
            "question": {
                "id": question["id"],
                "content": question["content"],
                "options": question["options"],
            },
            "myAnswered": uid in answers,
            "opponentAnswered": opponent_id in answers,
        })
    elif room.status == "finished":
        payload["winnerId"] = room.match_history.winner_id if room.match_history else None
    return payload


def _publish_room(db: Session, room: Room) -> None:
    payload = _room_payload(db, room, room.host_id)
    answers = {}
    if (
        room.status == "playing"
        and room.current_question_index < len(room.question_ids or [])
    ):
        question = room.question_ids[room.current_question_index]
        answers = question.get("answers", {})
    payload.pop("myAnswered", None)
    payload.pop("opponentAnswered", None)
    payload["answeredUids"] = list(answers.keys())

    created_at = room.created_at
    if created_at is not None and created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    invitation = None
    if room.guest_id is not None:
        invitation = {
            "roomId": room.id,
            "notificationId": room.id,
            "hostId": room.host_id,
            "hostName": payload["hostName"],
            "guestId": room.guest_id,
            "createdAt": created_at,
        }
    publish_room(room.id, payload, invitation)


def _require_player(room: Room, uid: str) -> None:
    if uid not in (room.host_id, room.guest_id):
        raise ApiError(403, "FORBIDDEN", "Bạn không tham gia trận đấu này.")


@router.post("/queue")
def join_queue(user: CurrentUser = Depends(get_current_user),
               db: Session = Depends(get_db)):
    account = (
        db.query(User).filter(User.uid == user.uid).with_for_update().first()
    )
    if account is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy hồ sơ người chơi.")

    active_room = _active_room(db, user.uid)
    if active_room is not None:
        if active_room.status == "waiting":
            _publish_room(db, active_room)
            raise ApiError(
                409,
                "CONFLICT",
                "Bạn đang có lời mời thách đấu chưa kết thúc.",
            )
        return ok({"status": active_room.status, "roomId": active_room.id})

    entry = (
        db.query(MatchQueue)
        .filter(MatchQueue.user_id == user.uid)
        .with_for_update()
        .first()
    )
    if entry is not None and entry.status == "waiting":
        publish_queue_state(
            user.uid,
            "waiting",
            queue_id=entry.id,
        )
        return ok({"status": "waiting", "queueId": entry.id})

    candidate = (
        db.query(MatchQueue)
        .filter(
            MatchQueue.status == "waiting",
            MatchQueue.user_id != user.uid,
        )
        .order_by(
            func.abs(MatchQueue.score - (account.score or 0)),
            MatchQueue.joined_at,
        )
        .with_for_update(skip_locked=True)
        .first()
    )

    if entry is None:
        entry = MatchQueue(user_id=user.uid)
        db.add(entry)
    entry.score = account.score or 0
    entry.status = "matched" if candidate else "waiting"
    entry.joined_at = datetime.utcnow()

    if candidate is None:
        db.commit()
        publish_queue_state(
            user.uid,
            "waiting",
            queue_id=entry.id,
        )
        return ok({"status": "waiting", "queueId": entry.id})

    candidate.status = "matched"
    room = Room(
        host_id=candidate.user_id,
        guest_id=user.uid,
        status="playing",
        question_ids=_new_room_questions(db),
        current_question_index=0,
        question_start_time=datetime.utcnow(),
        host_score=0,
        guest_score=0,
    )
    db.add(room)
    db.flush()
    _create_history(db, room)
    db.commit()
    _publish_room(db, room)
    return ok({"status": "matched", "roomId": room.id})


@router.get("/queue")
def queue_status(user: CurrentUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    room = _active_room(db, user.uid)
    if room is not None:
        return ok({"status": room.status, "roomId": room.id})
    entry = (
        db.query(MatchQueue)
        .filter(MatchQueue.user_id == user.uid)
        .order_by(MatchQueue.joined_at.desc())
        .first()
    )
    if entry is None or entry.status != "waiting":
        return ok({"status": "idle", "queueId": None})
    return ok({
        "status": "waiting",
        "queueId": entry.id,
    })


@router.delete("/queue")
def leave_queue(user: CurrentUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    entries = db.query(MatchQueue).filter(
        MatchQueue.user_id == user.uid, MatchQueue.status == "waiting"
    ).all()
    for entry in entries:
        entry.status = "cancelled"
    db.commit()
    active_room = _active_room(db, user.uid)
    if active_room is not None:
        _publish_room(db, active_room)
    else:
        publish_queue_state(user.uid, "idle")
    return ok({"cancelled": len(entries)})


@router.post("/invite/{friend_uid}")
def invite_friend(friend_uid: str, user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    if friend_uid == user.uid:
        raise ApiError(400, "VALIDATION", "Bạn không thể tự thách đấu.")
    friendship = db.query(Friend).filter(
        Friend.status == "accepted",
        or_(
            (Friend.user_id == user.uid) & (Friend.friend_id == friend_uid),
            (Friend.user_id == friend_uid) & (Friend.friend_id == user.uid),
        ),
    ).first()
    if friendship is None:
        raise ApiError(403, "FORBIDDEN", "Chỉ có thể thách đấu bạn bè đã kết nối.")
    if _active_room(db, user.uid) is not None:
        raise ApiError(409, "CONFLICT", "Bạn đang có một trận chưa kết thúc.")
    if _active_room(db, friend_uid) is not None:
        raise ApiError(409, "CONFLICT", "Bạn bè này đang ở trong một trận.")
    db.query(MatchQueue).filter(
        MatchQueue.user_id.in_((user.uid, friend_uid)),
        MatchQueue.status == "waiting",
    ).update({MatchQueue.status: "cancelled"}, synchronize_session=False)

    room = Room(
        host_id=user.uid,
        guest_id=friend_uid,
        status="waiting",
        question_ids=_new_room_questions(db),
        current_question_index=0,
        host_score=0,
        guest_score=0,
    )
    db.add(room)
    db.flush()
    db.add(Notification(
        user_id=friend_uid,
        type="match_invite",
        ref_id=room.id,
        is_read=False,
    ))
    db.commit()
    _publish_room(db, room)
    return ok({"roomId": room.id, "status": room.status})


@router.get("/invitations")
def invitations(user: CurrentUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    rows = (
        db.query(Notification, Room, User)
        .join(Room, Room.id == Notification.ref_id)
        .join(User, User.uid == Room.host_id)
        .filter(
            Notification.user_id == user.uid,
            Notification.type == "match_invite",
            Notification.is_read.is_(False),
            Room.guest_id == user.uid,
            Room.status == "waiting",
        )
        .order_by(Notification.created_at.desc())
        .all()
    )
    active_rows = [
        row for row in rows
        if not _expire_stale_room(db, row[1], datetime.utcnow())
    ]
    return ok([
        {
            "roomId": room.id,
            "notificationId": notification.id,
            "hostId": host.uid,
            "hostName": host.display_name or "Người chơi",
            "createdAt": (
                notification.created_at.replace(tzinfo=timezone.utc).isoformat()
                if notification.created_at else None
            ),
        }
        for notification, room, host in active_rows
    ])


@router.post("/rooms/{room_id}/accept")
def accept_invite(room_id: str, user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).with_for_update().first()
    if room is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lời mời.")
    if room.guest_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Bạn không thể nhận lời mời này.")
    if _expire_stale_room(db, room, datetime.utcnow()):
        return ok({"roomId": room.id, "status": room.status})
    if room.status != "waiting":
        raise ApiError(403, "FORBIDDEN", "Bạn không thể nhận lời mời này.")
    room.status = "playing"
    room.question_start_time = datetime.utcnow()
    _create_history(db, room)
    db.query(Notification).filter(
        Notification.user_id == user.uid,
        Notification.type == "match_invite",
        Notification.ref_id == room_id,
    ).update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    _publish_room(db, room)
    return ok({"roomId": room.id, "status": room.status})


@router.post("/rooms/{room_id}/decline")
def decline_invite(room_id: str, user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).with_for_update().first()
    if room is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lời mời.")
    if room.guest_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Bạn không thể từ chối lời mời này.")
    if _expire_stale_room(db, room, datetime.utcnow()):
        return ok({"roomId": room.id, "status": room.status})
    if room.status != "waiting":
        raise ApiError(403, "FORBIDDEN", "Bạn không thể từ chối lời mời này.")
    room.status = "cancelled"
    db.query(Notification).filter(
        Notification.user_id == user.uid,
        Notification.type == "match_invite",
        Notification.ref_id == room_id,
    ).update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    _publish_room(db, room)
    return ok({"roomId": room.id, "status": room.status})


@router.post("/rooms/{room_id}/cancel")
def cancel_invite(room_id: str, user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).with_for_update().first()
    if room is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lời mời.")
    if room.host_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Chỉ người gửi lời mời mới có thể hủy.")
    if room.status != "waiting":
        raise ApiError(409, "CONFLICT", "Không thể hủy sau khi trận đã bắt đầu.")

    room.status = "cancelled"
    db.query(Notification).filter(
        Notification.user_id == room.guest_id,
        Notification.type == "match_invite",
        Notification.ref_id == room_id,
    ).update({Notification.is_read: True}, synchronize_session=False)
    db.commit()
    _publish_room(db, room)
    return ok({"roomId": room.id, "status": room.status})


@router.get("/rooms/{room_id}")
def get_room(room_id: str, user: CurrentUser = Depends(get_current_user),
             db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).with_for_update().first()
    if room is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy phòng đấu.")
    _require_player(room, user.uid)
    if _expire_stale_room(db, room, datetime.utcnow()):
        return ok(_room_payload(db, room, user.uid))
    history = db.query(MatchHistory).filter(MatchHistory.room_id == room.id).first()
    _advance_if_due(room, history, datetime.utcnow())
    db.commit()
    _publish_room(db, room)
    return ok(_room_payload(db, room, user.uid))


@router.post("/rooms/{room_id}/answer")
def submit_answer(room_id: str, body: PvpAnswerIn,
                  user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    room = db.query(Room).filter(Room.id == room_id).with_for_update().first()
    if room is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy phòng đấu.")
    _require_player(room, user.uid)
    if _expire_stale_room(db, room, datetime.utcnow()):
        return ok(_room_payload(db, room, user.uid))
    history = db.query(MatchHistory).filter(MatchHistory.room_id == room.id).first()
    now = datetime.utcnow()
    _advance_if_due(room, history, now)
    if room.status != "playing":
        raise ApiError(409, "CONFLICT", "Trận đấu này đã kết thúc.")
    if body.questionIndex != room.current_question_index:
        raise ApiError(409, "CONFLICT", "Câu hỏi đã chuyển, hãy tải lại trận đấu.")

    question_ids = copy.deepcopy(room.question_ids)
    question = question_ids[room.current_question_index]
    if body.selectedIndex >= len(question["options"]):
        raise ApiError(400, "VALIDATION", "Lựa chọn không hợp lệ.")
    answers = dict(question.get("answers", {}))
    if user.uid in answers:
        raise ApiError(409, "CONFLICT", "Bạn đã trả lời câu này rồi.")
    is_correct = body.selectedIndex == question["correctIndex"]
    answers[user.uid] = {
        "selectedIndex": body.selectedIndex,
        "isCorrect": is_correct,
    }
    question["answers"] = answers
    room.question_ids = question_ids
    if is_correct:
        if user.uid == room.host_id:
            room.host_score = (room.host_score or 0) + QUESTION_POINTS
        else:
            room.guest_score = (room.guest_score or 0) + QUESTION_POINTS
    if history is not None:
        _sync_history_question(history, room, room.current_question_index)
    _advance_if_due(room, history, now)
    db.commit()
    _publish_room(db, room)
    return ok(_room_payload(db, room, user.uid))


@router.get("/history")
def match_history(page: int = Query(default=1, ge=1),
                  user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    rows = (
        db.query(MatchHistory)
        .join(Room, MatchHistory.room_id == Room.id)
        .filter(
            Room.status == "finished",
            or_(
                MatchHistory.player1_id == user.uid,
                MatchHistory.player2_id == user.uid,
            ),
        )
        .order_by(MatchHistory.created_at.desc())
        .offset((page - 1) * 20)
        .limit(20)
        .all()
    )
    opponent_ids = {
        row.player2_id if row.player1_id == user.uid else row.player1_id
        for row in rows
    }
    users = {
        account.uid: account.display_name
        for account in db.query(User).filter(User.uid.in_(opponent_ids)).all()
    } if opponent_ids else {}
    return ok([
        {
            "id": row.id,
            "opponentName": users.get(
                row.player2_id if row.player1_id == user.uid else row.player1_id,
                "Người chơi",
            ),
            "myScore": row.score1 if row.player1_id == user.uid else row.score2,
            "opponentScore": row.score2 if row.player1_id == user.uid else row.score1,
            "result": (
                "draw" if row.winner_id is None
                else "win" if row.winner_id == user.uid
                else "loss"
            ),
            "createdAt": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ])


@router.get("/history/{history_id}")
def match_history_detail(history_id: str,
                         user: CurrentUser = Depends(get_current_user),
                         db: Session = Depends(get_db)):
    history = (
        db.query(MatchHistory)
        .join(Room, MatchHistory.room_id == Room.id)
        .filter(
            MatchHistory.id == history_id,
            Room.status == "finished",
            or_(
                MatchHistory.player1_id == user.uid,
                MatchHistory.player2_id == user.uid,
            ),
        )
        .first()
    )
    if history is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy trận đấu.")

    is_player1 = history.player1_id == user.uid
    opponent_id = history.player2_id if is_player1 else history.player1_id
    opponent = db.query(User).filter(User.uid == opponent_id).first()
    room = db.query(Room).filter(Room.id == history.room_id).first()
    questions = {
        question.get("id"): question
        for question in (room.question_ids if room else [])
        if isinstance(question, dict)
    }
    details = []
    for detail in history.details or []:
        question = questions.get(detail.get("questionId"), {})
        my_player = "host" if is_player1 else "guest"
        opponent_player = "guest" if is_player1 else "host"
        details.append({
            "questionId": detail.get("questionId", ""),
            "content": question.get("content", ""),
            "options": question.get("options", []),
            "correctIndex": question.get("correctIndex", -1),
            "mySelectedIndex": detail.get(f"{my_player}SelectedIndex"),
            "opponentSelectedIndex": detail.get(f"{opponent_player}SelectedIndex"),
            "myCorrect": bool(detail.get(f"{my_player}Correct")),
            "opponentCorrect": bool(detail.get(f"{opponent_player}Correct")),
        })

    return ok({
        "id": history.id,
        "opponentName": opponent.display_name if opponent else "Người chơi",
        "myScore": history.score1 if is_player1 else history.score2,
        "opponentScore": history.score2 if is_player1 else history.score1,
        "result": (
            "draw" if history.winner_id is None
            else "win" if history.winner_id == user.uid
            else "loss"
        ),
        "createdAt": history.created_at.isoformat() if history.created_at else None,
        "details": details,
    })
