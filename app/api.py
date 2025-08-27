from fastapi import APIRouter, Response, status
from .instrumentation import TrackRequest


from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def root():
    return {
        "app": "devops-app",
        "endpoints": ["/healthz", "/hello?name=YOU", "/metrics", "/docs"]
    }

@router.get("/favicon.ico")
async def favicon():
    # No favicon yet; avoid noisy 404s
    return Response(status_code=204)

@router.get("/healthz")
async def healthz():
    return {"status": "ok"}

@router.get("/hello")
async def hello(name: str = "world"):
    return {"message": f"Hello, {name}!"}

@router.get("/work")
async def work():
# Simulate some work
    return {"result": 42}