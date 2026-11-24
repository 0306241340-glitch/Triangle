import uuid
from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session
from ..auth import CurrentUser, require_admin
from ..database import get_db
from ..errors import ApiError, ok
from ..models import (
    Attempt,
    AttemptAnswer,
    Comment,
    HistoryDetail,
    Item,
    Question,
    QuizHistory,
    QuizSet,
    QuizSetQuestion,
    Report,
    Topic,
    User,
    UserItem,
)
from ..schemas import (
    AdminItemIn,
    AdminQuestionIn,
    AdminQuizSetIn,
    AdminReportStatusIn,
    AdminTopicIn,
    AdminUserStatusIn,
)

router = APIRouter()

def _avg(xs):
    return round(sum(xs) / len(xs)) if xs else 0

@router.get("/stats")
def stats(user: CurrentUser = Depends(require_admin), db: Session = Depends(get_db)):
    users = db.query(User).all()
    sets = db.query(QuizSet).all()
    questions = db.query(Question).all()
    histories = db.query(QuizHistory).all()
    reports = db.query(Report).all()
    topics = {t.id: t.name for t in db.query(Topic).all()}
    set_names = {s.id: s.name for s in sets}
    user_names = {u.uid: u.display_name for u in users}
    by_set, by_topic = {}, {}
    for h in histories:
        by_set.setdefault(h.quiz_set_id, []).append(h.score or 0)
        by_topic.setdefault(h.topic_id, []).append(h.score or 0)
    rep_count = {}
    for r in reports:
        rep_count[r.question_id] = rep_count.get(r.question_id, 0) + 1
    q_content = {q.id: q.content for q in questions}
    return ok({
        "totals": {"users": len(users), "quizSets": len(sets), "questions": len(questions),
                   "attempts": len(histories),
                   "pendingReports": len([r for r in reports if r.status == "pending"])},
        "byQuizSet": sorted(
            [{"quizSetId": s.id, "name": s.name, "attempts": len(by_set.get(s.id, [])),
              "avgScore": _avg(by_set.get(s.id, [])),
              "maxScore": max(by_set[s.id]) if s.id in by_set else 0,
              "minScore": min(by_set[s.id]) if s.id in by_set else 0} for s in sets],
            key=lambda e: -e["attempts"]),
        "byTopic": sorted(
            [{"topicId": tid, "name": topics.get(tid, tid), "attempts": len(v),
              "avgScore": _avg(v)} for tid, v in by_topic.items()],
            key=lambda e: -e["attempts"]),
        "mostReportedQuestions": [
            {"questionId": qid, "content": q_content.get(qid, ""), "count": c}
            for qid, c in sorted(rep_count.items(), key=lambda kv: -kv[1])[:5]],
        "recentAttempts": [
            {"userId": h.user_id, "displayName": user_names.get(h.user_id, ""),
             "quizSetId": h.quiz_set_id, "quizSetName": set_names.get(h.quiz_set_id, ""),
             "score": h.score or 0,
             "createdAt": h.created_at.isoformat() if h.created_at else None}
            for h in sorted(histories, key=lambda x: str(x.created_at or ""), reverse=True)[:5]],
    })


@router.get("/quiz-sets")
def list_quiz_sets(user: CurrentUser = Depends(require_admin),
                   db: Session = Depends(get_db)):
    rows = db.query(QuizSet).order_by(QuizSet.name).all()
    links_by_set = {}
    for link in db.query(QuizSetQuestion).order_by(
        QuizSetQuestion.position
    ).all():
        links_by_set.setdefault(link.quiz_set_id, []).append(link.question_id)
    return ok([
        _quiz_set_dict(row, links_by_set.get(row.id, [])) for row in rows
    ])


