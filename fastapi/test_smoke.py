"""Smoke test khong can Firebase: override auth bang user gia.
Chay:  python -m pytest test_smoke.py -q   (hoac: python test_smoke.py)"""
import base64, json, os, sys, tempfile
from datetime import datetime, timedelta
from unittest.mock import patch
os.environ["DATABASE_URL"] = "sqlite:///./test_quiz.db"
if os.path.exists("test_quiz.db"):
    os.remove("test_quiz.db")
sys.path.insert(0, ".")
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.orm import Session as DbSession, sessionmaker
from fastapi.testclient import TestClient
import app.auth as auth_module
from app.auth import CurrentUser, get_current_user
from app.database import Base, engine
from app.errors import ApiError
from app.main import app
from app.routers import pvp
from app.seed import seed

Base.metadata.create_all(bind=engine)
seed("seed-data-3-chu-de.json")
UID = "VFLqQiv8AnOvWt7lhfXnNtmfKcu2"  # An
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
c = TestClient(app, raise_server_exceptions=False)
published_rooms = {}
published_invitations = set()
published_queue_states = {}


def publish_room(room_id, payload, invitation=None):
    published_rooms[room_id] = payload
    active = payload["status"] in ("waiting", "playing")
    for uid in (payload["hostId"], payload.get("guestId")):
        if uid is not None:
            pvp.publish_queue_state(
                uid,
                "in_room" if active else "idle",
                room_id=room_id if active else None,
            )
    if invitation is not None and payload["status"] == "waiting":
        published_invitations.add(room_id)
    else:
        published_invitations.discard(room_id)


pvp.publish_room = publish_room
pvp.publish_queue_state = lambda uid, status, **kwargs: published_queue_states.update(
    {uid: {"status": status, **kwargs}}
)

r = c.get("/health"); assert r.status_code == 200 and r.json()["data"]["status"] == "ok", r.text
r = c.get("/topics"); assert r.status_code == 200 and len(r.json()["data"]) == 3, r.text
r = c.get("/quiz-sets", params={"topicId": "topic_tong_hop"})
assert [s["id"] for s in r.json()["data"]] == ["set_tong_hop_1"], r.text
r = c.get("/quiz-sets/set_tong_hop_1")
assert r.json()["data"]["name"].startswith("Kiến thức"), r.text
assert r.json()["data"]["comments"] == [], r.text

# start: 10 cau, khong lo correctIndex
r = c.post("/quiz/start", json={"quizSetId": "set_tong_hop_1"})
assert r.status_code == 200, r.text
start = r.json()["data"]
assert len(start["questions"]) == 10 and "correctIndex" not in str(start["questions"])
assert start["durationSec"] == 300
att = start["attemptId"]

# 50/50: lay dap an dung that tu DB, an 2 sai, khong an dung, tru 30 xu
from app.database import SessionLocal
from app.models import AttemptAnswer, Report, User
q0 = start["questions"][0]
report_response = c.post("/quiz/report", json={
    "attemptId": att,
    "questionId": q0["id"],
    "issueType": "answer",
    "answerText": q0["options"][0],
    "description": "Đáp án này có vẻ chưa chính xác.",
})
assert report_response.status_code == 200, report_response.text
db = SessionLocal()
report = db.query(Report).filter(
    Report.id == report_response.json()["data"]["id"]
).first()
assert report is not None
assert report.question_id == q0["id"] and report.reason.startswith("Đáp án:")
keys = {a.question_id: a.correct_index for
        a in db.query(AttemptAnswer).filter(AttemptAnswer.attempt_id == att).all()}
r = c.post("/quiz/fifty-fifty", json={"attemptId": att, "questionId": q0["id"]})
assert r.status_code == 200, r.text
hidden = r.json()["data"]["hiddenIndices"]
assert len(hidden) == 2 and keys[q0["id"]] not in hidden, (hidden, keys[q0["id"]])
assert r.json()["data"]["coins"] == 70  # 100 - 30
r = c.post("/quiz/fifty-fifty", json={"attemptId": att, "questionId": q0["id"]})
assert r.status_code == 409, r.text  # dung lai 1 cau -> chan
db.close()

