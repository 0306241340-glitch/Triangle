"""Choi don — logic cham diem giong het Express (quiz.js):
Dễ 10đ/5xu, TB 20đ/10xu, Khó 30đ/15xu; dung het 10 cau = 180đ/90xu.
correctIndex KHONG bao gio tra ve client; chi luu trong attempt_answers."""
import random
import time
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Attempt, AttemptAnswer, HistoryDetail, Question, QuizHistory, QuizSet, Transaction, User
from ..schemas import FiftyFiftyIn, StartIn, SubmitIn

router = APIRouter()
POINTS = {"easy": (10, 5), "medium": (20, 10), "hard": (30, 15)}

def _shuffle(a):
    a = list(a)
    random.shuffle(a)
    return a

@router.post("/start")
def start(body: StartIn, user: CurrentUser = Depends(get_current_user),
          db: Session = Depends(get_db)):
    s = db.query(QuizSet).filter(QuizSet.id == body.quizSetId).first()
    if not s or not s.is_active:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")
    qs = (db.query(Question).filter(Question.topic_id == s.topic_id,
                                    Question.is_active == True).all())
    qs = _shuffle(qs)[: s.question_count or 10]
    if not qs:
        raise ApiError(400, "VALIDATION", "Bộ đề chưa có câu hỏi.")
    attempt_id = f"att_{int(time.time()*1000)}_{user.uid[:6]}"
    att = Attempt(id=attempt_id, user_id=user.uid, quiz_set_id=s.id,
                  topic_id=s.topic_id, duration_sec=s.duration_sec or 300)
    db.add(att)
    out_qs = []
    for q in qs:
        order = _shuffle([0, 1, 2, 3])
        db.add(AttemptAnswer(attempt_id=attempt_id, question_id=q.id,
                             correct_index=order.index(q.correct_index), level=q.level))
        out_qs.append({"id": q.id, "content": q.content,
                       "options": [q.options[i] for i in order], "level": q.level})
    db.commit()
    return ok({"attemptId": attempt_id, "durationSec": s.duration_sec or 300,
               "questions": out_qs})

@router.post("/submit")
def submit(body: SubmitIn, user: CurrentUser = Depends(get_current_user),
           db: Session = Depends(get_db)):
    att = db.query(Attempt).filter(Attempt.id == body.attemptId).first()
    if not att:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lượt chơi này.")
    if att.submitted:
        raise ApiError(409, "CONFLICT", "Lượt chơi này đã nộp rồi, không cộng điểm lần 2.")
    if att.user_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Không phải lượt chơi của bạn.")
    keys = {a.question_id: a for a in
            db.query(AttemptAnswer).filter(AttemptAnswer.attempt_id == att.id).all()}
    score = coins = correct = 0
    details = []
    for a in body.answers:
        k = keys.get(a.questionId)
        is_ok = bool(k) and a.selectedIndex == k.correct_index
        if is_ok:
            correct += 1
            sc, cn = POINTS.get(k.level, (10, 5))
            score += sc
            coins += cn
        details.append({"questionId": a.questionId, "selectedIndex": a.selectedIndex,
                        "correctIndex": k.correct_index if k else -1,
                        "isCorrect": is_ok, "level": k.level if k else "easy"})
    hist = QuizHistory(user_id=user.uid, quiz_set_id=body.quizSetId, topic_id=att.topic_id,
                       score=score, correct_count=correct, total_count=len(keys),
                       coins_earned=coins, time_taken_sec=body.timeTakenSec or 0)
    db.add(hist)
    db.flush()
    for d in details:
        db.add(HistoryDetail(history_id=hist.id, question_id=d["questionId"],
                             selected_index=d["selectedIndex"], correct_index=d["correctIndex"],
                             is_correct=d["isCorrect"], level=d["level"]))
    u = db.query(User).filter(User.uid == user.uid).first()
    u.score += score
    u.weekly_score += score
    u.monthly_score += score
    u.coins += coins
    db.add(Transaction(user_id=user.uid, type="earn", amount=coins,
                       reason="quiz_reward", related_id=hist.id))
    att.submitted = True
    s = db.query(QuizSet).filter(QuizSet.id == body.quizSetId).first()
    if s:
        s.avg_score = round(((s.avg_score or 0) * (s.attempt_count or 0) + score) /
                            ((s.attempt_count or 0) + 1))
        s.attempt_count = (s.attempt_count or 0) + 1
    db.commit()
    return ok({"score": score, "correctCount": correct, "totalCount": len(keys),
               "coinsEarned": coins, "historyId": hist.id})

