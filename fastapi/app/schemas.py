from typing import List, Optional
from pydantic import BaseModel, Field

class StartIn(BaseModel):
    quizSetId: str

class AnswerIn(BaseModel):
    questionId: str
    selectedIndex: int = -1

class SubmitIn(BaseModel):
    attemptId: str
    quizSetId: str
    answers: List[AnswerIn]
    timeTakenSec: int = 0

class FiftyFiftyIn(BaseModel):
    attemptId: str
    questionId: str
    selectedIndex: Optional[int] = None

class HelpIn(BaseModel):
    attemptId: str
    questionId: str = ""
    answerId: str = ""
    helpType: str
    selectedIndex: Optional[int] = None

class CommentIn(BaseModel):
    rating: int = 5
    content: str = ""

class ProfileUpdateIn(BaseModel):
    displayName: str
    avatarUrl: str = ""

class PurchaseIn(BaseModel):
    itemId: str

class EquipIn(BaseModel):
    itemId: str
    equipped: bool

class PvpAnswerIn(BaseModel):
    questionIndex: int = Field(ge=0)
    selectedIndex: int = Field(ge=0, le=7)

class FavoriteIn(BaseModel):
    targetId: str
    targetType: str


class AdminTopicIn(BaseModel):
    id: Optional[str] = None
    name: str
    description: str = ""
    icon: str = ""
    imageUrl: str = ""
    isActive: bool = True


class AdminQuestionIn(BaseModel):
    topicId: str
    content: str
    options: List[str]
    correctIndex: int
    level: str = "easy"
    explanation: str = ""
    isActive: bool = True


class AdminQuizSetIn(BaseModel):
    id: Optional[str] = None
    topicId: str
    title: str
    description: str = ""
    level: str = "mixed"
    durationSec: int = 300
    questionCount: int = 10
    isActive: bool = True
    selectionMode: str = "random"
    questionIds: List[str] = Field(default_factory=list)


class AdminItemIn(BaseModel):
    id: Optional[str] = None
    name: str
    type: str
    lifelineCode: str = ""
    price: int = 0
    description: str = ""
    isActive: bool = True


class AdminUserStatusIn(BaseModel):
    status: str


class AdminReportStatusIn(BaseModel):
    status: str