# submit: tra loi dung het -> 180d / 90xu (4 de, 4 TB, 2 kho)
answers = [{"questionId": q["id"], "selectedIndex": keys[q["id"]]} for q in start["questions"]]
r = c.post("/quiz/submit", json={"attemptId": att, "quizSetId": "set_tong_hop_1",
                                 "answers": answers, "timeTakenSec": 56})
assert r.status_code == 200, r.text
d = r.json()["data"]
assert (d["score"], d["correctCount"], d["coinsEarned"]) == (180, 10, 90), d
r = c.post("/quiz/submit", json={"attemptId": att, "quizSetId": "set_tong_hop_1",
                                 "answers": answers, "timeTakenSec": 56})
assert r.status_code == 409, r.text  # nop trung -> khong cong 2 lan
db = SessionLocal()
u = db.query(User).filter(User.uid == UID).first()
assert (u.score, u.coins, u.monthly_score) == (180, 160, 180), (u.score, u.coins)  # 70+90
from app.models import QuizSet, QuizHistory
s = db.query(QuizSet).filter(QuizSet.id == "set_tong_hop_1").first()
assert (s.attempt_count, s.avg_score) == (1, 180), (s.attempt_count, s.avg_score)
assert db.query(QuizHistory).count() == 1
db.close()

# comment + leaderboard + history
r = c.post("/quiz-sets/set_tong_hop_1/comments", json={"rating": 5, "content": "Hay"})
assert r.status_code == 200, r.text
r = c.get("/quiz-sets/set_tong_hop_1")
assert len(r.json()["data"]["comments"]) == 1, r.text
r = c.get("/leaderboard")
assert r.json()["data"]["myScore"] == 180 and r.json()["data"]["myRank"] == 1, r.text
r = c.get("/quiz/history")
assert len(r.json()["data"]) == 1 and r.json()["data"][0]["score"] == 180, r.text
quiz_history_id = r.json()["data"][0]["id"]
r = c.get(f"/quiz/history/{quiz_history_id}")
assert r.status_code == 200 and len(r.json()["data"]["details"]) == 10, r.text
assert r.json()["data"]["details"][0]["content"], r.text

# Profile, friends, favorites, and store data all remain in SQL.
profile = c.get("/me").json()["data"]
assert profile["uid"] == UID and profile["userCode"] == "TU001A", profile
r = c.put("/me/profile", json={"displayName": "An SQL", "avatarUrl": ""})
assert r.status_code == 200 and c.get("/me").json()["data"]["displayName"] == "An SQL"

ADMIN_UID = "tTUzRgv5gseRFwPWHJycH2gB4mP2"
r = c.get("/friends/search", params={"q": "AD001A"})
assert r.status_code == 200 and r.json()["data"][0]["uid"] == ADMIN_UID, r.text
r = c.post(f"/friends/{ADMIN_UID}")
assert r.status_code == 200 and r.json()["data"]["status"] == "pending", r.text
friendship_id = r.json()["data"]["id"]
r = c.get("/friends/requests", params={"direction": "outgoing"})
assert [item["id"] for item in r.json()["data"]] == [friendship_id], r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
r = c.get("/admin/reports")
assert r.status_code == 200 and any(
    report["questionId"] == q0["id"]
    and report["userId"] == UID
    and report["reason"].startswith("Đáp án:")
    for report in r.json()["data"]
), r.text
r = c.get("/friends/requests", params={"direction": "incoming"})
assert [item["id"] for item in r.json()["data"]] == [friendship_id], r.text
r = c.post(f"/friends/{friendship_id}/accept")
assert r.status_code == 200 and r.json()["data"]["status"] == "accepted", r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
r = c.get("/friends")
assert [item["id"] for item in r.json()["data"]] == [friendship_id], r.text

# Random matchmaking and friend challenges use persisted PostgreSQL room state.
from app.models import MatchHistory, MatchQueue, Room
r = c.post("/pvp/queue")
assert r.status_code == 200 and r.json()["data"]["status"] == "waiting", r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
r = c.post("/pvp/queue")
assert r.status_code == 200 and r.json()["data"]["status"] == "matched", r.text
random_room_id = r.json()["data"]["roomId"]
assert published_rooms[random_room_id]["status"] == "playing"
assert "correctIndex" not in str(published_rooms[random_room_id])
assert published_queue_states[UID]["room_id"] == random_room_id
assert published_queue_states[ADMIN_UID]["room_id"] == random_room_id
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
r = c.get(f"/pvp/rooms/{random_room_id}")
assert r.status_code == 200 and "correctIndex" not in str(r.json()["data"]), r.text


