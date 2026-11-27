from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ok
from ..models import Friend, QuizHistory, User

router = APIRouter()
FIELDS = {"all": "score", "week": "weekly_score", "month": "monthly_score"}


def _display_name(u: User) -> str:
    name = (u.display_name or "").strip()
    if name:
        return name
    email = (u.email or "").strip()
    if "@" in email:
        return email.split("@", 1)[0]
    return email or "Người chơi"


def _period_cutoff(scope: str) -> datetime | None:
    now = datetime.utcnow()
    if scope == "week":
        return now - timedelta(days=7)
    if scope == "month":
        return now - timedelta(days=30)
    return None


def _friend_ids(db: Session, uid: str) -> set[str]:
    relationships = db.query(Friend).filter(
        Friend.status == "accepted",
        or_(Friend.user_id == uid, Friend.friend_id == uid),
    ).all()
    ids = {uid}
    for relation in relationships:
        ids.add(
            relation.friend_id
            if relation.user_id == uid
            else relation.user_id
        )
    return ids


@router.get("")
def leaderboard(scope: str = Query(default="all"), topicId: str = Query(default=""),
                limit: int = Query(default=20),
                user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    if scope not in ("all", "week", "month", "friends"):
        scope = "all"
    limit = min(limit, 50)
    cutoff = _period_cutoff(scope)

    history_query = db.query(QuizHistory)
    if topicId:
        history_query = history_query.filter(QuizHistory.topic_id == topicId)
    if cutoff is not None:
        history_query = history_query.filter(QuizHistory.created_at >= cutoff)
    history_rows = history_query.all()

    totals: dict[str, dict[str, int]] = {}
    for h in history_rows:
        t = totals.setdefault(h.user_id, {"score": 0, "plays": 0})
        t["score"] += h.score or 0
        t["plays"] += 1

    friend_id_set = _friend_ids(db, user.uid) if scope == "friends" else None

    if topicId:
        if friend_id_set is not None:
            totals = {uid: total for uid, total in totals.items() if uid in friend_id_set}
        users = {u.uid: u for u in db.query(User).all()}
        all_entries = sorted(
            [
                {
                    "uid": uid,
                    "displayName": _display_name(users[uid]),
                    "avatarUrl": users[uid].avatar_url or "",
                    "score": t["score"],
                    "plays": t["plays"],
                }
                for uid, t in totals.items()
                if uid in users and users[uid].status != "locked"
            ],
            key=lambda e: -e["score"],
        )
        all_ranked = [{"rank": i + 1, **e} for i, e in enumerate(all_entries)]
        me = next((e for e in all_ranked if e["uid"] == user.uid), None)
        return ok({
            "scope": scope,
            "topicId": topicId,
            "entries": all_ranked[:limit],
            "myRank": me["rank"] if me else None,
            "myScore": me["score"] if me else 0,
        })

    users = [u for u in db.query(User).all() if u.status != "locked"]
    if friend_id_set is not None:
        users = [u for u in users if u.uid in friend_id_set]

    field = "score" if scope == "friends" else FIELDS[scope]

    def _user_score(u: User) -> int:
        if scope in ("week", "month") and u.uid in totals:
            return totals[u.uid]["score"]
        if scope == "month":
            return u.monthly_score or u.weekly_score or u.score or 0
        return getattr(u, field) or 0

    users.sort(key=lambda u: (-_user_score(u), str(u.updated_at or "")))
    my_idx = next((i for i, u in enumerate(users) if u.uid == user.uid), -1)
    entries = [
        {
            "rank": i + 1,
            "uid": u.uid,
            "displayName": _display_name(u),
            "avatarUrl": u.avatar_url or "",
            "score": _user_score(u),
            "plays": totals.get(u.uid, {}).get("plays", 0),
        }
        for i, u in enumerate(users[:limit])
    ]
    return ok({
        "scope": scope,
        "entries": entries,
        "myRank": my_idx + 1 if my_idx >= 0 else None,
        "myScore": _user_score(users[my_idx]) if my_idx >= 0 else 0,
    })
