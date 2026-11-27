"""Bang SQL — anh xa 1-1 tu 16 collection Firestore (ERD 3.2) sang bang quan he.
Khoa chinh giu nguyen id cu (topic_tong_hop, set_tong_hop_1, q_th_01...)
nen du lieu seed cu dung lai duoc, khong can doi Flutter.

QUAN TRONG (sua 18/11): phai khai relationship() cho moi khoa ngoai, khong chi
viet ForeignKey. SQLAlchemy chi xep thu tu INSERT theo khoa ngoai KHI CO
relationship — khong co thi no xep theo ten class A-Z ("Question" < "Topic"
nen no chen questions truoc ca topics -> loi ForeignKeyViolation tren
Postgres; SQLite khong kiem tra FK nen smoke test cu khong bat duoc).
Day cung la loi tiem an o /quiz/submit (HistoryDetail chen truoc QuizHistory)."""
import uuid
from datetime import datetime
from sqlalchemy import JSON, Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import declarative_base, relationship
from .database import Base

def _now():
    return datetime.utcnow()

class User(Base):
    __tablename__ = "users"
    uid = Column(String, primary_key=True)  # Firebase UID, vd VFLqQiv8...
    email = Column(String, default="")
    display_name = Column(String, default="")
    avatar_url = Column(String, default="")
    role = Column(String, default="user")  # user | admin
    score = Column(Integer, default=0)
    weekly_score = Column(Integer, default=0)
    monthly_score = Column(Integer, default=0)
    coins = Column(Integer, default=100)
    status = Column(String, default="active")
    user_code = Column(String, default="")
    created_at = Column(DateTime, default=_now)
    updated_at = Column(DateTime, default=_now)
    attempts = relationship("Attempt", back_populates="user")
    histories = relationship("QuizHistory", back_populates="user")
    transactions = relationship("Transaction", back_populates="user")
    comments = relationship("Comment", back_populates="user")
    favorites = relationship("Favorite", back_populates="user")
    user_items = relationship("UserItem", back_populates="user")
    match_queue_entries = relationship("MatchQueue", back_populates="user")
    notifications = relationship("Notification", back_populates="user")
    hosted_rooms = relationship("Room", back_populates="host", foreign_keys="Room.host_id")
    guest_rooms = relationship("Room", back_populates="guest", foreign_keys="Room.guest_id")

class Topic(Base):
    __tablename__ = "topics"
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String, default="")
    icon = Column(String, default="")
    image_url = Column(String, default="")
    is_active = Column(Boolean, default=True)
    question_count = Column(Integer, default=0)
    quiz_sets = relationship("QuizSet", back_populates="topic")
    questions = relationship("Question", back_populates="topic")

class QuizSet(Base):
    __tablename__ = "quiz_sets"
    id = Column(String, primary_key=True)
    topic_id = Column(String, ForeignKey("topics.id"), nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, default="")
    difficulty = Column(String, default="")
    duration_sec = Column(Integer, default=300)
    question_count = Column(Integer, default=10)
    is_active = Column(Boolean, default=True)
    attempt_count = Column(Integer, default=0)
    avg_score = Column(Integer, default=0)
    topic = relationship("Topic", back_populates="quiz_sets")
    attempts = relationship("Attempt", back_populates="quiz_set")
    histories = relationship("QuizHistory", back_populates="quiz_set")
    comments = relationship("Comment", back_populates="quiz_set")
    question_links = relationship(
        "QuizSetQuestion",
        back_populates="quiz_set",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

class Question(Base):
    __tablename__ = "questions"
    id = Column(String, primary_key=True)
    topic_id = Column(String, ForeignKey("topics.id"), nullable=False)
    content = Column(String, nullable=False)
    options = Column(JSON, default=list)  # 4 lua chon, dung thu tu goc
    correct_index = Column(Integer, nullable=False)
    level = Column(String, default="easy")  # easy | medium | hard
    explanation = Column(String, default="")
    is_active = Column(Boolean, default=True)
    topic = relationship("Topic", back_populates="questions")
    quiz_set_links = relationship("QuizSetQuestion", passive_deletes="all")


class QuizSetQuestion(Base):
    __tablename__ = "quiz_set_questions"
    quiz_set_id = Column(
        String, ForeignKey("quiz_sets.id", ondelete="CASCADE"), primary_key=True
    )
    question_id = Column(
        String, ForeignKey("questions.id", ondelete="RESTRICT"), primary_key=True
    )
    position = Column(Integer, nullable=False, default=0)
    quiz_set = relationship("QuizSet", back_populates="question_links")
    question = relationship("Question", back_populates="quiz_set_links")

class Attempt(Base):
    __tablename__ = "attempts"
    id = Column(String, primary_key=True)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    quiz_set_id = Column(String, ForeignKey("quiz_sets.id"), nullable=False)
    topic_id = Column(String, nullable=False)
    duration_sec = Column(Integer, default=300)
    submitted = Column(Boolean, default=False)
    helps_used = Column(JSON, default=dict)  # {questionId: "fifty_fifty"}
    created_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="attempts")
    quiz_set = relationship("QuizSet", back_populates="attempts")
    answers = relationship("AttemptAnswer", back_populates="attempt")

