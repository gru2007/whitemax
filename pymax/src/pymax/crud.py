"""
CRUD операции для базы данных - без sqlmodel, используем sqlalchemy.
"""
from typing import cast
from uuid import UUID

from sqlalchemy import create_engine, select
from sqlalchemy.engine.base import Engine
from sqlalchemy.orm import Session, sessionmaker

from .models import Auth, Base


class Database:
    def __init__(self, workdir: str) -> None:
        self.workdir = workdir
        self.engine = self.get_engine(workdir)
        self.SessionLocal = sessionmaker(bind=self.engine)
        self.create_all()
        self._ensure_single_auth()

    def create_all(self) -> None:
        Base.metadata.create_all(self.engine)

    def get_engine(self, workdir: str) -> Engine:
        return create_engine(f"sqlite:///{workdir}/session.db")

    def get_session(self) -> Session:
        return self.SessionLocal()

    def get_auth_token(self) -> str | None:
        with self.get_session() as session:
            result = session.execute(select(Auth.token)).scalar_one_or_none()
            return cast(str | None, result)

    def get_device_id(self) -> UUID:
        with self.get_session() as session:
            device_id = session.execute(select(Auth.device_id)).scalar_one_or_none()

            if device_id is None:
                auth = Auth()
                session.add(auth)
                session.commit()
                session.refresh(auth)
                return auth.device_id
            return device_id

    def insert_auth(self, auth: Auth) -> Auth:
        with self.get_session() as session:
            session.add(auth)
            session.commit()
            session.refresh(auth)
            return auth

    def update_auth_token(self, device_id: UUID | None = None, token: str | None = None) -> None:
        """
        Обновить токен авторизации в базе данных.
        
        :param device_id: ID устройства (опционально, для совместимости)
        :param token: Токен авторизации
        """
        with self.get_session() as session:
            auth = session.execute(select(Auth)).scalar_one_or_none()
            if auth is None:
                auth = Auth()
                session.add(auth)
            if token is not None:
                auth.token = token
            session.commit()

    def update(self, auth: Auth) -> Auth:
        with self.get_session() as session:
            session.add(auth)
            session.commit()
            session.refresh(auth)
            return auth

    def _ensure_single_auth(self) -> None:
        """Убеждаемся, что есть только одна запись в таблице auth."""
        with self.get_session() as session:
            auths = list(session.execute(select(Auth)).scalars().all())
            if len(auths) == 0:
                auth = Auth()
                session.add(auth)
                session.commit()
            elif len(auths) > 1:
                # Удаляем все кроме первой записи
                for auth in auths[1:]:
                    session.delete(auth)
                session.commit()
