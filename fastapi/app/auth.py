"""Xac thuc: giu nguyen Firebase Auth nhu ban Express.
App Flutter dang nhap nhu cu, lay ID token, gui header Bearer — khong doi gi.
FastAPI chi verify token bang firebase-admin, roi lay role tu bang users."""
import json
import os
import secrets
from dataclasses import dataclass

from fastapi import Depends, Header
from sqlalchemy.orm import Session

from .database import get_db
from .errors import ApiError
from .models import User

_firebase_app = None
_USER_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _new_user_code(db: Session) -> str:
    for _ in range(100):
        code = "".join(secrets.choice(_USER_CODE_CHARS) for _ in range(6))
        if not db.query(User).filter(User.user_code == code).first():
            return code
    raise RuntimeError("Không thể tạo mã người dùng duy nhất.")

def _init_firebase():
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app
    import firebase_admin
    from firebase_admin import credentials
    raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "")
    if raw.strip():
        cred = credentials.Certificate(json.loads(raw))
        _firebase_app = firebase_admin.initialize_app(cred)
    elif os.path.exists("serviceAccountKey.json"):
        cred = credentials.Certificate("serviceAccountKey.json")
        _firebase_app = firebase_admin.initialize_app(cred)
    else:
        _firebase_app = firebase_admin.initialize_app()  # ADC (neu co)
    return _firebase_app

@dataclass
class CurrentUser:
    uid: str
    role: str = "user"
    email: str = ""

def get_current_user(authorization: str = Header(default=""),
                     db: Session = Depends(get_db)) -> CurrentUser:
    token = authorization[7:] if authorization.startswith("Bearer ") else ""
    if not token:
        raise ApiError(401, "UNAUTHENTICATED", "Thiếu token đăng nhập.")
    try:
        from firebase_admin import auth as fb_auth
        _init_firebase()
        decoded = fb_auth.verify_id_token(token)
    except Exception:
        raise ApiError(401, "UNAUTHENTICATED", "Token không hợp lệ hoặc đã hết hạn.")
    uid = decoded["uid"]
    user = db.query(User).filter(User.uid == uid).first()
    if user is None:  # dang nhap lan dau: tao ho so nhu seed (0 diem, 100 xu)
        user = User(uid=uid, email=decoded.get("email", ""),
                    display_name=decoded.get("name", ""), coins=100,
                    user_code=_new_user_code(db))
        db.add(user)
        db.commit()
    elif not user.user_code:
        user.user_code = _new_user_code(db)
        db.commit()
    return CurrentUser(uid=uid, role=user.role, email=user.email)

def require_admin(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    if user.role != "admin":
        raise ApiError(403, "FORBIDDEN", "Chỉ quản trị viên mới dùng được chức năng này.")
    return user
