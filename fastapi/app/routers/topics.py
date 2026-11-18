from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..auth import CurrentUser, get_current_user
from ..database import get_db
from ..errors import ok
from ..models import Topic

router = APIRouter()

@router.get("")
def list_topics(user: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(Topic).filter(Topic.is_active == True).all()
    return ok([{"id": t.id, "name": t.name, "description": t.description,
                "icon": t.icon, "imageUrl": t.image_url, "isActive": t.is_active,
                "questionCount": t.question_count} for t in rows])
