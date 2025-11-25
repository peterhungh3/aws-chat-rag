import os
from typing import Optional


class Settings:
    """Application configuration settings"""
    
    # Application
    APP_NAME: str = "AWS Chat RAG"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # Database (RDS PostgreSQL)
    DATABASE_HOST: Optional[str] = os.getenv("DATABASE_HOST")
    DATABASE_PORT: int = int(os.getenv("DATABASE_PORT", "5432"))
    DATABASE_NAME: str = os.getenv("DATABASE_NAME", "chatrag")
    DATABASE_USER: str = os.getenv("DATABASE_USER", "postgres")
    DATABASE_PASSWORD: Optional[str] = os.getenv("DATABASE_PASSWORD")
    
    # Redis (ElastiCache)
    REDIS_HOST: Optional[str] = os.getenv("REDIS_HOST")
    REDIS_PORT: int = int(os.getenv("REDIS_PORT", "6379"))
    
    # AWS
    AWS_REGION: str = os.getenv("AWS_REGION", "us-east-2")
    
    @property
    def database_url(self) -> Optional[str]:
        """Construct database URL"""
        if not all([self.DATABASE_HOST, self.DATABASE_PASSWORD]):
            return None
        return (
            f"postgresql://{self.DATABASE_USER}:{self.DATABASE_PASSWORD}"
            f"@{self.DATABASE_HOST}:{self.DATABASE_PORT}/{self.DATABASE_NAME}"
        )


settings = Settings()

