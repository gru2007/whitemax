"""
Модели данных для базы данных - без sqlmodel, используем sqlalchemy.
"""
from uuid import UUID, uuid4

from sqlalchemy import Column, String, TypeDecorator
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class GUID(TypeDecorator):
    """Кастомный тип для хранения UUID в SQLite."""
    impl = String
    cache_ok = True
    
    def load_dialect_impl(self, dialect):
        return dialect.type_descriptor(String(36))
    
    def process_bind_param(self, value, dialect):
        if value is None:
            return value
        elif isinstance(value, UUID):
            return str(value)
        else:
            return str(UUID(value))
    
    def process_result_value(self, value, dialect):
        if value is None:
            return value
        else:
            return UUID(value)


class Auth(Base):
    __tablename__ = "auth"
    
    device_id: UUID = Column(GUID(), primary_key=True, default=uuid4)
    token: str | None = Column(String, nullable=True)
