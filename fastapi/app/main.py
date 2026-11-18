"""FastAPI — App Do Vui Trac Nghiem. Giong het hop dong cua ban Express:
- Cung duong dan: /topics, /quiz-sets, /quiz/start, /quiz/submit, /quiz/fifty-fifty,
  /leaderboard, /admin/stats, /quiz/history, POST /quiz-sets/{id}/comments
- Cung envelope {ok, data} / {ok:false, error:{code,message}} de Flutter khong doi code.
- Cung Bearer Firebase ID token.
- KEM CORS allow-all (ban Express khong co CORS — day la 1 trong cac loi sang nay)."""
from fastapi import Depends, FastAPI, Request

from .auth import get_current_user
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .database import Base, engine
from .errors import ApiError, fail_body, ok
from .routers import admin, leaderboard, quiz, quiz_sets, topics

app = FastAPI(title="Quiz App API (FastAPI + SQL)", version="2.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
                   allow_headers=["*"], allow_credentials=False)

Base.metadata.create_all(bind=engine)

@app.exception_handler(ApiError)
async def api_error_handler(request: Request, exc: ApiError):
    return JSONResponse(status_code=exc.status, content=fail_body(exc.code, exc.message))

@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    return JSONResponse(status_code=500, content=fail_body("INTERNAL", str(exc)))

@app.get("/health")
def health():
    return ok({"status": "ok"})

@app.get("/me")
def me(user=Depends(get_current_user)):
    from .database import SessionLocal
    from .models import User as U
    db = SessionLocal()
    u = db.query(U).filter(U.uid == user.uid).first()
    db.close()
    return ok({"uid": u.uid, "email": u.email, "displayName": u.display_name,
               "role": u.role, "score": u.score, "coins": u.coins,
               "weeklyScore": u.weekly_score, "monthlyScore": u.monthly_score})

app.include_router(topics.router, prefix="/topics")
app.include_router(quiz_sets.router, prefix="/quiz-sets")
app.include_router(quiz.router, prefix="/quiz")
app.include_router(leaderboard.router, prefix="/leaderboard")
app.include_router(admin.router, prefix="/admin")
