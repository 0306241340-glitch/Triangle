from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..auth import CurrentUser, require_admin
from ..database import get_db
from ..errors import ok
from ..models import Question, QuizHistory, QuizSet, Report, Topic, User

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
