# ---------- Stage 1: Builder ----------
FROM python:3.10-slim AS builder

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./

ENV PIP_NO_CACHE_DIR=1

RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir .

COPY src ./src

# ---------- Stage 2: Test ----------
FROM python:3.10-slim AS test

WORKDIR /app

# Устанавливаем PYTHONPATH здесь
ENV PYTHONPATH=/app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq5 && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY src ./src
COPY tests ./tests

RUN python -m pip install --no-cache-dir -e ".[test]"

CMD ["pytest", "-v"]

# ---------- Stage 3: Runtime ----------
FROM python:3.10-slim AS runtime

WORKDIR /app

# Также устанавливаем PYTHONPATH для runtime
ENV PYTHONPATH=/app

RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app/src /app/src

RUN find /usr/local/lib/python3.10/site-packages -name '__pycache__' -type d -exec rm -rf {} + \
    && find /usr/local/lib/python3.10/site-packages -name '*.pyc' -type f -delete

RUN useradd -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser
ENV PATH="/home/appuser/.local/bin:${PATH}"

EXPOSE 8112

CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8112"]
