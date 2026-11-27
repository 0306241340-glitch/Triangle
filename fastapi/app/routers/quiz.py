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
from ..models import Attempt, AttemptAnswer, HistoryDetail, Question, QuizHistory, QuizSet, QuizSetQuestion, Transaction, User
from ..schemas import FiftyFiftyIn, HelpIn, StartIn, SubmitIn

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
    question_links = (
        db.query(QuizSetQuestion)
        .filter(QuizSetQuestion.quiz_set_id == s.id)
        .order_by(QuizSetQuestion.position)
        .all()
    )
    if question_links:
        question_ids = [link.question_id for link in question_links]
        questions_by_id = {
            question.id: question
            for question in db.query(Question)
            .filter(Question.id.in_(question_ids), Question.is_active.is_(True))
            .all()
        }
        if len(questions_by_id) != len(question_ids):
            raise ApiError(
                400,
                "VALIDATION",
                "Bộ đề có câu hỏi đã bị ẩn hoặc không còn hợp lệ.",
            )
        qs = [questions_by_id[question_id] for question_id in question_ids]
    else:
        qs = (
            db.query(Question)
            .filter(
                Question.topic_id == s.topic_id,
                Question.is_active.is_(True),
            )
            .all()
        )
        qs = _shuffle(qs)[: s.question_count or 10]
    if not qs:
        raise ApiError(400, "VALIDATION", "Bộ đề chưa có câu hỏi.")
    attempt_id = f"att_{int(time.time()*1000)}_{user.uid[:6]}"
    att = Attempt(id=attempt_id, user_id=user.uid, quiz_set_id=s.id,
                  topic_id=s.topic_id, duration_sec=s.duration_sec or 300)
    db.add(att)
    db.flush()
    out_qs = []
    for q in qs:
        order = _shuffle([0, 1, 2, 3])
        shuffled_options = [q.options[i] for i in order]
        answer = AttemptAnswer(attempt_id=attempt_id, question_id=q.id,
                               correct_index=order.index(q.correct_index),
                               options=shuffled_options, level=q.level)
        db.add(answer)
        db.flush()
        out_qs.append({"id": q.id, "topicId": q.topic_id, "content": q.content,
                       "options": shuffled_options, "level": q.level,
                       "slotId": str(answer.id)})
    db.commit()
    db.flush()
    account = db.query(User).filter(User.uid == user.uid).first()
    return ok({"attemptId": attempt_id, "durationSec": s.duration_sec or 300,
               "topicId": s.topic_id, "userCoins": account.coins or 0,
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
    if att.quiz_set_id != body.quizSetId:
        raise ApiError(400, "VALIDATION", "Bộ đề không khớp với lượt chơi.")
    keys = {a.question_id: a for a in
            db.query(AttemptAnswer).filter(AttemptAnswer.attempt_id == att.id).all()}
    answer_ids = [answer.questionId for answer in body.answers]
    if len(answer_ids) != len(set(answer_ids)) or any(qid not in keys for qid in answer_ids):
        raise ApiError(400, "VALIDATION", "Danh sách đáp án không hợp lệ.")
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
                        "isCorrect": is_ok, "options": list(k.options or []) if k else [],
                        "level": k.level if k else "easy"})
    hist = QuizHistory(user_id=user.uid, quiz_set_id=body.quizSetId, topic_id=att.topic_id,
                       score=score, correct_count=correct, total_count=len(keys),
                       coins_earned=coins, time_taken_sec=body.timeTakenSec or 0)
    db.add(hist)
    db.flush()
    for d in details:
        db.add(HistoryDetail(history_id=hist.id, question_id=d["questionId"],
                             selected_index=d["selectedIndex"], correct_index=d["correctIndex"],
                             is_correct=d["isCorrect"], options=d["options"], level=d["level"]))
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
               "answeredCount": len(body.answers), "coinsEarned": coins,
               "userCoins": u.coins, "historyId": hist.id,
               "correctIndices": {qid: k.correct_index for qid, k in keys.items()}})

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