def finish_match(room_id, start_index=0):
    for question_index in range(start_index, 10):
        db = SessionLocal()
        room = db.query(Room).filter(Room.id == room_id).first()
        snapshot = room.question_ids[question_index]
        correct_index = snapshot["correctIndex"]
        db.close()
        for player_uid in (UID, ADMIN_UID):
            app.dependency_overrides[get_current_user] = lambda uid=player_uid: CurrentUser(
                uid=uid, role="user"
            )
            response = c.post(
                f"/pvp/rooms/{room_id}/answer",
                json={
                    "questionIndex": question_index,
                    "selectedIndex": correct_index,
                },
            )
            assert response.status_code == 200, response.text
            data = response.json()["data"]
            if player_uid == UID and question_index == 0:
                assert data["myAnswered"] is True and data["questionIndex"] == 0, data
                duplicate = c.post(
                    f"/pvp/rooms/{room_id}/answer",
                    json={
                        "questionIndex": question_index,
                        "selectedIndex": correct_index,
                    },
                )
                assert duplicate.status_code == 409, duplicate.text
            if player_uid == ADMIN_UID and question_index < 9:
                assert data["questionIndex"] == question_index + 1, data
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        uid=UID, role="user"
    )
    result = c.get(f"/pvp/rooms/{room_id}")
    assert result.status_code == 200 and result.json()["data"]["status"] == "finished"
    assert published_rooms[room_id]["status"] == "finished"
    db = SessionLocal()
    history = db.query(MatchHistory).filter(
        MatchHistory.room_id == room_id
    ).first()
    assert history is not None
    expected_score = (10 - start_index) * 10
    assert (history.score1, history.score2, history.winner_id) == (
        expected_score, expected_score, None
    )
    assert len(history.details) == 10
    db.close()


finish_match(random_room_id)
assert published_queue_states[UID]["status"] == "idle"
assert published_queue_states[ADMIN_UID]["status"] == "idle"
requeued = c.post("/pvp/queue")
assert (
    requeued.status_code == 200
    and requeued.json()["data"]["status"] == "waiting"
), requeued.text
db = SessionLocal()
assert db.query(MatchQueue).filter(MatchQueue.user_id == UID).count() == 1
db.close()
assert c.delete("/pvp/queue").status_code == 200
r = c.get("/pvp/history")
assert r.status_code == 200 and len(r.json()["data"]) == 1, r.text
match_history_id = r.json()["data"][0]["id"]
r = c.get(f"/pvp/history/{match_history_id}")
assert r.status_code == 200 and len(r.json()["data"]["details"]) == 10, r.text
assert r.json()["data"]["details"][0]["content"], r.text
invite = c.post(f"/pvp/invite/{ADMIN_UID}")
assert invite.status_code == 200 and invite.json()["data"]["status"] == "waiting", invite.text
friend_room_id = invite.json()["data"]["roomId"]
assert friend_room_id in published_invitations
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
incoming = c.get("/pvp/invitations")
assert incoming.status_code == 200
assert any(row["roomId"] == friend_room_id for row in incoming.json()["data"])
assert c.post("/pvp/queue").status_code == 409
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
assert c.post("/pvp/queue").status_code == 409
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
accepted = c.post(f"/pvp/rooms/{friend_room_id}/accept")
assert accepted.status_code == 200 and accepted.json()["data"]["status"] == "playing"
assert friend_room_id not in published_invitations
db = SessionLocal()
friend_room = db.query(Room).filter(Room.id == friend_room_id).first()
friend_room.question_start_time = datetime.utcnow() - timedelta(seconds=16)
db.commit()
db.close()
timed_out = c.get(f"/pvp/rooms/{friend_room_id}")
assert timed_out.status_code == 200
assert timed_out.json()["data"]["questionIndex"] == 1, timed_out.text
finish_match(friend_room_id, start_index=1)

