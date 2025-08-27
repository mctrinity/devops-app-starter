from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "devops-app"
    env: str = "local"
    log_level: str = "INFO"
    port: int = 8080
    # Example of secrets / config
    db_url: str | None = None

    class Config:
        env_prefix = "APP_"  # e.g., APP_ENV=prod
        extra = "ignore"


settings = Settings()