def _quiz_set_dict(row: QuizSet, question_ids=None):
    question_ids = question_ids or []
    return {
        "id": row.id,
        "topicId": row.topic_id,
        "title": row.name,
        "level": row.difficulty or "mixed",
        "questionCount": row.question_count or 0,
        "durationSec": row.duration_sec or 300,
        "attemptCount": row.attempt_count or 0,
        "avgScore": row.avg_score or 0,
        "description": row.description or "",
        "isActive": bool(row.is_active),
        "selectionMode": "manual" if question_ids else "random",
        "questionIds": question_ids,
    }


@router.get("/quiz-sets/{set_id}/questions")
def list_quiz_set_questions(set_id: str, user: CurrentUser = Depends(require_admin),
                            db: Session = Depends(get_db)):
    quiz_set = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if quiz_set is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")

    links = (
        db.query(QuizSetQuestion)
        .filter(QuizSetQuestion.quiz_set_id == quiz_set.id)
        .order_by(QuizSetQuestion.position)
        .all()
    )
    if links:
        question_map = {
            row.id: row
            for row in db.query(Question)
            .filter(Question.id.in_([link.question_id for link in links]))
            .all()
        }
        rows = [question_map[link.question_id] for link in links
                if link.question_id in question_map]
    else:
        rows = (
            db.query(Question)
            .filter(
                Question.topic_id == quiz_set.topic_id,
                Question.is_active.is_(True),
            )
            .order_by(Question.id)
            .all()
        )
    return ok([
        {
            "id": row.id,
            "slotId": "",
            "topicId": row.topic_id,
            "content": row.content,
            "options": row.options or [],
            "correctIndex": row.correct_index,
            "level": row.level or "easy",
            "explanation": row.explanation or "",
        }
        for row in rows
    ])


@router.get("/items")
def list_items(user: CurrentUser = Depends(require_admin),
               db: Session = Depends(get_db)):
    rows = db.query(Item).order_by(Item.name).all()
    return ok([
        {
            "id": row.id,
            "name": row.name,
            "type": row.type or "help",
            "lifelineCode": row.effect or "",
            "price": row.price or 0,
            "description": row.description or "",
            "imageUrl": "",
            "isActive": bool(row.is_active),
        }
        for row in rows
    ])


@router.get("/users")
def list_users(search: str = "", user: CurrentUser = Depends(require_admin),
               db: Session = Depends(get_db)):
    query = db.query(User)
    if search.strip():
        needle = f"%{search.strip()}%"
        query = query.filter(
            (User.display_name.ilike(needle))
            | (User.email.ilike(needle))
            | (User.uid.ilike(needle))
            | (User.user_code.ilike(needle))
        )
    rows = query.order_by(User.display_name, User.email).all()
    game_counts = dict(
        db.query(QuizHistory.user_id, func.count(QuizHistory.id))
        .group_by(QuizHistory.user_id)
        .all()
    )
    return ok([
        {
            "uid": row.uid,
            "email": row.email or "",
            "displayName": row.display_name or "",
            "avatarUrl": row.avatar_url or "",
            "userCode": row.user_code or "",
            "role": row.role or "user",
            "status": row.status or "active",
            "coins": row.coins or 0,
            "score": row.score or 0,
            "weeklyScore": row.weekly_score or 0,
            "streakDays": 0,
            "gamesPlayed": game_counts.get(row.uid, 0),
            "createdAt": row.created_at.isoformat() if row.created_at else None,
            "updatedAt": row.updated_at.isoformat() if row.updated_at else None,
        }
        for row in rows
    ])


@router.get("/reports")
def list_reports(user: CurrentUser = Depends(require_admin),
                 db: Session = Depends(get_db)):
    questions = {row.id: row.content for row in db.query(Question).all()}
    users = {row.uid: row.display_name for row in db.query(User).all()}
    rows = db.query(Report).order_by(Report.id.desc()).all()
    return ok([
        {
            "id": row.id,
            "questionId": row.question_id,
            "questionContent": questions.get(row.question_id, ""),
            "userId": row.user_id or "",
            "userName": users.get(row.user_id, ""),
            "reason": row.reason or "",
            "status": row.status or "pending",
        }
        for row in rows
    ])


