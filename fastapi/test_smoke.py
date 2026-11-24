"""Smoke test khong can Firebase: override auth bang user gia.
Chay:  python -m pytest test_smoke.py -q   (hoac: python test_smoke.py)"""
import os, sys
from datetime import datetime, timedelta
os.environ["DATABASE_URL"] = "sqlite:///./test_quiz.db"
if os.path.exists("test_quiz.db"):
    os.remove("test_quiz.db")
sys.path.insert(0, ".")
from fastapi.testclient import TestClient
from app.auth import CurrentUser, get_current_user
from app.database import Base, engine
from app.main import app
from app.seed import seed

Base.metadata.create_all(bind=engine)
seed("seed-data-3-chu-de.json")
UID = "VFLqQiv8AnOvWt7lhfXnNtmfKcu2"  # An
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
c = TestClient(app, raise_server_exceptions=False)

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
from app.models import AttemptAnswer, User
db = SessionLocal()
keys = {a.question_id: a.correct_index for a in
        db.query(AttemptAnswer).filter(AttemptAnswer.attempt_id == att).all()}
q0 = start["questions"][0]
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
r = c.get("/friends/requests", params={"direction": "incoming"})
assert [item["id"] for item in r.json()["data"]] == [friendship_id], r.text
r = c.post(f"/friends/{friendship_id}/accept")
assert r.status_code == 200 and r.json()["data"]["status"] == "accepted", r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
r = c.get("/friends")
assert [item["id"] for item in r.json()["data"]] == [friendship_id], r.text

# Random matchmaking and friend challenges use persisted PostgreSQL room state.
from app.models import MatchHistory, Room
r = c.post("/pvp/queue")
assert r.status_code == 200 and r.json()["data"]["status"] == "waiting", r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(
    uid=ADMIN_UID, role="admin"
)
r = c.post("/pvp/queue")
assert r.status_code == 200 and r.json()["data"]["status"] == "matched", r.text
random_room_id = r.json()["data"]["roomId"]
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
r = c.get("/pvp/history")
assert r.status_code == 200 and len(r.json()["data"]) == 1, r.text
match_history_id = r.json()["data"][0]["id"]
r = c.get(f"/pvp/history/{match_history_id}")
assert r.status_code == 200 and len(r.json()["data"]["details"]) == 10, r.text
assert r.json()["data"]["details"][0]["content"], r.text
invite = c.post(f"/pvp/invite/{ADMIN_UID}")
assert invite.status_code == 200 and invite.json()["data"]["status"] == "waiting", invite.text
friend_room_id = invite.json()["data"]["roomId"]
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
db = SessionLocal()
friend_room = db.query(Room).filter(Room.id == friend_room_id).first()
friend_room.question_start_time = datetime.utcnow() - timedelta(seconds=16)
db.commit()
db.close()
timed_out = c.get(f"/pvp/rooms/{friend_room_id}")
assert timed_out.status_code == 200
assert timed_out.json()["data"]["questionIndex"] == 1, timed_out.text
finish_match(friend_room_id, start_index=1)

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
print("ALL SMOKE TESTS PASSED")
