import json
import os
import threading
from typing import Any
from urllib.parse import quote

import firebase_admin
from fastapi import Body, Depends, FastAPI, Header
from fastapi.responses import JSONResponse
from firebase_admin import auth, credentials, firestore


app = FastAPI(title="Triangle Store API")
_firebase_lock = threading.Lock()
_max_safe_integer = 9_007_199_254_740_991


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status = status
        self.code = code
        self.message = message


@app.exception_handler(ApiError)
async def handle_api_error(_, error: ApiError):
    return JSONResponse(
        status_code=error.status,
        content={
            "ok": False,
            "error": {"code": error.code, "message": error.message},
        },
    )


def _firebase_app():
    try:
        return firebase_admin.get_app()
    except ValueError:
        with _firebase_lock:
            try:
                return firebase_admin.get_app()
            except ValueError:
                service_account_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
                if service_account_json:
                    try:
                        service_account = json.loads(service_account_json)
                    except json.JSONDecodeError as error:
                        raise RuntimeError(
                            "FIREBASE_SERVICE_ACCOUNT_JSON must contain valid JSON."
                        ) from error
                    return firebase_admin.initialize_app(
                        credentials.Certificate(service_account)
                    )
                return firebase_admin.initialize_app()


def _db():
    return firestore.client(_firebase_app())


def _require_user(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "UNAUTHENTICATED", "Thiếu token đăng nhập.")
    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise ApiError(401, "UNAUTHENTICATED", "Thiếu token đăng nhập.")

    try:
        decoded = auth.verify_id_token(token, app=_firebase_app())
    except auth.InvalidIdTokenError as error:
        raise ApiError(
            401, "UNAUTHENTICATED", "Token không hợp lệ hoặc đã hết hạn."
        ) from error
    return decoded["uid"]


def _is_safe_integer(value: Any) -> bool:
    return (
        type(value) is int
        and 0 <= value <= _max_safe_integer
    )


def _quantity(data: dict[str, Any]) -> int:
    value = data.get("quantity")
    return value if type(value) is int and 0 < value <= _max_safe_integer else 1


def _has_owned_quantity(data: dict[str, Any]) -> bool:
    value = data.get("quantity")
    if type(value) is not int or abs(value) > _max_safe_integer:
        value = 1
    return value > 0


def _ok(data: Any) -> dict[str, Any]:
    return {"ok": True, "data": data}


@app.get("/health")
def health():
    return _ok({"status": "ok"})


@app.get("/store/items")
def load_items(uid: str = Depends(_require_user)):
    db = _db()
    items = list(
        db.collection("items").where("isActive", "==", True).stream()
    )
    user = db.collection("users").document(uid).get()
    if not user.exists:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy hồ sơ người dùng.")

    coins = user.to_dict().get("coins")
    if not _is_safe_integer(coins):
        raise ApiError(500, "INVALID_BALANCE", "Số dư xu trong hồ sơ chưa hợp lệ.")

    inventory = {}
    owned_items = db.collection("user_items").where("userId", "==", uid).stream()
    for owned in owned_items:
        data = owned.to_dict()
        item_id = data.get("itemId")
        if item_id:
            inventory[item_id] = inventory.get(item_id, 0) + _quantity(data)

    item_data = [{"id": item.id, **item.to_dict()} for item in items]
    type_order = {"help": 0, "frame": 1, "title": 2}
    item_data.sort(
        key=lambda item: (
            type_order.get(item.get("type"), 3),
            item.get("price") if _is_safe_integer(item.get("price")) else 0,
        )
    )
    return _ok({"coins": coins, "items": item_data, "inventory": inventory})