@router.get("/topics")
def list_topics(user: CurrentUser = Depends(require_admin),
                db: Session = Depends(get_db)):
    rows = db.query(Topic).order_by(Topic.name).all()
    return ok([_topic_dict(row, db) for row in rows])


def _topic_dict(row: Topic, db: Session):
    return {
        "id": row.id,
        "name": row.name,
        "description": row.description or "",
        "icon": row.icon or "",
        "imageUrl": row.image_url or "",
        "isActive": bool(row.is_active),
        "questionCount": db.query(Question).filter(
            Question.topic_id == row.id
        ).count(),
    }


@router.post("/topics")
def create_topic(body: AdminTopicIn, user: CurrentUser = Depends(require_admin),
                 db: Session = Depends(get_db)):
    name = body.name.strip()
    if not name:
        raise ApiError(400, "VALIDATION", "Tên chủ đề không được để trống.")
    row = Topic(
        id=uuid.uuid4().hex,
        name=name,
        description=body.description.strip(),
        icon=body.icon.strip(),
        image_url=body.imageUrl.strip(),
        is_active=body.isActive,
        question_count=0,
    )
    db.add(row)
    db.commit()
    return ok(_topic_dict(row, db))


@router.put("/topics/{topic_id}")
def update_topic(topic_id: str, body: AdminTopicIn,
                 user: CurrentUser = Depends(require_admin),
                 db: Session = Depends(get_db)):
    row = db.query(Topic).filter(Topic.id == topic_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy chủ đề.")
    name = body.name.strip()
    if not name:
        raise ApiError(400, "VALIDATION", "Tên chủ đề không được để trống.")
    row.name = name
    row.description = body.description.strip()
    row.icon = body.icon.strip()
    row.image_url = body.imageUrl.strip()
    row.is_active = body.isActive
    db.commit()
    return ok(_topic_dict(row, db))


@router.delete("/topics/{topic_id}")
def delete_topic(topic_id: str, user: CurrentUser = Depends(require_admin),
                 db: Session = Depends(get_db)):
    row = db.query(Topic).filter(Topic.id == topic_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy chủ đề.")
    if (db.query(QuizSet).filter(QuizSet.topic_id == topic_id).first() or
            db.query(Question).filter(Question.topic_id == topic_id).first()):
        raise ApiError(
            409,
            "CONFLICT",
            "Không thể xóa chủ đề đang có bộ đề hoặc câu hỏi; hãy ẩn chủ đề.",
        )
    db.delete(row)
    db.commit()
    return ok({"id": topic_id, "deleted": True})


@router.get("/questions")
def list_questions(topicId: str = "", search: str = "", level: str = "",
                   user: CurrentUser = Depends(require_admin),
                   db: Session = Depends(get_db)):
    query = db.query(Question)
    if topicId:
        query = query.filter(Question.topic_id == topicId)
    if level:
        query = query.filter(Question.level == level)
    rows = query.order_by(Question.id).all()
    if search:
        needle = search.strip().lower()
        rows = [row for row in rows if needle in row.content.lower()]
    return ok([_question_dict(row) for row in rows])


@router.get("/questions/{question_id}")
def get_question(question_id: str, user: CurrentUser = Depends(require_admin),
                 db: Session = Depends(get_db)):
    row = db.query(Question).filter(Question.id == question_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy câu hỏi.")
    return ok(_question_dict(row))


def _question_dict(row: Question):
    return {
        "id": row.id,
        "slotId": "",
        "topicId": row.topic_id,
        "content": row.content,
        "options": row.options or [],
        "correctIndex": row.correct_index,
        "level": row.level or "easy",
        "explanation": row.explanation or "",
        "isActive": bool(row.is_active),
    }


def _validate_question(body: AdminQuestionIn, db: Session):
    if not body.content.strip():
        raise ApiError(400, "VALIDATION", "Nội dung câu hỏi không được để trống.")
    if len(body.options) != 4 or any(not option.strip() for option in body.options):
        raise ApiError(400, "VALIDATION", "Câu hỏi phải có đủ 4 phương án.")
    if not 0 <= body.correctIndex < 4:
        raise ApiError(400, "VALIDATION", "Đáp án đúng phải nằm trong 4 phương án.")
    if body.level not in {"easy", "medium", "hard"}:
        raise ApiError(400, "VALIDATION", "Độ khó không hợp lệ.")
    topic = db.query(Topic).filter(Topic.id == body.topicId).first()
    if topic is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy chủ đề.")
    return topic


def _sync_topic_question_count(db: Session, topic_id: str):
    topic = db.query(Topic).filter(Topic.id == topic_id).first()
    if topic is not None:
        topic.question_count = db.query(Question).filter(
            Question.topic_id == topic_id
        ).count()


@router.post("/questions")
def create_question(body: AdminQuestionIn,
                    user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    _validate_question(body, db)
    row = Question(
        id=uuid.uuid4().hex,
        topic_id=body.topicId,
        content=body.content.strip(),
        options=[option.strip() for option in body.options],
        correct_index=body.correctIndex,
        level=body.level,
        explanation=body.explanation.strip(),
        is_active=body.isActive,
    )
    db.add(row)
    _sync_topic_question_count(db, body.topicId)
    db.commit()
    return ok(_question_dict(row))


@router.put("/questions/{question_id}")
def update_question(question_id: str, body: AdminQuestionIn,
                    user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    row = db.query(Question).filter(Question.id == question_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy câu hỏi.")
    _validate_question(body, db)
    linked_sets = db.query(QuizSetQuestion).filter(
        QuizSetQuestion.question_id == row.id
    ).count()
    if linked_sets and (
        body.topicId != row.topic_id or not body.isActive
    ):
        raise ApiError(
            409,
            "CONFLICT",
            "Không thể đổi chủ đề hoặc ẩn câu hỏi đang được gán vào bộ đề.",
        )
    old_topic_id = row.topic_id
    row.topic_id = body.topicId
    row.content = body.content.strip()
    row.options = [option.strip() for option in body.options]
    row.correct_index = body.correctIndex
    row.level = body.level
    row.explanation = body.explanation.strip()
    row.is_active = body.isActive
    _sync_topic_question_count(db, old_topic_id)
    _sync_topic_question_count(db, body.topicId)
    db.commit()
    return ok(_question_dict(row))


@router.delete("/questions/{question_id}")
def delete_question(question_id: str, user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    row = db.query(Question).filter(Question.id == question_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy câu hỏi.")
    referenced = any((
        db.query(QuizSetQuestion).filter(
            QuizSetQuestion.question_id == question_id
        ).first(),
        db.query(AttemptAnswer).filter(
            AttemptAnswer.question_id == question_id
        ).first(),
        db.query(HistoryDetail).filter(
            HistoryDetail.question_id == question_id
        ).first(),
        db.query(Report).filter(Report.question_id == question_id).first(),
    ))
    if referenced:
        raise ApiError(
            409,
            "CONFLICT",
            "Không thể xóa câu hỏi đã được dùng trong bộ đề, lượt thi hoặc báo lỗi.",
        )
    topic_id = row.topic_id
    db.delete(row)
    _sync_topic_question_count(db, topic_id)
    db.commit()
    return ok({"id": question_id, "deleted": True})


def _validate_quiz_set(body: AdminQuizSetIn, db: Session):
    if not body.title.strip():
        raise ApiError(400, "VALIDATION", "Tên bộ đề không được để trống.")
    if body.durationSec <= 0 or body.questionCount <= 0:
        raise ApiError(
            400,
            "VALIDATION",
            "Thời gian và số câu hỏi phải lớn hơn 0.",
        )
    if body.selectionMode not in {"random", "manual"}:
        raise ApiError(400, "VALIDATION", "Cách chọn câu hỏi không hợp lệ.")
    topic = db.query(Topic).filter(Topic.id == body.topicId).first()
    if topic is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy chủ đề.")

    question_ids = list(dict.fromkeys(body.questionIds))
    if body.selectionMode == "manual":
        if not question_ids:
            raise ApiError(
                400,
                "VALIDATION",
                "Hãy chọn ít nhất một câu hỏi cho bộ đề.",
            )
        questions = db.query(Question).filter(
            Question.id.in_(question_ids),
            Question.topic_id == body.topicId,
            Question.is_active.is_(True),
        ).all()
        if len(questions) != len(question_ids):
            raise ApiError(
                400,
                "VALIDATION",
                "Chỉ chọn câu hỏi đang hoạt động thuộc chủ đề của bộ đề.",
            )
        return question_ids

    if body.questionIds:
        raise ApiError(
            400,
            "VALIDATION",
            "Không gửi danh sách câu hỏi khi chọn chế độ ngẫu nhiên.",
        )
    available = db.query(Question).filter(
        Question.topic_id == body.topicId,
        Question.is_active.is_(True),
    ).count()
    if body.questionCount > available:
        raise ApiError(
            400,
            "VALIDATION",
            "Số câu trong bộ đề vượt quá số câu hỏi đang hoạt động của chủ đề.",
        )
    return []


def _save_quiz_set_links(db: Session, set_id: str, question_ids):
    db.query(QuizSetQuestion).filter(
        QuizSetQuestion.quiz_set_id == set_id
    ).delete(synchronize_session=False)
    db.add_all([
        QuizSetQuestion(
            quiz_set_id=set_id,
            question_id=question_id,
            position=position,
        )
        for position, question_id in enumerate(question_ids)
    ])


@router.post("/quiz-sets")
def create_quiz_set(body: AdminQuizSetIn,
                    user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    question_ids = _validate_quiz_set(body, db)
    row = QuizSet(
        id=uuid.uuid4().hex,
        topic_id=body.topicId,
        name=body.title.strip(),
        description=body.description.strip(),
        difficulty=body.level,
        duration_sec=body.durationSec,
        question_count=len(question_ids) if question_ids else body.questionCount,
        is_active=body.isActive,
        attempt_count=0,
        avg_score=0,
    )
    db.add(row)
    db.flush()
    _save_quiz_set_links(db, row.id, question_ids)
    db.commit()
    return ok(_quiz_set_dict(row, question_ids))


@router.put("/quiz-sets/{set_id}")
def update_quiz_set(set_id: str, body: AdminQuizSetIn,
                    user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    row = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")
    question_ids = _validate_quiz_set(body, db)
    row.topic_id = body.topicId
    row.name = body.title.strip()
    row.description = body.description.strip()
    row.difficulty = body.level
    row.duration_sec = body.durationSec
    row.question_count = len(question_ids) if question_ids else body.questionCount
    row.is_active = body.isActive
    _save_quiz_set_links(db, row.id, question_ids)
    db.commit()
    return ok(_quiz_set_dict(row, question_ids))


@router.delete("/quiz-sets/{set_id}")
def delete_quiz_set(set_id: str, user: CurrentUser = Depends(require_admin),
                    db: Session = Depends(get_db)):
    row = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")
    used = any((
        db.query(Attempt).filter(Attempt.quiz_set_id == set_id).first(),
        db.query(QuizHistory).filter(QuizHistory.quiz_set_id == set_id).first(),
        db.query(Comment).filter(Comment.quiz_set_id == set_id).first(),
    ))
    if used:
        raise ApiError(
            409,
            "CONFLICT",
            "Không thể xóa bộ đề đã có lượt thi hoặc đánh giá; hãy ẩn bộ đề.",
        )
    db.query(QuizSetQuestion).filter(
        QuizSetQuestion.quiz_set_id == set_id
    ).delete(synchronize_session=False)
    db.delete(row)
    db.commit()
    return ok({"id": set_id, "deleted": True})


def _item_dict(row: Item):
    return {
        "id": row.id,
        "name": row.name,
        "type": row.type or "help",
        "lifelineCode": row.effect or "",
        "price": row.price or 0,
        "description": row.description or "",
        "imageUrl": "",
        "isActive": bool(row.is_active),
    }


def _validate_item(body: AdminItemIn):
    if not body.name.strip():
        raise ApiError(400, "VALIDATION", "Tên vật phẩm không được để trống.")
    if body.type not in {"help", "frame", "title"}:
        raise ApiError(400, "VALIDATION", "Loại vật phẩm không hợp lệ.")
    if body.price < 0:
        raise ApiError(400, "VALIDATION", "Giá vật phẩm không được âm.")
    if body.type == "help" and not body.lifelineCode.strip():
        raise ApiError(400, "VALIDATION", "Vật phẩm trợ giúp cần mã hiệu ứng.")


@router.post("/items")
def create_item(body: AdminItemIn, user: CurrentUser = Depends(require_admin),
                db: Session = Depends(get_db)):
    _validate_item(body)
    row = Item(
        id=uuid.uuid4().hex,
        name=body.name.strip(),
        type=body.type,
        effect=body.lifelineCode.strip(),
        price=body.price,
        description=body.description.strip(),
        is_active=body.isActive,
    )
    db.add(row)
    db.commit()
    return ok(_item_dict(row))


@router.put("/items/{item_id}")
def update_item(item_id: str, body: AdminItemIn,
                user: CurrentUser = Depends(require_admin),
                db: Session = Depends(get_db)):
    row = db.query(Item).filter(Item.id == item_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy vật phẩm.")
    _validate_item(body)
    if row.type != body.type and db.query(UserItem).filter(
        UserItem.item_id == item_id
    ).first():
        raise ApiError(
            409,
            "CONFLICT",
            "Không thể đổi loại vật phẩm đã có người sở hữu.",
        )
    row.name = body.name.strip()
    row.type = body.type
    row.effect = body.lifelineCode.strip()
    row.price = body.price
    row.description = body.description.strip()
    row.is_active = body.isActive
    db.commit()
    return ok(_item_dict(row))


@router.delete("/items/{item_id}")
def delete_item(item_id: str, user: CurrentUser = Depends(require_admin),
                db: Session = Depends(get_db)):
    row = db.query(Item).filter(Item.id == item_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy vật phẩm.")
    if db.query(UserItem).filter(UserItem.item_id == item_id).first():
        raise ApiError(
            409,
            "CONFLICT",
            "Vật phẩm đã có người sở hữu; hãy ẩn vật phẩm thay vì xóa.",
        )
    db.delete(row)
    db.commit()
    return ok({"id": item_id, "deleted": True})


@router.put("/users/{uid}/status")
def update_user_status(uid: str, body: AdminUserStatusIn,
                       user: CurrentUser = Depends(require_admin),
                       db: Session = Depends(get_db)):
    row = db.query(User).filter(User.uid == uid).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy tài khoản.")
    if body.status not in {"active", "locked"}:
        raise ApiError(400, "VALIDATION", "Trạng thái tài khoản không hợp lệ.")
    if uid == user.uid and body.status == "locked":
        raise ApiError(400, "VALIDATION", "Bạn không thể tự khóa tài khoản admin.")
    row.status = body.status
    row.updated_at = datetime.utcnow()
    db.commit()
    return ok({"uid": row.uid, "status": row.status})


@router.put("/reports/{report_id}/status")
def update_report_status(report_id: int, body: AdminReportStatusIn,
                         user: CurrentUser = Depends(require_admin),
                         db: Session = Depends(get_db)):
    row = db.query(Report).filter(Report.id == report_id).first()
    if row is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy báo lỗi.")
    if body.status not in {"pending", "resolved", "rejected"}:
        raise ApiError(400, "VALIDATION", "Trạng thái báo lỗi không hợp lệ.")
    row.status = body.status
    db.commit()
    return ok({"id": row.id, "status": row.status})
