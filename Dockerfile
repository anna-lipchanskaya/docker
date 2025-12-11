# ---------- Stage 1: Builder ----------
FROM ubuntu:22.04 AS builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-venv \
    gcc \
    libpq-dev \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/local/bin/python

# Копируем только pyproject.toml и устанавливаем зависимости + сам пакет в editable-режиме
COPY pyproject.toml ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -e ".[test]"   # сразу ставим всё, включая dev/test зависимости

# Теперь копируем исходники (после установки, чтобы не переустанавливать зависимости при изменении кода)
COPY src ./src


# ---------- Stage 2: Test ----------
FROM ubuntu:22.04 AS test

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    gcc \
    libpq-dev \
    curl \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN ln -s /usr/bin/python3 /usr/local/bin/python

# Копируем уже установленные пакеты и бинарники из builder
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Копируем исходники и тесты
COPY src ./src
COPY tests ./tests
COPY pyproject.toml ./

# Убеждаемся, что пакет виден (editable install уже сделан в builder, но на всякий случай)
ENV PYTHONPATH=/app

CMD ["pytest", "-v", "tests"]


# ---------- Stage 3: Runtime ----------
FROM ubuntu:22.04 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow
ENV PORT=8112

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    libpq5 \
    curl \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

RUN ln -s /usr/bin/python3 /usr/local/bin/python

# Копируем только нужное из builder
COPY --from=builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /app/src /app/src

# Удаляем __pycache__ и .pyc файлы
RUN find /usr/local/lib/python3.10/dist-packages -name '__pycache__' -type d -exec rm -rf {} + && \
    find /usr/local/lib/python3.10/dist-packages -name '*.pyc' -delete

# Создаём непривилегированного пользователя
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Обязательно, чтобы src был виден
ENV PYTHONPATH=/app

EXPOSE 8112

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8112/users/ || exit 1

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8112"]
