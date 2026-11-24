import os
import sys

os.environ["DATABASE_URL"] = "sqlite:///./test_vuong.db"
if os.path.exists("test_vuong.db"):
    os.remove("test_vuong.db")

sys.path.insert(0, ".")
from fastapi.testclient import TestClient

from app.auth import CurrentUser, get_current_user
from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import Item, MatchHistory, Question, Room, Topic, User

Base.metadata.create_all(bind=engine)
USER_A = "vuong-pvp-test-a"
USER_B = "vuong-pvp-test-b"
db = SessionLocal()
db.add_all([
    User(uid=USER_A, email="a@test.invalid", display_name="Người chơi A",
         user_code="VPA111", coins=100),
    User(uid=USER_B, email="b@test.invalid", display_name="Người chơi B",
         user_code="VPB222", coins=100),
])
db.commit()
db.add(Topic(id="pvp-test-topic", name="PvP test", is_active=True))
db.commit()
for index in range(10):
    db.add(Question(
        id=f"pvp-test-question-{index}",
        topic_id="pvp-test-topic",
        content=f"Câu hỏi {index}",
        options=["Đúng", "Sai 1", "Sai 2", "Sai 3"],
        correct_index=0,
        is_active=True,
    ))
db.add(Item(
    id="pvp-test-help",
    name="Trợ giúp test",
    price=20,
    type="help",
    is_active=True,
))
db.commit()
db.close()


def use_user(uid):
    app.dependency_overrides[get_current_user] = lambda: CurrentUser(
        uid=uid, role="user"
    )


client = TestClient(app, raise_server_exceptions=False)
use_user(USER_A)
assert client.get("/health").status_code == 200
assert client.get("/friends/search", params={"q": "VPB222"}).json()["data"][0][
    "uid"
] == USER_B
request = client.post(f"/friends/{USER_B}")
assert request.status_code == 200 and request.json()["data"]["status"] == "pending"
request_id = request.json()["data"]["id"]
use_user(USER_B)
assert client.post(f"/friends/{request_id}/accept").status_code == 200
use_user(USER_A)
assert len(client.get("/friends").json()["data"]) == 1

catalog = client.get("/store/items")
assert catalog.status_code == 200 and catalog.json()["data"]["coins"] == 100
purchase = client.post("/store/purchase", json={"itemId": "pvp-test-help"})
assert purchase.status_code == 200 and purchase.json()["data"]["coins"] == 80
inventory = client.get("/store/inventory").json()["data"]
assert inventory["userItems"][0]["quantity"] == 1

assert client.post("/pvp/queue").json()["data"]["status"] == "waiting"
use_user(USER_B)
matched = client.post("/pvp/queue")
assert matched.status_code == 200 and matched.json()["data"]["status"] == "matched"
room_id = matched.json()["data"]["roomId"]
use_user(USER_A)
room = client.get(f"/pvp/rooms/{room_id}")
assert room.status_code == 200 and "correctIndex" not in str(room.json()["data"])

for question_index in range(10):
    db = SessionLocal()
    room_record = db.query(Room).filter(Room.id == room_id).first()
    correct_index = room_record.question_ids[question_index]["correctIndex"]
    db.close()
    for uid in (USER_A, USER_B):
        use_user(uid)
        answer = client.post(
            f"/pvp/rooms/{room_id}/answer",
            json={
                "questionIndex": question_index,
                "selectedIndex": correct_index,
            },
        )
        assert answer.status_code == 200, answer.text
        if uid == USER_A and question_index == 0:
            assert answer.json()["data"]["myAnswered"] is True
            duplicate = client.post(
                f"/pvp/rooms/{room_id}/answer",
                json={
                    "questionIndex": question_index,
                    "selectedIndex": correct_index,
                },
            )
            assert duplicate.status_code == 409

use_user(USER_A)
result = client.get(f"/pvp/rooms/{room_id}").json()["data"]
assert result["status"] == "finished" and result["hostScore"] == 100
db = SessionLocal()
history = db.query(MatchHistory).filter(MatchHistory.room_id == room_id).first()
assert history is not None and len(history.details) == 10
db.close()

invite = client.post(f"/pvp/invite/{USER_B}")
assert invite.status_code == 200
friend_room_id = invite.json()["data"]["roomId"]
use_user(USER_B)
assert any(
    item["roomId"] == friend_room_id
    for item in client.get("/pvp/invitations").json()["data"]
)
accepted = client.post(f"/pvp/rooms/{friend_room_id}/accept")
assert accepted.status_code == 200 and accepted.json()["data"]["status"] == "playing"

print("VUONG API SMOKE TESTS PASSED")
