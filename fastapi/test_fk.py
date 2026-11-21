"""Test VOI BAT KIEM TRA KHOA NGOAI (nhu Postgres tren Supabase).
SQLite mac dinh tat FK nen test_smoke.py khong bat duoc loi chen sai thu tu.
Chay:  python test_fk.py"""
import os
os.environ["DATABASE_URL"] = "sqlite:///./test_fk.db"
if os.path.exists("test_fk.db"):
    os.remove("test_fk.db")
from sqlalchemy import event
from app.database import Base, engine
event.listen(engine, "connect", lambda c, _: c.execute("PRAGMA foreign_keys=ON"))
from fastapi.testclient import TestClient
from app.auth import CurrentUser, get_current_user
from app.main import app
from app.seed import seed

Base.metadata.create_all(bind=engine)
seed("seed-data-3-chu-de.json")
UID = "VFLqQiv8AnOvWt7lhfXnNtmfKcu2"
ADMIN = "tTUzRgv5gseRFwPWHJycH2gB4mP2"
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=UID, role="user")
c = TestClient(app, raise_server_exceptions=False)
r = c.post("/quiz/start", json={"quizSetId": "set_tong_hop_1"})
assert r.status_code == 200, r.text
start = r.json()["data"]
att = start["attemptId"]
from app.database import SessionLocal
from app.models import AttemptAnswer
db = SessionLocal()
keys = {a.question_id: a.correct_index for a in
        db.query(AttemptAnswer).filter(AttemptAnswer.attempt_id == att).all()}
db.close()
answers = [{"questionId": q["id"], "selectedIndex": keys[q["id"]]} for q in start["questions"]]
r = c.post("/quiz/submit", json={"attemptId": att, "quizSetId": "set_tong_hop_1",
                                 "answers": answers, "timeTakenSec": 56})
assert r.status_code == 200, r.text
assert r.json()["data"]["score"] == 180, r.text
r = c.post("/quiz-sets/set_tong_hop_1/comments", json={"rating": 5, "content": "Hay"})
assert r.status_code == 200, r.text
app.dependency_overrides[get_current_user] = lambda: CurrentUser(uid=ADMIN, role="admin")
r = c.get("/admin/stats")
assert r.status_code == 200 and r.json()["data"]["totals"]["attempts"] == 1, r.text
print("FK TEST PASSED (seed + start + submit 180 + comment + admin, FK bat)")