# The inviter can cancel a waiting challenge, but the recipient cannot.
cancel_invite = c.post(f"/pvp/invite/{ADMIN_UID}")
assert cancel_invite.status_code == 200, cancel_invite.text
cancel_room_id = cancel_invite.json()["data"]["roomId"]
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
forbidden = c.post(f"/pvp/rooms/{cancel_room_id}/cancel")
assert forbidden.status_code == 403, forbidden.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
cancelled = c.post(f"/pvp/rooms/{cancel_room_id}/cancel")
assert cancelled.status_code == 200
assert cancelled.json()["data"]["status"] == "cancelled", cancelled.text
assert cancel_room_id not in published_invitations
assert published_queue_states[UID]["status"] == "idle"
assert published_queue_states[ADMIN_UID]["status"] == "idle"
db = SessionLocal()
assert db.query(Room).filter(Room.id == cancel_room_id).first().status == "cancelled"
db.close()

# Waiting invites expire after two minutes but remain in SQL as cancelled rooms.
stale_invite = c.post(f"/pvp/invite/{ADMIN_UID}")
assert stale_invite.status_code == 200, stale_invite.text
stale_invite_id = stale_invite.json()["data"]["roomId"]
db = SessionLocal()
stale_room = db.query(Room).filter(Room.id == stale_invite_id).first()
stale_room.created_at = datetime.utcnow() - timedelta(minutes=1, seconds=59)
db.commit()
db.close()
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
incoming = c.get("/pvp/invitations")
assert any(row["roomId"] == stale_invite_id for row in incoming.json()["data"])
db = SessionLocal()
stale_room = db.query(Room).filter(Room.id == stale_invite_id).first()
stale_room.created_at = datetime.utcnow() - timedelta(minutes=2, seconds=1)
db.commit()
db.close()
pvp.cleanup_expired_rooms()
incoming = c.get("/pvp/invitations")
assert all(row["roomId"] != stale_invite_id for row in incoming.json()["data"])
assert published_rooms[stale_invite_id]["status"] == "cancelled"
assert published_queue_states[UID]["status"] == "idle"
assert published_queue_states[ADMIN_UID]["status"] == "idle"
db = SessionLocal()
assert db.query(Room).filter(Room.id == stale_invite_id).first() is not None
db.close()

# An abandoned active match expires and no longer blocks matchmaking.
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
assert c.post("/pvp/queue").json()["data"]["status"] == "waiting"
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
matched = c.post("/pvp/queue")
assert matched.status_code == 200 and matched.json()["data"]["status"] == "matched", matched.text
stale_match_id = matched.json()["data"]["roomId"]
db = SessionLocal()
stale_match = db.query(Room).filter(Room.id == stale_match_id).first()
stale_match.question_start_time = datetime.utcnow() - timedelta(minutes=2, seconds=1)
db.commit()
db.close()
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
queue = c.get("/pvp/queue")
assert queue.status_code == 200 and queue.json()["data"] == {
    "status": "idle",
    "queueId": None,
}, queue.text
assert published_rooms[stale_match_id]["status"] == "cancelled"
assert published_queue_states[UID]["status"] == "idle"
assert published_queue_states[ADMIN_UID]["status"] == "idle"
db = SessionLocal()
assert db.query(Room).filter(Room.id == stale_match_id).first() is not None
assert db.query(MatchHistory).filter(
    MatchHistory.room_id == stale_match_id
).first() is not None
db.close()

r = c.post("/favorites", json={"targetId": "set_tong_hop_1", "targetType": "quizSet"})
assert r.status_code == 200, r.text
r = c.get("/favorites")
assert r.status_code == 200 and any(
    item["targetId"] == "set_tong_hop_1" and item["targetType"] == "quizSet"
    for item in r.json()["data"]
), r.text
r = c.get("/favorites/status", params={
    "targetId": "set_tong_hop_1", "targetType": "quizSet"
})
assert r.json()["data"]["isFavorite"] is True, r.text
r = c.get("/favorites/ids", params={"targetType": "quizSet"})
assert "set_tong_hop_1" in r.json()["data"], r.text
r = c.delete("/favorites", params={
    "targetId": "set_tong_hop_1", "targetType": "quizSet"
})
assert r.status_code == 200, r.text
r = c.post("/favorites", json={"targetId": "topic_tong_hop", "targetType": "topic"})
assert r.status_code == 200 and r.json()["data"]["isFavorite"] is True, r.text
r = c.get("/favorites/status", params={
    "targetId": "topic_tong_hop", "targetType": "topic"
})
assert r.json()["data"]["isFavorite"] is True, r.text
r = c.delete("/favorites", params={
    "targetId": "topic_tong_hop", "targetType": "topic"
})
assert r.status_code == 200, r.text

