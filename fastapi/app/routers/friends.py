from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Friend, User

router = APIRouter()


def _profile(user: User) -> dict:
    return {
        "uid": user.uid,
        "userCode": user.user_code or "",
        "displayName": user.display_name or "Người chơi",
        "avatarUrl": user.avatar_url or "",
    }


def _request(friendship: Friend) -> dict:
    return {
        "id": str(friendship.id),
        "userId": friendship.user_id,
        "friendId": friendship.friend_id,
        "status": friendship.status or "pending",
    }


@router.get("/search")
def search_users(q: str = Query(min_length=2, max_length=64),
                 user: CurrentUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    query = q.strip()
    if len(query) < 2:
        raise ApiError(400, "VALIDATION", "Nhập ít nhất 2 ký tự để tìm bạn bè.")

    users = db.query(User).filter(User.uid != user.uid)
    if query.isalnum() and len(query) == 6:
        matches = users.filter(User.user_code == query.upper()).limit(1).all()
    else:
        matches = users.filter(User.display_name.ilike(f"%{query}%")).limit(20).all()
        if not matches:
            matches = users.filter(User.user_code == query.upper()).limit(1).all()
    return ok([_profile(account) for account in matches])


@router.get("/profile/{uid}")
def get_profile(uid: str, user: CurrentUser = Depends(get_current_user),
                db: Session = Depends(get_db)):
    account = db.query(User).filter(User.uid == uid).first()
    if account is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy tài khoản này.")
    return ok(_profile(account))


@router.get("")
def list_friends(user: CurrentUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    rows = db.query(Friend).filter(
        Friend.status == "accepted",
        or_(Friend.user_id == user.uid, Friend.friend_id == user.uid),
    ).all()
    return ok([_request(row) for row in rows])


@router.get("/requests")
def list_requests(direction: str = Query(pattern="^(incoming|outgoing)$"),
                  user: CurrentUser = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    owner_column = Friend.friend_id if direction == "incoming" else Friend.user_id
    rows = db.query(Friend).filter(
        owner_column == user.uid, Friend.status == "pending"
    ).all()
    return ok([_request(row) for row in rows])


@router.post("/{recipient_uid}")
def send_request(recipient_uid: str, user: CurrentUser = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    if recipient_uid == user.uid:
        raise ApiError(400, "VALIDATION", "Bạn không thể tự kết bạn với chính mình.")
    recipient = db.query(User).filter(User.uid == recipient_uid).first()
    if recipient is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy tài khoản này.")

    existing = db.query(Friend).filter(
        or_(
            (Friend.user_id == user.uid) & (Friend.friend_id == recipient_uid),
            (Friend.user_id == recipient_uid) & (Friend.friend_id == user.uid),
        )
    ).first()
    if existing is not None:
        if existing.status == "accepted":
            raise ApiError(409, "CONFLICT", "Hai bạn đã là bạn bè.")
        if existing.user_id == recipient_uid:
            raise ApiError(409, "CONFLICT", "Người này đã gửi lời mời kết bạn cho bạn.")
        raise ApiError(409, "CONFLICT", "Bạn đã gửi lời mời cho người này rồi.")

    friendship = Friend(user_id=user.uid, friend_id=recipient_uid, status="pending")
    db.add(friendship)
    db.commit()
    db.refresh(friendship)
    return ok(_request(friendship))


@router.post("/{request_id}/accept")
def accept_request(request_id: int, user: CurrentUser = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    friendship = db.query(Friend).filter(Friend.id == request_id).first()
    if friendship is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy lời mời kết bạn.")
    if friendship.friend_id != user.uid or friendship.status != "pending":
        raise ApiError(403, "FORBIDDEN", "Bạn không thể chấp nhận lời mời này.")
    friendship.status = "accepted"
    db.commit()
    return ok(_request(friendship))


@router.delete("/{request_id}")
def delete_friendship(request_id: int, user: CurrentUser = Depends(get_current_user),
                      db: Session = Depends(get_db)):
    friendship = db.query(Friend).filter(Friend.id == request_id).first()
    if friendship is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy quan hệ bạn bè.")
    if user.uid not in (friendship.user_id, friendship.friend_id):
        raise ApiError(403, "FORBIDDEN", "Bạn không có quyền xóa quan hệ này.")
    db.delete(friendship)
    db.commit()
    return ok({"deleted": True})
