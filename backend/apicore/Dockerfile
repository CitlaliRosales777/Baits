FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY run.py .

RUN useradd --create-home --uid 10001 apicore
USER apicore

EXPOSE 65000

CMD ["gunicorn", "--bind", "0.0.0.0:65000", "--workers", "2", "--threads", "4", "run:app"]