r = c.get("/store/items")
assert r.status_code == 200 and r.json()["data"]["coins"] == 160, r.text
khung_ids = {
    item["id"]
    for item in r.json()["data"]["items"]
    if item["type"] == "frame"
}
assert khung_ids == {
    "item_frame_gold",
    "item_frame_neon",
    "item_frame_silver",
    "item_frame_fire",
}, r.text
r = c.post("/store/purchase", json={"itemId": "item_frame_gold"})
assert r.status_code == 200 and r.json()["data"]["coins"] == 60, r.text
r = c.post("/store/equip", json={"itemId": "item_frame_gold", "equipped": True})
assert r.status_code == 200, r.text
profile = c.get("/me").json()["data"]
assert any(item["itemId"] == "item_frame_gold" for item in profile["equippedItems"])

help_attempt = c.post(
    "/quiz/start", json={"quizSetId": "set_tong_hop_1"}
).json()["data"]
r = c.post("/quiz/help", json={
    "attemptId": help_attempt["attemptId"], "helpType": "extra_time"
})
assert r.status_code == 200 and r.json()["data"]["coins"] == 40, r.text
r = c.post("/quiz/help", json={
    "attemptId": help_attempt["attemptId"], "helpType": "extra_time"
})
assert r.status_code == 409, r.text
original_question = help_attempt["questions"][0]["id"]
original_slot = help_attempt["questions"][0]["slotId"]
r = c.post("/quiz/help", json={
    "attemptId": help_attempt["attemptId"],
    "questionId": original_question,
    "answerId": original_slot,
    "helpType": "change_question",
})
assert r.status_code == 200 and r.json()["data"]["question"]["id"] != original_question, r.text
assert r.json()["data"]["otherQuestion"]["id"] == original_question, r.text
assert r.json()["data"]["coins"] == 10, r.text
r = c.post("/quiz/help", json={
    "attemptId": help_attempt["attemptId"],
    "questionId": original_question,
    "answerId": original_slot,
    "helpType": "change_question",
})
assert r.status_code == 409, r.text

r = c.get("/topics", headers={"Authorization": ""})


# Admin management endpoints are restricted to administrators and support CRUD.
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=UID, role="user"
)
assert c.get("/admin/items").status_code == 403
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)

sets = c.get("/admin/quiz-sets")
assert sets.status_code == 200 and any(
    row["id"] == "set_tong_hop_1" for row in sets.json()["data"]
), sets.text
questions = c.get("/admin/quiz-sets/set_tong_hop_1/questions")
assert questions.status_code == 200 and questions.json()["data"], questions.text
assert "correctIndex" in questions.json()["data"][0]

items = c.get("/admin/items")
assert items.status_code == 200 and any(
    row["id"] == "item_frame_gold" for row in items.json()["data"]
), items.text
created_item = c.post("/admin/items", json={
    "name": "Smoke hint", "type": "help", "lifelineCode": "fifty_fifty",
    "price": 15, "description": "Smoke test",
})
assert created_item.status_code == 200, created_item.text
item_id = created_item.json()["data"]["id"]
updated_item = c.put(f"/admin/items/{item_id}", json={
    "name": "Updated smoke hint", "type": "help",
    "lifelineCode": "fifty_fifty", "price": 20,
})
assert updated_item.status_code == 200
assert updated_item.json()["data"]["price"] == 20
assert c.delete(f"/admin/items/{item_id}").status_code == 200