@router.post("/help")
def use_other_help(body: HelpIn, user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    att = db.query(Attempt).filter(Attempt.id == body.attemptId).first()
    if not att:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lượt chơi này.")
    if att.user_id != user.uid:
        raise ApiError(403, "FORBIDDEN", "Không phải lượt chơi của bạn.")
    if att.submitted:
        raise ApiError(409, "CONFLICT", "Lượt chơi này đã nộp rồi.")

    account = db.query(User).filter(User.uid == user.uid).with_for_update().first()
    used = dict(att.helps_used or {})
    if body.helpType == "extra_time":
        key, cost, response = "extra_time", 20, {"addedSeconds": 30}
        if used.get(key):
            raise ApiError(409, "CONFLICT", "Bạn đã dùng thêm thời gian rồi.")
    elif body.helpType == "change_question":
        try:
            answer_id = int(body.answerId)
        except ValueError:
            raise ApiError(400, "VALIDATION", "Vị trí câu hỏi không hợp lệ.")
        answer = db.query(AttemptAnswer).filter(
            AttemptAnswer.attempt_id == att.id,
            AttemptAnswer.id == answer_id,
        ).first()
        if answer is None:
            raise ApiError(404, "NOT_FOUND", "Câu hỏi không thuộc lượt chơi này.")
        if body.questionId and answer.question_id != body.questionId:
            raise ApiError(409, "CONFLICT", "Câu hỏi đã thay đổi, hãy thử lại.")
        key, cost, response = f"change_slot:{answer.id}", 30, {}
        if used.get(key):
            raise ApiError(409, "CONFLICT", "Câu hỏi này đã được đổi.")
        other_answers = db.query(AttemptAnswer).filter(
            AttemptAnswer.attempt_id == att.id,
            AttemptAnswer.id != answer.id,
        ).all()
        if not other_answers:
            raise ApiError(400, "VALIDATION", "Không có câu hỏi khác để thay thế.")
        other_answer = random.choice(other_answers)
        q_map = {
            q.id: q
            for q in db.query(Question).filter(
                Question.id.in_([answer.question_id, other_answer.question_id])
            ).all()
        }
        current_question = q_map.get(answer.question_id)
        other_question = q_map.get(other_answer.question_id)
        if (current_question is None or other_question is None or
                len(current_question.options or []) < 2 or
                len(other_question.options or []) < 2):
            raise ApiError(400, "VALIDATION", "Câu hỏi thay thế không hợp lệ.")

        answer.question_id, other_answer.question_id = (
            other_answer.question_id, answer.question_id,
        )
        current_order = _shuffle(list(range(len(other_question.options))))
        other_order = _shuffle(list(range(len(current_question.options))))
        current_options = [other_question.options[i] for i in current_order]
        other_options = [current_question.options[i] for i in other_order]
        answer.correct_index = current_order.index(other_question.correct_index)
        answer.options = current_options
        answer.level = other_question.level
        other_answer.correct_index = other_order.index(current_question.correct_index)
        other_answer.options = other_options
        other_answer.level = current_question.level
        response = {
            "question": {
                "id": other_question.id,
                "topicId": other_question.topic_id,
                "content": other_question.content,
                "options": current_options,
                "level": other_question.level,
                "slotId": str(answer.id),
            },
            "otherQuestion": {
                "id": current_question.id,
                "topicId": current_question.topic_id,
                "content": current_question.content,
                "options": other_options,
                "level": current_question.level,
                "slotId": str(other_answer.id),
            },
            "otherSlotId": str(other_answer.id),
        }
    else:
        raise ApiError(400, "VALIDATION", "Loại trợ giúp không hợp lệ.")

    if (account.coins or 0) < cost:
        raise ApiError(400, "INSUFFICIENT_COINS", f"Không đủ {cost} xu.")
    account.coins -= cost
    used[key] = True
    att.helps_used = used
    db.add(Transaction(user_id=user.uid, type="spend", amount=-cost,
                       reason=body.helpType, related_id=att.id))
    db.commit()
    return ok({**response, "coins": account.coins})

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

def _fallback_history_options(question, correct_index: int) -> list[str]:
    """Fallback cho lịch sử cũ chưa lưu options đã xáo: đảm bảo đáp án đúng nằm ở correct_index."""
    if not question or not question.options:
        return []
    opts = list(question.options)
    if (
        0 <= question.correct_index < len(opts)
        and 0 <= correct_index < len(opts)
        and question.correct_index != correct_index
    ):
        opts[question.correct_index], opts[correct_index] = (
            opts[correct_index],
            opts[question.correct_index],
        )
    return opts


@router.get("/history/{hid}")
def history_detail(hid: str, user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    h = db.query(QuizHistory).filter(QuizHistory.id == hid, QuizHistory.user_id == user.uid).first()
    if not h:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lượt chơi.")
    ds = db.query(HistoryDetail).filter(HistoryDetail.history_id == hid).all()
    question_ids = {detail.question_id for detail in ds}
    questions = {
        question.id: question
        for question in db.query(Question).filter(Question.id.in_(question_ids)).all()
    } if question_ids else {}
    return ok({"id": h.id, "quizSetId": h.quiz_set_id, "score": h.score,
               "correctCount": h.correct_count, "totalCount": h.total_count,
               "coinsEarned": h.coins_earned, "timeTakenSec": h.time_taken_sec,
               "details": [{"questionId": d.question_id,
                            "content": questions[d.question_id].content
                            if d.question_id in questions else "",
                            "options": d.options if d.options else _fallback_history_options(
                                questions.get(d.question_id), d.correct_index
                            ),
                            "explanation": questions[d.question_id].explanation
                            if d.question_id in questions else "",
                            "selectedIndex": d.selected_index,
                            "correctIndex": d.correct_index, "isCorrect": d.is_correct,
                            "level": d.level} for d in ds]})
