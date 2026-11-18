from typing import List, Optional
from pydantic import BaseModel

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

class CommentIn(BaseModel):
    rating: int = 5
    content: str = ""