created_title = c.post("/admin/items", json={
    "name": "Danh hiệu Cao thủ", "type": "title", "price": 150,
})
assert created_title.status_code == 200, created_title.text
assert created_title.json()["data"]["id"] == "item_title_danh_hieu_cao_thu"
duplicate_title = c.post("/admin/items", json={
    "name": "Danh hiệu Cao thủ", "type": "title", "price": 150,
})
assert duplicate_title.status_code == 200, duplicate_title.text
assert duplicate_title.json()["data"]["id"] == "item_title_danh_hieu_cao_thu_2"
assert c.delete(
    f"/admin/items/{created_title.json()['data']['id']}"
).status_code == 200
assert c.delete(
    f"/admin/items/{duplicate_title.json()['data']['id']}"
).status_code == 200
custom_title = c.post("/admin/items", json={
    "id": "item_title_champion", "name": "Danh hiệu Nhà vô địch",
    "type": "title", "price": 200,
})
assert custom_title.status_code == 200, custom_title.text
assert custom_title.json()["data"]["id"] == "item_title_champion"
duplicate_id = c.post("/admin/items", json={
    "id": "item_title_champion", "name": "Danh hiệu khác",
    "type": "title", "price": 200,
})
assert duplicate_id.status_code == 200, duplicate_id.text
assert duplicate_id.json()["data"]["id"] == "item_title_champion_2"
assert c.post("/admin/items", json={
    "id": "invalid_title", "name": "Danh hiệu lỗi",
    "type": "title", "price": 100,
}).status_code == 400
assert c.delete(
    f"/admin/items/{custom_title.json()['data']['id']}"
).status_code == 200
assert c.delete(
    f"/admin/items/{duplicate_id.json()['data']['id']}"
).status_code == 200

users = c.get("/admin/users")
assert users.status_code == 200 and any(
    row["uid"] == UID and row["gamesPlayed"] >= 1 for row in users.json()["data"]
), users.text
assert c.get("/admin/users", params={"search": "TU001A"}).json()["data"]
locked = c.put(f"/admin/users/{UID}/status", json={"status": "locked"})
assert locked.status_code == 200 and locked.json()["data"]["status"] == "locked"
unlocked = c.put(f"/admin/users/{UID}/status", json={"status": "active"})
assert unlocked.status_code == 200 and unlocked.json()["data"]["status"] == "active"

from app.models import Report
db = SessionLocal()
db.add(Report(question_id=questions.json()["data"][0]["id"], user_id=UID,
              reason="Smoke test report"))
db.commit()
db.close()
reports = c.get("/admin/reports")
assert reports.status_code == 200 and any(
    row["reason"] == "Smoke test report" for row in reports.json()["data"]
), reports.text
report_id = reports.json()["data"][0]["id"]
report_update = c.put(
    f"/admin/reports/{report_id}/status", json={"status": "resolved"}
)
assert report_update.status_code == 200
assert report_update.json()["data"]["status"] == "resolved"

topic_response = c.post("/admin/topics", json={
    "id": "topic_crud_topic",
    "name": "CRUD topic", "description": "Temporary topic",
    "icon": "T", "imageUrl": "", "isActive": True,
})
assert topic_response.status_code == 200, topic_response.text
topic_id = topic_response.json()["data"]["id"]
assert topic_id == "topic_crud_topic"
assert topic_response.json()["data"]["questionCount"] == 0
duplicate_topic = c.post("/admin/topics", json={
    "id": "topic_crud_topic", "name": "Duplicate topic",
})
assert duplicate_topic.status_code == 200, duplicate_topic.text
assert duplicate_topic.json()["data"]["id"] == "topic_crud_topic_2"
assert c.delete(
    f"/admin/topics/{duplicate_topic.json()['data']['id']}"
).status_code == 200
topic_update = c.put(f"/admin/topics/{topic_id}", json={
    "name": "Updated CRUD topic", "description": "Updated",
    "icon": "T", "imageUrl": "", "isActive": True,
})
assert topic_update.status_code == 200

question_response = c.post("/admin/questions", json={
    "topicId": topic_id,
    "content": "Manual selection question",
    "options": ["A", "B", "C", "D"],
    "correctIndex": 2,
    "level": "medium",
    "explanation": "Test answer",
    "isActive": True,
})
assert question_response.status_code == 200, question_response.text
question_id = question_response.json()["data"]["id"]
topic_rows = c.get("/admin/topics").json()["data"]
assert next(row for row in topic_rows if row["id"] == topic_id)[
    "questionCount"
] == 1
assert c.get("/admin/questions", params={"topicId": topic_id}).json()["data"]
question_update = c.put(f"/admin/questions/{question_id}", json={
    "topicId": topic_id,
    "content": "Updated manual question",
    "options": ["A", "B", "C", "D"],
    "correctIndex": 0,
    "level": "hard",
    "explanation": "",
    "isActive": True,
})
assert question_update.status_code == 200
assert question_update.json()["data"]["correctIndex"] == 0