class AttemptAnswer(Base):
    __tablename__ = "attempt_answers"
    id = Column(Integer, primary_key=True, autoincrement=True)
    attempt_id = Column(String, ForeignKey("attempts.id"), nullable=False)
    question_id = Column(String, ForeignKey("questions.id"), nullable=False)
    correct_index = Column(Integer, nullable=False)  # vi tri dung SAU KHI xao
    options = Column(JSON, default=list)  # 4 lua chon theo thu tu da xao
    level = Column(String, default="easy")
    attempt = relationship("Attempt", back_populates="answers")
    question = relationship("Question")

class QuizHistory(Base):
    __tablename__ = "quiz_histories"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    quiz_set_id = Column(String, ForeignKey("quiz_sets.id"), nullable=False)
    topic_id = Column(String, nullable=False)
    score = Column(Integer, default=0)
    correct_count = Column(Integer, default=0)
    total_count = Column(Integer, default=0)
    coins_earned = Column(Integer, default=0)
    time_taken_sec = Column(Integer, default=0)
    created_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="histories")
    quiz_set = relationship("QuizSet", back_populates="histories")
    details = relationship("HistoryDetail", back_populates="history")

class HistoryDetail(Base):
    __tablename__ = "history_details"
    id = Column(Integer, primary_key=True, autoincrement=True)
    history_id = Column(String, ForeignKey("quiz_histories.id"), nullable=False)
    question_id = Column(String, nullable=False)
    selected_index = Column(Integer, default=-1)
    correct_index = Column(Integer, default=-1)
    is_correct = Column(Boolean, default=False)
    options = Column(JSON, default=list)  # 4 lua chon theo thu tu da xao
    level = Column(String, default="easy")
    history = relationship("QuizHistory", back_populates="details")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    type = Column(String, default="earn")  # earn | spend
    amount = Column(Integer, default=0)
    reason = Column(String, default="")
    related_id = Column(String, default="")
    created_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="transactions")

class Comment(Base):
    __tablename__ = "comments"
    id = Column(Integer, primary_key=True, autoincrement=True)
    quiz_set_id = Column(String, ForeignKey("quiz_sets.id"), nullable=False)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    rating = Column(Integer, default=5)
    content = Column(String, default="")
    created_at = Column(DateTime, default=_now)
    quiz_set = relationship("QuizSet", back_populates="comments")
    user = relationship("User", back_populates="comments")

class Item(Base):
    __tablename__ = "items"
    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String, default="")
    effect = Column(String, default="")
    price = Column(Integer, default=0)
    type = Column(String, default="help")
    is_active = Column(Boolean, default=True)
    user_items = relationship("UserItem", back_populates="item")

