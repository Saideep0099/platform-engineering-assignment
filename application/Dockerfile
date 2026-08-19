# Multi-stage: build deps in one layer set, ship a slim runtime.
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim
# Non-root user — required by most security baselines and by our PodSecurity policy
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY src/ ./src/
USER 10001
EXPOSE 8080
# Exec-form CMD so uvicorn receives SIGTERM directly -> graceful shutdown
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
