from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from datetime import datetime
from zoneinfo import ZoneInfo
import os

app = FastAPI(title="AWS Chat RAG API", version="1.0.0")

# CORS middleware for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for frontend
# In Docker container: WORKDIR is /app, so frontend is at /app/frontend/
frontend_path = os.path.join(os.getcwd(), "frontend")
if os.path.exists(frontend_path):
    app.mount("/static", StaticFiles(directory=frontend_path), name="static")


@app.get("/")
async def root():
    """Serve the frontend HTML page"""
    frontend_file = os.path.join(frontend_path, "index.html")
    if os.path.exists(frontend_file):
        return FileResponse(frontend_file)
    return {"message": "Frontend not found. API is running at /hello"}


@app.get("/hello")
async def hello():
    """Simple hello endpoint to test the deployment"""
    est_time = datetime.now(ZoneInfo("America/New_York"))
    return {"message": f"hello - Current EST time: {est_time.strftime('%Y-%m-%d %H:%M:%S %Z')}"}


@app.get("/health")
async def health_check():
    """Health check endpoint for ALB"""
    return {"status": "healthy"}