class Report(Base):
    __tablename__ = "reports"
    id = Column(Integer, primary_key=True, autoincrement=True)
    question_id = Column(String, nullable=False)
    user_id = Column(String, default="")
    reason = Column(String, default="")
    status = Column(String, default="pending")

class Friend(Base):
    __tablename__ = "friends"
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    friend_id = Column(String, ForeignKey("users.uid"), nullable=False)
    status = Column(String, default="accepted")
    user = relationship("User", foreign_keys=[user_id])
    friend = relationship("User", foreign_keys=[friend_id])


class Favorite(Base):
    """3.2.7 — danh sach chu de / bo de yeu thich cua user."""
    __tablename__ = "favorites"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    target_id = Column(String, nullable=False)  # id cua Topic hoac QuizSet
    target_type = Column(String, nullable=False)  # 'topic' | 'quizSet'
    created_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="favorites")

class UserItem(Base):
    """3.2.9 — tui do ca nhan (so luong tro giup / trang thai trang bi)."""
    __tablename__ = "user_items"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    item_id = Column(String, ForeignKey("items.id"), nullable=False)
    quantity = Column(Integer, default=1)
    equipped = Column(Boolean, default=False)
    user = relationship("User", back_populates="user_items")
    item = relationship("Item", back_populates="user_items")

class Room(Base):
    """3.2.12 — phong thi dau doi khang 1vs1."""
    __tablename__ = "rooms"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    host_id = Column(String, ForeignKey("users.uid"), nullable=False)
    guest_id = Column(String, ForeignKey("users.uid"), nullable=True)
    status = Column(String, default="waiting")  # waiting|ready|playing|finished|cancelled
    question_ids = Column(JSON, default=list)  # 10 cau chung cua tran
    current_question_index = Column(Integer, default=0)
    question_start_time = Column(DateTime, nullable=True)
    host_score = Column(Integer, default=0)
    guest_score = Column(Integer, default=0)
    created_at = Column(DateTime, default=_now)
    host = relationship("User", back_populates="hosted_rooms", foreign_keys=[host_id])
    guest = relationship("User", back_populates="guest_rooms", foreign_keys=[guest_id])
    match_history = relationship("MatchHistory", back_populates="room", uselist=False)

class MatchHistory(Base):
    """3.2.13 — ket qua + dien bien tran doi khang da xong (1 Room = 1 lich su)."""
    __tablename__ = "match_histories"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    room_id = Column(String, ForeignKey("rooms.id"), nullable=False)
    player1_id = Column(String, ForeignKey("users.uid"), nullable=False)
    player2_id = Column(String, ForeignKey("users.uid"), nullable=False)
    score1 = Column(Integer, default=0)
    score2 = Column(Integer, default=0)
    winner_id = Column(String, ForeignKey("users.uid"), nullable=True)  # null khi hoa
    details = Column(JSON, default=list)  # [{questionId, p1Selected, p2Selected, p1Time, p2Time}]
    created_at = Column(DateTime, default=_now)
    room = relationship("Room", back_populates="match_history")
    player1 = relationship("User", foreign_keys=[player1_id])
    player2 = relationship("User", foreign_keys=[player2_id])
    winner = relationship("User", foreign_keys=[winner_id])

class MatchQueue(Base):
    """3.2.14 — hang doi ghep doi thu ngau nhien theo diem."""
    __tablename__ = "match_queue"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)
    score = Column(Integer, default=0)
    status = Column(String, default="waiting")  # waiting | matched | cancelled
    joined_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="match_queue_entries")

class Notification(Base):
    """3.2.16 — thong bao loi moi ket ban / thach dau / he thong."""
    __tablename__ = "notifications"
    id = Column(String, primary_key=True, default=lambda: uuid.uuid4().hex)
    user_id = Column(String, ForeignKey("users.uid"), nullable=False)  # nguoi nhan
    type = Column(String, nullable=False)  # friend_request | match_invite | system
    ref_id = Column(String, default="")  # id cua Friend hoac Room lien quan
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_now)
    user = relationship("User", back_populates="notifications")
