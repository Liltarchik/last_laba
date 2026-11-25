FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
RUN useradd --system --uid 10001 app
USER app
ENV PORT=8080
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:$PORT app:app"]
