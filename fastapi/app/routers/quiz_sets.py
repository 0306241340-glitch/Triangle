from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Comment, QuizSet, User
from ..schemas import CommentIn

router = APIRouter()

def _set_dict(s):
    return {"id": s.id, "topicId": s.topic_id, "name": s.name,
            "description": s.description, "difficulty": s.difficulty,
            "durationSec": s.duration_sec, "questionCount": s.question_count,
            "isActive": s.is_active, "attemptCount": s.attempt_count,
            "avgScore": s.avg_score}

@router.get("")
def list_sets(topicId: str = Query(default=""), level: str = Query(default=""),
              search: str = Query(default=""),
              user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    q = db.query(QuizSet).filter(QuizSet.is_active == True)
    if topicId:
        q = q.filter(QuizSet.topic_id == topicId)
    rows = q.all()
    if level:
        rows = [s for s in rows if s.difficulty == level]
    if search:
        rows = [s for s in rows if search.lower() in (s.name or "").lower()]
    return ok([_set_dict(s) for s in rows])

@router.get("/{set_id}")
def get_set(set_id: str, user: CurrentUser = Depends(get_current_user),
            db: Session = Depends(get_db)):
    s = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if not s:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")
    comments = (db.query(Comment, User.display_name)
                .join(User, User.uid == Comment.user_id)
                .filter(Comment.quiz_set_id == set_id)
                .order_by(Comment.created_at.desc()).limit(20).all())
    d = _set_dict(s)
    d["comments"] = [
        {"id": c.id, "quizSetId": c.quiz_set_id, "userId": c.user_id,
         "userName": display_name or "Người chơi", "rating": c.rating,
         "comment": c.content,
         "createdAt": c.created_at.isoformat() if c.created_at else None}
        for c, display_name in comments
    ]
    return ok(d)

@router.post("/{set_id}/comments")
def add_comment(set_id: str, body: CommentIn,
                user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    if not 1 <= body.rating <= 5 or len(body.content) > 2000:
        raise ApiError(400, "VALIDATION", "Đánh giá cần từ 1 đến 5 sao và tối đa 2.000 ký tự.")
    s = db.query(QuizSet).filter(QuizSet.id == set_id).first()
    if not s:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy bộ đề.")
    c = Comment(quiz_set_id=set_id, user_id=user.uid, rating=body.rating, content=body.content)
    db.add(c)
    db.commit()
    db.refresh(c)
    u = db.query(User).filter(User.uid == user.uid).first()
    return ok({
        "id": c.id,
        "quizSetId": set_id,
        "userId": user.uid,
        "userName": (u.display_name if u and u.display_name else "Người chơi"),
        "rating": c.rating,
        "comment": c.content,
        "content": c.content,
        "createdAt": c.created_at.isoformat() if c.created_at else None,
    })
