# syntax=docker/dockerfile:1.7


FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
PYTHONUNBUFFERED=1


# ===== builder =====
FROM base AS builder
WORKDIR /w
COPY app/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
pip install --upgrade pip && pip wheel --no-cache-dir --no-deps -r requirements.txt -w /wheels


# ===== runtime =====
FROM base AS runtime
WORKDIR /app
ENV PORT=8080 \
APP_ENV=prod \
APP_LOG_LEVEL=INFO


# Install runtime deps only
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/* && rm -rf /wheels


# Copy code last (better layer caching)
COPY app/ ./app/
EXPOSE 8080


# App user (non-root)
RUN useradd -r -u 10001 appuser && chown -R appuser:appuser /app
USER appuser


CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]