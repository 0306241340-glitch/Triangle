"""FastAPI — App Do Vui Trac Nghiem. Giong het hop dong cua ban Express:
- Cung duong dan: /topics, /quiz-sets, /quiz/start, /quiz/submit, /quiz/fifty-fifty,
  /leaderboard, /admin/stats, /quiz/history, POST /quiz-sets/{id}/comments
- Cung envelope {ok, data} / {ok:false, error:{code,message}} de Flutter khong doi code.
- Cung Bearer Firebase ID token.
- KEM CORS allow-all (ban Express khong co CORS — day la 1 trong cac loi sang nay)."""
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, Request
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
import traceback

from firebase_admin.exceptions import FirebaseError
from .auth import get_current_user
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from datetime import datetime
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError

from .database import Base, engine, get_db
from .errors import ApiError, fail_body, ok
from .models import Item, QuizHistory, User, UserItem
from .routers import admin, favorites, friends, leaderboard, pvp, quiz, quiz_sets, store, topics
from .seed import seed_frames
from .schemas import ProfileUpdateIn

logger = logging.getLogger(__name__)


async def _cleanup_old_pvp_rooms():
    while True:
        try:
            await asyncio.to_thread(pvp.cleanup_expired_rooms)
        except (
            SQLAlchemyError,
            FirebaseError,
            GoogleAPICallError,
            DefaultCredentialsError,
        ):
            logger.exception("Không thể dọn phòng PvP đã hết hạn.")
        await asyncio.sleep(30)


@asynccontextmanager
async def lifespan(_app):
    cleanup_task = asyncio.create_task(_cleanup_old_pvp_rooms())
    try:
        yield
    finally:
        cleanup_task.cancel()
        try:
            await cleanup_task
        except asyncio.CancelledError:
            pass


app = FastAPI(
    title="Quiz App API (FastAPI + SQL)",
    version="2.0.0",
    lifespan=lifespan,
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
                   allow_headers=["*"], allow_credentials=False)

Base.metadata.create_all(bind=engine)
seed_frames()

@app.exception_handler(ApiError)
async def api_error_handler(request: Request, exc: ApiError):
    return JSONResponse(status_code=exc.status, content=fail_body(exc.code, exc.message))

@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    traceback.print_exc()
    return JSONResponse(status_code=500, content=fail_body("INTERNAL", str(exc)),
                        headers={"Access-Control-Allow-Origin": "*"})


@app.get("/health")
def health():
    return ok({"status": "ok"})

@app.get("/me")
def me(user=Depends(get_current_user), db: Session = Depends(get_db)):
    u = db.query(User).filter(User.uid == user.uid).first()
    equipped = db.query(Item.id, Item.type, Item.name).join(
        UserItem, UserItem.item_id == Item.id
    ).filter(UserItem.user_id == user.uid, UserItem.equipped.is_(True)).all()
    return ok({
        "uid": u.uid,
        "email": u.email,
        "displayName": u.display_name,
        "avatarUrl": u.avatar_url or "",
        "userCode": u.user_code,
        "role": u.role,
        "status": u.status,
        "score": u.score or 0,
        "coins": u.coins or 0,
        "weeklyScore": u.weekly_score or 0,
        "monthlyScore": u.monthly_score or 0,
        "gamesPlayed": db.query(QuizHistory).filter(
            QuizHistory.user_id == user.uid).count(),
        "createdAt": u.created_at.isoformat() if u.created_at else None,
        "updatedAt": u.updated_at.isoformat() if u.updated_at else None,
        "equippedItems": [
            {"itemId": item_id, "type": item_type, "name": item_name}
            for item_id, item_type, item_name in equipped
        ],
    })


@app.put("/me/profile")
def update_profile(body: ProfileUpdateIn, user=Depends(get_current_user),
                   db: Session = Depends(get_db)):
    display_name = body.displayName.strip()
    if len(display_name) < 2:
        raise ApiError(400, "VALIDATION", "Tên hiển thị phải có ít nhất 2 ký tự.")
    if len(body.avatarUrl) > 500_000:
        raise ApiError(400, "VALIDATION", "Ảnh đại diện vượt quá dung lượng cho phép.")

    account = db.query(User).filter(User.uid == user.uid).first()
    account.display_name = display_name
    account.avatar_url = body.avatarUrl
    account.updated_at = datetime.utcnow()
    db.commit()
    return ok({"displayName": account.display_name, "avatarUrl": account.avatar_url or ""})

app.include_router(topics.router, prefix="/topics")
app.include_router(quiz_sets.router, prefix="/quiz-sets")
app.include_router(quiz.router, prefix="/quiz")
app.include_router(leaderboard.router, prefix="/leaderboard")
app.include_router(admin.router, prefix="/admin")
app.include_router(friends.router, prefix="/friends")
app.include_router(store.router, prefix="/store")
app.include_router(favorites.router, prefix="/favorites")
app.include_router(pvp.router, prefix="/pvp")