def _fifty_fifty(body: FiftyFiftyIn, user, db):
    att = db.query(Attempt).filter(Attempt.id == body.attemptId).first()
    if not att:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lượt chơi này.")
    if att.user_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Không phải lượt chơi của bạn.")
    if att.submitted:
        raise ApiError(409, "CONFLICT", "Lượt chơi này đã nộp rồi.")
    key = (db.query(AttemptAnswer)
           .filter(AttemptAnswer.attempt_id == att.id,
                   AttemptAnswer.question_id == body.questionId).first())
    if not key:
        raise ApiError(404, "NOT_FOUND", "Câu hỏi không thuộc lượt chơi này.")
    used = dict(att.helps_used or {})
    if used.get(body.questionId):
        raise ApiError(409, "CONFLICT", "Câu này đã dùng 50/50 rồi.")
    u = db.query(User).filter(User.uid == user.uid).first()
    if (u.coins or 0) < 30:
        raise ApiError(400, "INSUFFICIENT_COINS", "Không đủ 30 xu để dùng 50/50.")
    wrong = [i for i in range(4) if i != key.correct_index and i != body.selectedIndex]
    hidden = _shuffle(wrong)[:2]
    u.coins -= 30
    used[body.questionId] = "fifty_fifty"
    att.helps_used = used
    db.add(Transaction(user_id=user.uid, type="spend", amount=-30,
                       reason="fifty_fifty", related_id=att.id))
    db.commit()
    return ok({"hiddenIndices": hidden, "coins": u.coins})

@router.post("/fifty-fifty")
def fifty_fifty(body: FiftyFiftyIn, user: CurrentUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    return _fifty_fifty(body, user, db)

@router.post("/use-help")
def use_help(body: FiftyFiftyIn, user: CurrentUser = Depends(get_current_user),
             db: Session = Depends(get_db)):
    return _fifty_fifty(body, user, db)  # alias, phong khi Flutter goi ten cu

@router.get("/history")
def history(topicId: str = Query(default=""), page: int = Query(default=1),
            user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    q = db.query(QuizHistory).filter(QuizHistory.user_id == user.uid)
    if topicId:
        q = q.filter(QuizHistory.topic_id == topicId)
    rows = q.order_by(QuizHistory.created_at.desc()).offset((page - 1) * 20).limit(20).all()
    return ok([{"id": h.id, "quizSetId": h.quiz_set_id, "topicId": h.topic_id,
                "score": h.score, "correctCount": h.correct_count,
                "totalCount": h.total_count, "coinsEarned": h.coins_earned,
                "timeTakenSec": h.time_taken_sec,
                "createdAt": h.created_at.isoformat() if h.created_at else None}
               for h in rows])

@router.get("/history/{hid}")
def history_detail(hid: str, user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    h = db.query(QuizHistory).filter(QuizHistory.id == hid, QuizHistory.user_id == user.uid).first()
    if not h:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lượt chơi.")
    ds = db.query(HistoryDetail).filter(HistoryDetail.history_id == hid).all()
    return ok({"id": h.id, "quizSetId": h.quiz_set_id, "score": h.score,
               "correctCount": h.correct_count, "totalCount": h.total_count,
               "coinsEarned": h.coins_earned, "timeTakenSec": h.time_taken_sec,
               "details": [{"questionId": d.question_id, "selectedIndex": d.selected_index,
                            "correctIndex": d.correct_index, "isCorrect": d.is_correct,
                            "level": d.level} for d in ds]})