@app.post("/store/purchase")
def purchase_item(
    payload: Any = Body(default=None),
    uid: str = Depends(_require_user),
):
    item_id = payload.get("itemId") if isinstance(payload, dict) else None
    if not isinstance(item_id, str) or not item_id.strip():
        raise ApiError(400, "VALIDATION", "Thiếu itemId hợp lệ.")

    item_id = item_id.strip()
    db = _db()
    item_ref = db.collection("items").document(item_id)
    user_ref = db.collection("users").document(uid)
    inventory_query = db.collection("user_items").where("userId", "==", uid)
    fallback_item_ref = db.collection("user_items").document(
        f"{uid}_{quote(item_id, safe='')}"
    )
    transaction_ref = db.collection("transactions").document()

    @firestore.transactional
    def perform_purchase(transaction):
        item_snapshot = item_ref.get(transaction=transaction)
        user_snapshot = user_ref.get(transaction=transaction)
        inventory_snapshots = list(inventory_query.stream(transaction=transaction))
        matching = [
            snapshot
            for snapshot in inventory_snapshots
            if snapshot.to_dict().get("itemId") == item_id
        ]
        preferred = next(
            (snapshot for snapshot in matching if snapshot.id == fallback_item_ref.id),
            matching[0] if matching else None,
        )
        user_item_ref = preferred.reference if preferred else fallback_item_ref

        if not item_snapshot.exists or item_snapshot.to_dict().get("isActive") is not True:
            raise ApiError(
                404, "NOT_FOUND", "Vật phẩm không tồn tại hoặc đã ngừng bán."
            )
        if not user_snapshot.exists:
            raise ApiError(404, "NOT_FOUND", "Không tìm thấy hồ sơ người dùng.")

        item = item_snapshot.to_dict()
        price = item.get("price")
        if not _is_safe_integer(price):
            raise ApiError(
                500, "INVALID_ITEM", "Giá vật phẩm chưa được cấu hình hợp lệ."
            )
        if matching and item.get("type") != "help":
            raise ApiError(
                409, "ALREADY_OWNED", "Bạn đã sở hữu vật phẩm này."
            )

        user = user_snapshot.to_dict()
        coins = user.get("coins")
        if not _is_safe_integer(coins):
            raise ApiError(
                500, "INVALID_BALANCE", "Số dư xu trong hồ sơ chưa hợp lệ."
            )
        if coins < price:
            raise ApiError(
                409, "INSUFFICIENT_COINS", "Bạn không đủ xu để mua vật phẩm này."
            )

        quantity = sum(_quantity(snapshot.to_dict()) for snapshot in matching) + 1
        timestamp = firestore.SERVER_TIMESTAMP
        transaction.update(
            user_ref, {"coins": coins - price, "updatedAt": timestamp}
        )
        transaction.set(
            user_item_ref,
            {
                "userId": uid,
                "itemId": item_id,
                "quantity": quantity,
                "equipped": any(
                    snapshot.to_dict().get("equipped") is True
                    for snapshot in matching
                ),
                **({"createdAt": timestamp} if not matching else {}),
                "updatedAt": timestamp,
            },
            merge=True,
        )
        for snapshot in matching:
            if snapshot.reference.id != user_item_ref.id:
                transaction.delete(snapshot.reference)
        transaction.set(
            transaction_ref,
            {
                "userId": uid,
                "type": "purchase",
                "amount": price,
                "reason": "shop_purchase",
                "relatedId": item_id,
                "createdAt": timestamp,
            },
        )
        return {"coins": coins - price, "quantity": quantity}

    return _ok(perform_purchase(db.transaction()))


@app.post("/store/equip")
def equip_item(
    payload: Any = Body(default=None),
    uid: str = Depends(_require_user),
):
    item_id = payload.get("itemId") if isinstance(payload, dict) else None
    equipped = payload.get("equipped") if isinstance(payload, dict) else None
    if not isinstance(item_id, str) or not item_id.strip():
        raise ApiError(400, "VALIDATION", "Thiếu itemId hợp lệ.")
    if type(equipped) is not bool:
        raise ApiError(400, "VALIDATION", "Thiếu trạng thái trang bị hợp lệ.")

    item_id = item_id.strip()
    db = _db()
    item_ref = db.collection("items").document(item_id)
    user_ref = db.collection("users").document(uid)
    inventory_query = db.collection("user_items").where("userId", "==", uid)

    @firestore.transactional
    def perform_equip(transaction):
        item_snapshot = item_ref.get(transaction=transaction)
        user_snapshot = user_ref.get(transaction=transaction)
        inventory_snapshots = list(inventory_query.stream(transaction=transaction))

        if not item_snapshot.exists or item_snapshot.to_dict().get("isActive") is not True:
            raise ApiError(
                404, "NOT_FOUND", "Vật phẩm không tồn tại hoặc đã ngừng hoạt động."
            )
        if not user_snapshot.exists:
            raise ApiError(404, "NOT_FOUND", "Không tìm thấy hồ sơ người dùng.")

        item = item_snapshot.to_dict()
        item_type = item.get("type")
        if item_type not in ("frame", "title"):
            raise ApiError(
                400, "NOT_EQUIPPABLE", "Vật phẩm này không thể trang bị."
            )

        same_type_items = list(
            db.collection("items").where("type", "==", item_type).stream(
                transaction=transaction
            )
        )
        same_type_ids = {snapshot.id for snapshot in same_type_items}
        matching = [
            snapshot
            for snapshot in inventory_snapshots
            if snapshot.to_dict().get("itemId") == item_id
            and _has_owned_quantity(snapshot.to_dict())
        ]
        if not matching:
            raise ApiError(
                403, "NOT_OWNED", "Bạn chưa sở hữu vật phẩm này."
            )

        owned_same_type = [
            snapshot
            for snapshot in inventory_snapshots
            if snapshot.to_dict().get("itemId") in same_type_ids
        ]
        matching_ids = {snapshot.id for snapshot in matching}
        timestamp = firestore.SERVER_TIMESTAMP
        for snapshot in owned_same_type:
            transaction.update(
                snapshot.reference,
                {
                    "equipped": equipped and snapshot.id in matching_ids,
                    "updatedAt": timestamp,
                },
            )
        field = "frameId" if item_type == "frame" else "titleId"
        transaction.update(
            user_ref,
            {
                field: item_id if equipped else None,
                "updatedAt": timestamp,
            },
        )
        return {"itemId": item_id, "equipped": equipped}

    return _ok(perform_equip(db.transaction()))
