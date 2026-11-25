from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ApiError, ok
from ..models import Item, Transaction, User, UserItem
from ..schemas import EquipIn, PurchaseIn

router = APIRouter()


def _item(item: Item) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "description": item.description or "",
        "effect": item.effect or "",
        "price": item.price or 0,
        "type": item.type or "help",
        "imageUrl": "",
    }


def _catalog(db: Session, user_id: str) -> dict:
    account = db.query(User).filter(User.uid == user_id).first()
    items = db.query(Item).filter(Item.is_active.is_(True)).order_by(Item.name).all()
    inventory = {}
    for row in db.query(UserItem).filter(
        UserItem.user_id == user_id, UserItem.quantity > 0
    ).all():
        inventory[row.item_id] = inventory.get(row.item_id, 0) + row.quantity
    return {
        "coins": account.coins or 0,
        "items": [_item(item) for item in items],
        "inventory": inventory,
    }


@router.get("/items")
def list_items(user: CurrentUser = Depends(get_current_user),
               db: Session = Depends(get_db)):
    return ok(_catalog(db, user.uid))


@router.get("/inventory")
def inventory(user: CurrentUser = Depends(get_current_user),
              db: Session = Depends(get_db)):
    catalog = _catalog(db, user.uid)
    rows = db.query(UserItem).filter(
        UserItem.user_id == user.uid, UserItem.quantity > 0
    ).all()
    catalog["userItems"] = [
        {
            "id": row.id,
            "userId": row.user_id,
            "itemId": row.item_id,
            "quantity": row.quantity or 0,
            "equipped": bool(row.equipped),
        }
        for row in rows
    ]
    return ok(catalog)


@router.post("/purchase")
def purchase(body: PurchaseIn, user: CurrentUser = Depends(get_current_user),
             db: Session = Depends(get_db)):
    account = db.query(User).filter(User.uid == user.uid).with_for_update().first()
    item = db.query(Item).filter(
        Item.id == body.itemId, Item.is_active.is_(True)
    ).first()
    if item is None:
        raise ApiError(404, "NOT_FOUND", "Không tìm thấy vật phẩm.")

    price = max(item.price or 0, 0)
    if (account.coins or 0) < price:
        raise ApiError(400, "INSUFFICIENT_COINS", "Bạn không đủ xu để mua vật phẩm này.")

    owned = db.query(UserItem).filter(
        UserItem.user_id == user.uid, UserItem.item_id == item.id
    ).first()
    stackable = item.type in ("help", "lifeline")
    if owned is not None and not stackable:
        raise ApiError(409, "CONFLICT", "Bạn đã sở hữu vật phẩm này.")

    account.coins = (account.coins or 0) - price
    if owned is None:
        owned = UserItem(user_id=user.uid, item_id=item.id, quantity=1, equipped=False)
        db.add(owned)
        quantity = 1
    else:
        owned.quantity = (owned.quantity or 0) + 1
        quantity = owned.quantity
    db.add(Transaction(
        user_id=user.uid,
        type="spend",
        amount=-price,
        reason="store_purchase",
        related_id=item.id,
    ))
    db.commit()
    return ok({"coins": account.coins, "quantity": quantity})


@router.post("/equip")
def equip(body: EquipIn, user: CurrentUser = Depends(get_current_user),
          db: Session = Depends(get_db)):
    owned = db.query(UserItem).filter(
        UserItem.user_id == user.uid,
        UserItem.item_id == body.itemId,
        UserItem.quantity > 0,
    ).first()
    if owned is None:
        raise ApiError(404, "NOT_FOUND", "Bạn chưa sở hữu vật phẩm này.")
    item = db.query(Item).filter(Item.id == body.itemId).first()
    if item is None or item.type not in ("frame", "title"):
        raise ApiError(400, "VALIDATION", "Vật phẩm này không thể trang bị.")

    if body.equipped:
        db.query(UserItem).filter(
            UserItem.user_id == user.uid,
            UserItem.equipped.is_(True),
            UserItem.item_id.in_(
                db.query(Item.id).filter(Item.type == item.type)
            ),
        ).update({UserItem.equipped: False}, synchronize_session=False)
    owned.equipped = body.equipped
    db.commit()
    return ok({"itemId": item.id, "equipped": owned.equipped})
