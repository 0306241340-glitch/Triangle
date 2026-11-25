from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from .auth import CurrentUser, get_current_user
from .database import Base, engine, get_db
from .errors import ApiError, fail_body, ok
from .models import Item, User, UserItem
from .routers import friends, pvp, store

app = FastAPI(title="Triangle Vương API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)

Base.metadata.create_all(bind=engine)


@app.exception_handler(ApiError)
async def api_error_handler(request: Request, error: ApiError):
    return JSONResponse(
        status_code=error.status,
        content=fail_body(error.code, error.message),
    )


@app.get("/health")
def health():
    return ok({"status": "ok"})


@app.get("/me")
def me(user: CurrentUser = Depends(get_current_user),
       db: Session = Depends(get_db)):
    account = db.query(User).filter(User.uid == user.uid).first()
    equipped = db.query(Item.id, Item.type, Item.name).join(
        UserItem, UserItem.item_id == Item.id
    ).filter(
        UserItem.user_id == user.uid,
        UserItem.equipped.is_(True),
    ).all()
    return ok({
        "uid": account.uid,
        "email": account.email or "",
        "displayName": account.display_name or "",
        "avatarUrl": account.avatar_url or "",
        "userCode": account.user_code or "",
        "role": account.role or "user",
        "score": account.score or 0,
        "coins": account.coins or 0,
        "equippedItems": [
            {"itemId": item_id, "type": item_type, "name": item_name}
            for item_id, item_type, item_name in equipped
        ],
    })


app.include_router(friends.router, prefix="/friends")
app.include_router(store.router, prefix="/store")
app.include_router(pvp.router, prefix="/pvp")
