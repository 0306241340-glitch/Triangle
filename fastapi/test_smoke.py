"""Smoke test khong can Firebase: override auth bang user gia.
Chay:  python -m pytest test_smoke.py -q   (hoac: python test_smoke.py)"""
import os, sys
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
r = c.get("/topics", headers={"Authorization": ""})
print("ALL SMOKE TESTS PASSED")
