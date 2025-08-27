# app/main.py
import os
import logging
from fastapi import FastAPI, Request, Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from .api import router
from .settings import settings
from .instrumentation import TrackRequest

app = FastAPI(title=settings.app_name)
app.include_router(router)

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    tracker = TrackRequest(request.method, request.url.path)
    response = await call_next(request)
    tracker.done(response.status_code)
    return response

@app.get("/metrics")
async def metrics():
    data = generate_latest()
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)

# 👇 Add this: print a nice, connectable URL when the app starts
@app.on_event("startup")
async def show_clickable_url():
    display_host = os.getenv("DISPLAY_HOST", "localhost")
    logging.getLogger("uvicorn.error").info(f"Open your browser at: http://{display_host}:{settings.port}")

if __name__ == "__main__":
    import uvicorn
    # Keep 0.0.0.0 for Docker; this is correct for container networking
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.port, reload=True)
