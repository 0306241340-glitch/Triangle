"""Ket noi SQL: local dung SQLite, deploy dung Postgres (Supabase) — cung 1 code.
Supabase: lay chuoi Transaction pooler (cong 6543, co ?pgbouncer=true), KHONG lay
Direct connection — Direct dung IPv6, Render va may An (IPv4) khong noi duoc.
Pooler chay che do transaction nen SQLAlchemy phai dung NullPool (khong giu ket noi)."""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from sqlalchemy.pool import NullPool

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./quiz.db")
# Dung psycopg3 (goi psycopg): psycopg2-binary khong co wheel cho Python 3.14
# nen pip phai build tu source va doi pg_config. Supabase/Render deu chay duoc.
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg://", 1)
elif DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
elif DATABASE_URL.startswith("postgresql"):
    connect_args = {"prepare_threshold": 0}
else:
    connect_args = {}

engine_kwargs = {"connect_args": connect_args}
if "pooler.supabase.com" in DATABASE_URL or ":6543" in DATABASE_URL:
    engine_kwargs["poolclass"] = NullPool
engine = create_engine(DATABASE_URL, **engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
