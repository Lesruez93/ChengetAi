from fastapi import APIRouter

from app.schemas.classify import ClassifyRequest, ClassifyResponse
from app.services.classifier import get_classifier

router = APIRouter(prefix="/classify", tags=["classify"])


@router.post("", response_model=ClassifyResponse)
def classify_message(payload: ClassifyRequest) -> ClassifyResponse:
    classifier = get_classifier(payload.strategy)
    return classifier.classify(payload.text)
