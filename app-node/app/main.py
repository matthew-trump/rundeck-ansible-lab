from fastapi import FastAPI
import datetime

app = FastAPI(title="Lab API")

# This value gets bumped on each "deploy" so you can see the update take effect
VERSION = "1.0.0"

@app.get("/")
def root():
    return {
        "service": "rundeck-ansible-lab",
        "version": VERSION,
        "status": "ok",
        "timestamp": datetime.datetime.utcnow().isoformat(),
    }

@app.get("/health")
def health():
    return {"status": "healthy", "version": VERSION}
