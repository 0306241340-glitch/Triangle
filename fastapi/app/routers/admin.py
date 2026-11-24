from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session
from ..auth import CurrentUser, require_admin
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Item, Question, QuizHistory, QuizSet, Report, Topic, User

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
    return ok([
        {
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
        }
        for row in rows
    ])


@router.get("/quiz-sets/{set_id}/questions")
def list_quiz_set_questions(set_id: str, user: CurrentUser = Depends(require_admin),
                            db: Session = Depends(get_db)):
    quiz_set = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if quiz_set is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")

    rows = (
        db.query(Question)
        .filter(Question.topic_id == quiz_set.topic_id, Question.is_active.is_(True))
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
def list_users(user: CurrentUser = Depends(require_admin),
               db: Session = Depends(get_db)):
    rows = db.query(User).order_by(User.display_name, User.email).all()
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
