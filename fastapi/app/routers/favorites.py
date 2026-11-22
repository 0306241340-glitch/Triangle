from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Favorite, QuizSet, Topic
from ..schemas import FavoriteIn

router = APIRouter()


def _validate_target(body: FavoriteIn, db: Session) -> None:
    if body.targetType == "topic":
        exists = db.query(Topic.id).filter(Topic.id == body.targetId).first()
    elif body.targetType == "quizSet":
        exists = db.query(QuizSet.id).filter(QuizSet.id == body.targetId).first()
    else:
        raise ApiError(400, "VALIDATION", "Loại mục yêu thích không hợp lệ.")
    if exists is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy mục cần lưu.")


@router.get("/status")
def status(targetId: str = Query(min_length=1),
           targetType: str = Query(min_length=1),
           user: CurrentUser = Depends(get_current_user),
           db: Session = Depends(get_db)):
    favorite = db.query(Favorite.id).filter(
        Favorite.user_id == user.uid,
        Favorite.target_id == targetId,
        Favorite.target_type == targetType,
    ).first()
    return ok({"isFavorite": favorite is not None})


@router.get("")
def list_favorites(user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    rows = db.query(Favorite).filter(Favorite.user_id == user.uid).all()
    return ok([
        {"id": row.id, "targetId": row.target_id, "targetType": row.target_type}
        for row in rows
    ])


@router.post("")
def add_favorite(body: FavoriteIn, user: CurrentUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    _validate_target(body, db)
    existing = db.query(Favorite).filter(
        Favorite.user_id == user.uid,
        Favorite.target_id == body.targetId,
        Favorite.target_type == body.targetType,
    ).first()
    if existing is None:
        db.add(Favorite(
            user_id=user.uid,
            target_id=body.targetId,
            target_type=body.targetType,
        ))
        db.commit()
    return ok({"isFavorite": True})


@router.delete("")
def remove_favorite(targetId: str = Query(min_length=1),
                    targetType: str = Query(min_length=1),
                    user: CurrentUser = Depends(get_current_user),
                    db: Session = Depends(get_db)):
    db.query(Favorite).filter(
        Favorite.user_id == user.uid,
        Favorite.target_id == targetId,
        Favorite.target_type == targetType,
    ).delete(synchronize_session=False)
    db.commit()
    return ok({"isFavorite": False})
