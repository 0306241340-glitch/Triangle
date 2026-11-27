from typing import List, Literal, Optional
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


class ReportIn(BaseModel):
    attemptId: str = Field(min_length=1, max_length=128)
    questionId: str = Field(min_length=1, max_length=128)
    issueType: Literal["question", "answer"]
    answerText: str = Field(default="", max_length=1000)
    description: str = Field(min_length=5, max_length=1000)


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
