"""Publish safe PvP projections to Firestore for realtime client listeners."""

from datetime import datetime, timezone
from functools import lru_cache

from firebase_admin import firestore

from .auth import _init_firebase


@lru_cache(maxsize=1)
def _firestore_db():
    return firestore.client(app=_init_firebase())


def publish_queue_state(
    uid: str,
    status: str,
    *,
    queue_id: str | None = None,
    room_id: str | None = None,
) -> None:
    _firestore_db().collection("users").document(uid).collection(
        "pvp_state"
    ).document("current").set({
        "status": status,
        "queueId": queue_id,
        "roomId": room_id,
        "updatedAt": datetime.now(timezone.utc),
    })


def publish_room(room_id: str, payload: dict, invitation: dict | None = None) -> None:
    db = _firestore_db()
    db.collection("rooms").document(room_id).set(payload)

    active = payload["status"] in ("waiting", "playing")
    for uid in (payload["hostId"], payload.get("guestId")):
        if uid is not None:
            publish_queue_state(
                uid,
                "in_room" if active else "idle",
                room_id=room_id if active else None,
            )

    if invitation is None:
        return

    recipient_id = invitation["guestId"]
    invitation_ref = (
        db.collection("users")
        .document(recipient_id)
        .collection("pvp_invitations")
        .document(room_id)
    )
    if payload["status"] == "waiting":
        invitation_ref.set(invitation)
    else:
        invitation_ref.delete()
