from fastapi import APIRouter, Body, Depends
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ok
from ..models import Favorite, QuizSet, Topic
from .quiz_sets import _set_dict

router = APIRouter()


@router.get("")
def list_favorites(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(QuizSet)
        .join(Favorite, Favorite.target_id == QuizSet.id)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_type == "quiz_set",
            QuizSet.is_active == True,
        )
        .order_by(Favorite.created_at.desc())
        .all()
    )
    return ok([_set_dict(s) for s in rows])


@router.get("/ids")
def list_favorite_ids(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Favorite.target_id)
        .filter(Favorite.user_id == user.uid, Favorite.target_type == "quiz_set")
        .all()
    )
    return ok([r[0] for r in rows])


@router.post("/{set_id}/toggle")
def toggle_favorite(
    set_id: str,
    payload: dict | None = Body(default=None),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    payload = payload or {}
    quiz_set = db.query(QuizSet).filter(QuizSet.id == set_id).first()

    # Tự động tạo bản ghi QuizSet vào DB nếu bộ đề chưa có sẵn trong bảng quiz_sets
    if not quiz_set:
        topic_id = str(payload.get("topicId") or "general")
        if not db.query(Topic).filter(Topic.id == topic_id).first():
            db.add(Topic(id=topic_id, name=str(payload.get("topicName") or "Tổng hợp")))
            db.flush()

        quiz_set = QuizSet(
            id=set_id,
            topic_id=topic_id,
            name=str(payload.get("title") or f"Bộ đề {set_id}"),
            duration_sec=int(payload.get("durationSec") or 300),
            question_count=int(payload.get("questionCount") or 10),
            is_active=True,
        )
        db.add(quiz_set)
        db.flush()

    existing = (
        db.query(Favorite)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_id == set_id,
            Favorite.target_type == "quiz_set",
        )
        .first()
    )
    if existing:
        db.delete(existing)
        db.commit()
        return ok({"quizSetId": set_id, "isFavorite": False})

    fav = Favorite(user_id=user.uid, target_id=set_id, target_type="quiz_set")
    db.add(fav)
    db.commit()
    return ok({"quizSetId": set_id, "isFavorite": True})