from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ok
from ..models import Friend, QuizHistory, User

router = APIRouter()
FIELDS = {"all": "score", "week": "weekly_score", "month": "monthly_score"}

@router.get("")
def leaderboard(scope: str = Query(default="all"), topicId: str = Query(default=""),
                limit: int = Query(default=20),
                user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    if scope not in ("all", "week", "month", "friends"):
        scope = "all"
    limit = min(limit, 50)
    if topicId:
        rows = db.query(QuizHistory).filter(QuizHistory.topic_id == topicId).all()
        totals = {}
        for h in rows:
            t = totals.setdefault(h.user_id, {"score": 0, "plays": 0})
            t["score"] += h.score or 0
            t["plays"] += 1
        users = {u.uid: u for u in db.query(User).all()}
        entries = sorted(
            [{"uid": uid, "displayName": users[uid].display_name or "",
              "avatarUrl": users[uid].avatar_url or "", "score": t["score"], "plays": t["plays"]}
             for uid, t in totals.items() if uid in users and users[uid].status != "locked"],
            key=lambda e: -e["score"])[:limit]
        entries = [{"rank": i + 1, **e} for i, e in enumerate(entries)]
        me = next((e for e in entries if e["uid"] == user.uid), None)
        return ok({"scope": scope, "topicId": topicId, "entries": entries,
                   "myRank": me["rank"] if me else None, "myScore": me["score"] if me else 0})
    users = [u for u in db.query(User).all() if u.status != "locked"]
    if scope == "friends":
        ids = {user.uid} | {f.friend_id for f in
                            db.query(Friend).filter(Friend.user_id == user.uid,
                                                   Friend.status == "accepted").all()}
        users = [u for u in users if u.uid in ids]
    field = "score" if scope == "friends" else FIELDS[scope]
    users.sort(key=lambda u: (-(getattr(u, field) or 0), str(u.updated_at or "")))
    my_idx = next((i for i, u in enumerate(users) if u.uid == user.uid), -1)
    entries = [{"rank": i + 1, "uid": u.uid, "displayName": u.display_name or "",
                "avatarUrl": u.avatar_url or "", "score": getattr(u, field) or 0}
               for i, u in enumerate(users[:limit])]
    return ok({"scope": scope, "entries": entries,
               "myRank": my_idx + 1 if my_idx >= 0 else None,
               "myScore": getattr(users[my_idx], field) or 0 if my_idx >= 0 else 0})