manual_set = c.post("/admin/quiz-sets", json={
    "id": "set_manual_question_set",
    "topicId": topic_id,
    "title": "Manual question set",
    "description": "",
    "level": "hard",
    "durationSec": 90,
    "questionCount": 1,
    "isActive": True,
    "selectionMode": "manual",
    "questionIds": [question_id],
})
assert manual_set.status_code == 200, manual_set.text
manual_set_id = manual_set.json()["data"]["id"]
assert manual_set_id == "set_manual_question_set"
assert manual_set.json()["data"]["questionIds"] == [question_id]
assert manual_set.json()["data"]["attemptCount"] == 0
assert manual_set.json()["data"]["avgScore"] == 0
duplicate_set = c.post("/admin/quiz-sets", json={
    "id": "set_manual_question_set",
    "topicId": topic_id,
    "title": "Duplicate manual set",
    "durationSec": 90,
    "questionCount": 1,
    "selectionMode": "manual",
    "questionIds": [question_id],
})
assert duplicate_set.status_code == 200, duplicate_set.text
assert duplicate_set.json()["data"]["id"] == "set_manual_question_set_2"
assert c.delete(
    f"/admin/quiz-sets/{duplicate_set.json()['data']['id']}"
).status_code == 200
manual_questions = c.get(
    f"/admin/quiz-sets/{manual_set_id}/questions"
)
assert [row["id"] for row in manual_questions.json()["data"]] == [question_id]

app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=UID, role="user"
)
manual_attempt = c.post(
    "/quiz/start", json={"quizSetId": manual_set_id}
)
assert manual_attempt.status_code == 200, manual_attempt.text
assert [row["id"] for row in manual_attempt.json()["data"]["questions"]] == [
    question_id
]
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
assert c.delete(f"/admin/questions/{question_id}").status_code == 409
assert c.delete(f"/admin/quiz-sets/{manual_set_id}").status_code == 409
assert c.delete(f"/admin/topics/{topic_id}").status_code == 409

with tempfile.TemporaryDirectory() as temp_dir:
    auth_engine = create_engine(
        URL.create("sqlite", database=os.path.join(temp_dir, "auth.db")),
        connect_args={"check_same_thread": False},
    )
    Base.metadata.create_all(bind=auth_engine)
    with auth_engine.begin() as conn:
        conn.execute(text("CREATE UNIQUE INDEX users_email_unique ON users (email)"))
    auth_session_factory = sessionmaker(bind=auth_engine)
    auth_db: DbSession = auth_session_factory()
    concurrent_db: DbSession = auth_session_factory()
    original_commit = auth_db.commit

    def commit_after_concurrent_user():
        concurrent_db.add(
            User(
                uid="local-dev-user",
                email="dev@local.test",
                user_code="ABC123",
            )
        )
        concurrent_db.commit()
        original_commit()

    auth_db.commit = commit_after_concurrent_user
    with patch.object(auth_module, "_has_firebase_credentials", return_value=False):
        created = get_current_user("", auth_db)
    assert created.uid == "local-dev-user"
    auth_db.commit = original_commit

    payload = base64.urlsafe_b64encode(
        json.dumps(
            {"uid": "different-firebase-uid", "email": "dev@local.test"}
        ).encode()
    ).decode().rstrip("=")
    with patch.object(auth_module, "_has_firebase_credentials", return_value=False):
        try:
            get_current_user(f"Bearer e30.{payload}.signature", auth_db)
            raise AssertionError("Expected conflicting email to return 409")
        except ApiError as exc:
            assert exc.status == 409
            assert exc.code == "ACCOUNT_EMAIL_CONFLICT"

    auth_db.close()
    concurrent_db.close()
    auth_engine.dispose()


print("ALL SMOKE TESTS PASSED")
