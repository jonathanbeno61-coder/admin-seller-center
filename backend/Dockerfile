FROM python:3.14-slim

WORKDIR /app

# Library sistem yang dibutuhkan XGBoost
RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Beri izin tulis agar SQLite bisa membuat database di container
RUN chmod -R 777 /app

ENV PORT=7860
EXPOSE 7860

CMD ["gunicorn", "app_api:app", "--bind", "0.0.0.0:7860", "--timeout", "120"]
