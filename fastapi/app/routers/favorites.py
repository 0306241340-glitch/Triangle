from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Favorite, QuizSet, Topic
from ..schemas import FavoriteIn

router = APIRouter()


def _normalize_target_type(target_type: str) -> str:
    if target_type == "topic":
        return "topic"
    if target_type in {"quizSet", "quiz_set"}:
        return "quizSet"
    raise ApiError(400, "VALIDATION", "Loại mục yêu thích không hợp lệ.")


def _target_type_aliases(target_type: str) -> tuple[str, ...]:
    normalized = _normalize_target_type(target_type)
    return ("quizSet", "quiz_set") if normalized == "quizSet" else ("topic",)


def _validate_target(body: FavoriteIn, db: Session) -> str:
    target_type = _normalize_target_type(body.targetType)
    if target_type == "topic":
        exists = db.query(Topic.id).filter(Topic.id == body.targetId).first()
    else:
        exists = db.query(QuizSet.id).filter(QuizSet.id == body.targetId).first()
    if exists is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy mục cần lưu.")
    return target_type


@router.get("")
def list_favorites(
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Favorite)
        .filter(Favorite.user_id == user.uid)
        .order_by(Favorite.created_at.desc())
        .all()
    )
    return ok([
        {
            "id": row.id,
            "targetId": row.target_id,
            "targetType": _normalize_target_type(row.target_type),
            "createdAt": row.created_at.isoformat() if row.created_at else None,
        }
        for row in rows
    ])


@router.get("/ids")
def list_favorite_ids(
    targetType: str = Query(default="quizSet"),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    aliases = _target_type_aliases(targetType)
    rows = (
        db.query(Favorite.target_id)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_type.in_(aliases),
        )
        .all()
    )
    return ok([row[0] for row in rows])


@router.get("/status")
def status(
    targetId: str = Query(min_length=1),
    targetType: str = Query(min_length=1),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    aliases = _target_type_aliases(targetType)
    favorite = (
        db.query(Favorite.id)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_id == targetId,
            Favorite.target_type.in_(aliases),
        )
        .first()
    )
    return ok({"isFavorite": favorite is not None})


@router.post("")
def add_favorite(
    body: FavoriteIn,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    target_type = _validate_target(body, db)
    existing = (
        db.query(Favorite)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_id == body.targetId,
            Favorite.target_type.in_(_target_type_aliases(target_type)),
        )
        .first()
    )
    if existing is None:
        db.add(
            Favorite(
                user_id=user.uid,
                target_id=body.targetId,
                target_type=target_type,
            )
        )
        db.commit()
    return ok({"isFavorite": True})


@router.delete("")
def remove_favorite(
    targetId: str = Query(min_length=1),
    targetType: str = Query(min_length=1),
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    aliases = _target_type_aliases(targetType)
    (
        db.query(Favorite)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_id == targetId,
            Favorite.target_type.in_(aliases),
        )
        .delete(synchronize_session=False)
    )
    db.commit()
    return ok({"isFavorite": False})


@router.post("/{set_id}/toggle")
def toggle_favorite(
    set_id: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    body = FavoriteIn(targetId=set_id, targetType="quizSet")
    _validate_target(body, db)
    existing = (
        db.query(Favorite)
        .filter(
            Favorite.user_id == user.uid,
            Favorite.target_id == set_id,
            Favorite.target_type.in_(_target_type_aliases("quizSet")),
        )
        .first()
    )
    if existing is not None:
        db.delete(existing)
        db.commit()
        return ok({"quizSetId": set_id, "isFavorite": False})

    db.add(Favorite(user_id=user.uid, target_id=set_id, target_type="quizSet"))
    db.commit()
    return ok({"quizSetId": set_id, "isFavorite": True})
