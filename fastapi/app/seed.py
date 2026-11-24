"""Nap du lieu mau 3 chu de tu file seed JSON cu (Firestore) xuong SQL.
Chay:  python -m app.seed [duong-dan-seed-json]
- Chi them moi khi chua co; KHONG ghi de diem/xu cua user da co (An/Ngoc).
- User trong seed chi la dong mau: uid that la cua An/Ngoc, dung de test."""
import json
import sys
from .database import Base, SessionLocal, engine
from .models import Item, Question, QuizSet, Topic, User

def seed(path):
    Base.metadata.create_all(bind=engine)
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    db = SessionLocal()
    try:
        for t in data.get("topics", []):
            if not db.query(Topic).filter(Topic.id == t["id"]).first():
                db.add(Topic(id=t["id"], name=t["name"], description=t.get("description", ""),
                             icon=t.get("icon", ""), image_url=t.get("imageUrl", ""),
                             is_active=t.get("isActive", True),
                             question_count=t.get("questionCount", 0)))
        for s in data.get("quiz_sets", []):
            if not db.query(QuizSet).filter(QuizSet.id == s["id"]).first():
                db.add(QuizSet(id=s["id"], topic_id=s["topicId"], name=s["name"],
                               duration_sec=s.get("durationSec", 300),
                               question_count=s.get("questionCount", 10),
                               is_active=s.get("isActive", True)))
        for q in data.get("questions", []):
            if not db.query(Question).filter(Question.id == q["id"]).first():
                db.add(Question(id=q["id"], topic_id=q["topicId"], content=q["content"],
                                options=q["options"], correct_index=q["correctIndex"],
                                level=q.get("level", "easy"),
                                explanation=q.get("explanation", ""),
                                is_active=q.get("isActive", True)))
        for it in data.get("items", []):
            if not db.query(Item).filter(Item.id == it["id"]).first():
                db.add(Item(id=it["id"], name=it["name"], description=it.get("description", ""),
                            effect=it.get("effect", ""), price=it.get("price", 0),
                            type=it.get("type", "help"), is_active=it.get("isActive", True)))
        for u in data.get("users", []):
            if not db.query(User).filter(User.uid == u["uid"]).first():
                db.add(User(uid=u["uid"], email=u.get("email", ""),
                            display_name=u.get("displayName", ""), role=u.get("role", "user"),
                            score=u.get("score", 0), coins=u.get("coins", 100),
                            weekly_score=u.get("weeklyScore", 0),
                            user_code=u.get("userCode", "")))
        db.commit()
        print(f"Seed xong: {db.query(Topic).count()} topics, "
              f"{db.query(QuizSet).count()} sets, {db.query(Question).count()} questions, "
              f"{db.query(Item).count()} items, {db.query(User).count()} users.")
    finally:
        db.close()

if __name__ == "__main__":
    import os
    default = ("seed-data-3-chu-de.json" if os.path.exists("seed-data-3-chu-de.json")
               else "../files/seed-data-3-chu-de.json")
    seed(sys.argv[1] if len(sys.argv) > 1 else default)
