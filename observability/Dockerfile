FROM python:3.11-slim

WORKDIR /app

COPY exporter.py /app/exporter.py

RUN pip install prometheus_client psycopg

ENTRYPOINT ["python", "/app/exporter.py"]
