FROM python:3.11-slim
WORKDIR /app
RUN pip install flask --no-cache-dir
COPY app.py .
ENV PORT=5000
EXPOSE 5000
CMD ["python3", "app.py"]
