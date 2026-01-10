"""
Python обертка для Swift для работы с pymax.
Обеспечивает синхронный интерфейс для асинхронного pymax клиента.
"""

import asyncio
import json
import os
import sys
from typing import Any, Dict, List, Optional

# Добавляем текущую директорию в sys.path для поиска модулей
_current_dir = os.path.dirname(os.path.abspath(__file__))
if _current_dir not in sys.path:
    sys.path.insert(0, _current_dir)

PYMAX_AVAILABLE = False
try:
    # Пытаемся импортировать pymax
    from pymax import MaxClient
    from pymax.payloads import UserAgentPayload
    from pymax.types import Chat, Message
    PYMAX_AVAILABLE = True
    print("✓ pymax imported successfully")
except ImportError as e:
    # Если импорт не удался, создаем заглушки для типов
    import sys
    import os
    import traceback
    
    print(f"Warning: Failed to import pymax: {e}")
    print(f"Error type: {type(e).__name__}")
    print(f"Python path: {sys.path}")
    
    # Проверяем наличие pymax
    app_dir = os.path.dirname(os.path.abspath(__file__))
    pymax_dir = os.path.join(app_dir, "pymax")
    print(f"Looking for pymax at: {pymax_dir}")
    print(f"pymax exists: {os.path.exists(pymax_dir)}")
    
    # Проверяем наличие __init__.py
    pymax_init = os.path.join(pymax_dir, "__init__.py")
    if os.path.exists(pymax_init):
        print(f"✓ pymax/__init__.py exists")
    else:
        print(f"✗ pymax/__init__.py NOT found")
    
    # Выводим полный traceback для диагностики
    print("Full traceback:")
    traceback.print_exc()
    
    # Устанавливаем заглушки
    MaxClient = None
    UserAgentPayload = None
    Chat = None
    Message = None


class MaxClientWrapper:
    """Синхронная обертка для MaxClient."""
    
    def __init__(self, phone: str, work_dir: Optional[str] = None):
        """
        Инициализация обертки.
        
        :param phone: Номер телефона
        :param work_dir: Рабочая директория для сохранения сессии
        """
        if MaxClient is None:
            raise RuntimeError("pymax not available")
        
        # Определяем рабочую директорию
        if work_dir is None:
            # Используем временную директорию для iOS
            work_dir = os.path.join(os.path.expanduser("~"), "Documents", "max_cache")
            os.makedirs(work_dir, exist_ok=True)
        
        self.phone = phone
        self.work_dir = work_dir
        self.client: Optional[MaxClient] = None
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        
    def _get_loop(self) -> asyncio.AbstractEventLoop:
        """Получить или создать event loop."""
        if self._loop is None or self._loop.is_closed():
            try:
                self._loop = asyncio.get_event_loop()
            except RuntimeError:
                self._loop = asyncio.new_event_loop()
                asyncio.set_event_loop(self._loop)
        return self._loop
    
    def _run_async(self, coro):
        """Запустить асинхронную функцию синхронно."""
        loop = self._get_loop()
        if loop.is_running():
            # Если loop уже запущен, создаем новый task
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as executor:
                future = executor.submit(asyncio.run, coro)
                return future.result()
        else:
            return loop.run_until_complete(coro)
    
    def create_client(self) -> Dict[str, Any]:
        """
        Создать клиент MaxClient.
        
        :return: Dict с результатом инициализации
        """
        try:
            ua = UserAgentPayload(device_type="WEB", app_version="25.12.13")
            self.client = MaxClient(
                phone=self.phone,
                work_dir=self.work_dir,
                headers=ua,
                reconnect=False,
            )
            return {"success": True, "message": "Client created"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def request_code(self, phone: Optional[str] = None, language: str = "ru") -> Dict[str, Any]:
        """
        Запросить код авторизации.
        
        :param phone: Номер телефона (если не указан, используется из __init__)
        :param language: Язык для сообщения
        :return: Dict с temp_token или ошибкой
        """
        if self.client is None:
            result = self.create_client()
            if not result.get("success"):
                return result
        
        phone = phone or self.phone
        
        try:
            async def _request():
                temp_token = await self.client.request_code(phone, language)
                return {"success": True, "temp_token": temp_token}
            
            return self._run_async(_request())
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def login_with_code(self, temp_token: str, code: str) -> Dict[str, Any]:
        """
        Авторизоваться с кодом.
        
        :param temp_token: Временный токен из request_code
        :param code: 6-значный код верификации
        :return: Dict с результатом авторизации
        """
        if self.client is None:
            result = self.create_client()
            if not result.get("success"):
                return result
        
        try:
            async def _login():
                await self.client.login_with_code(temp_token, code, start=False)
                # Получаем информацию о текущем пользователе
                me_info = None
                if self.client.me:
                    me_info = {
                        "id": self.client.me.id,
                        "first_name": self.client.me.names[0].first_name if self.client.me.names else None,
                    }
                return {
                    "success": True,
                    "token": self.client._token,
                    "me": me_info,
                }
            
            return self._run_async(_login())
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def get_chats(self) -> Dict[str, Any]:
        """
        Получить список чатов.
        
        :return: Dict со списком чатов
        """
        if self.client is None:
            return {"success": False, "error": "Client not initialized"}
        
        if not self.client.is_connected:
            return {"success": False, "error": "Client not connected"}
        
        try:
            async def _get_chats():
                # Получаем все чаты
                chat_ids = [chat.id for chat in self.client.chats]
                if chat_ids:
                    chats = await self.client.get_chats(chat_ids)
                else:
                    chats = []
                
                # Конвертируем в JSON-совместимый формат
                chats_list = []
                for chat in chats:
                    chat_dict = {
                        "id": chat.id,
                        "title": chat.title,
                        "type": chat.type.value if hasattr(chat.type, 'value') else str(chat.type),
                        "photo_id": chat.photo_id,
                        "unread_count": chat.unread_count,
                    }
                    chats_list.append(chat_dict)
                
                return {"success": True, "chats": chats_list}
            
            return self._run_async(_get_chats())
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def get_messages(self, chat_id: int, limit: int = 50) -> Dict[str, Any]:
        """
        Получить сообщения из чата.
        
        :param chat_id: ID чата
        :param limit: Максимальное количество сообщений
        :return: Dict со списком сообщений
        """
        if self.client is None:
            return {"success": False, "error": "Client not initialized"}
        
        if not self.client.is_connected:
            return {"success": False, "error": "Client not connected"}
        
        try:
            async def _get_messages():
                messages = await self.client.fetch_history(chat_id=chat_id, limit=limit)
                
                # Конвертируем в JSON-совместимый формат
                messages_list = []
                for msg in messages:
                    msg_dict = {
                        "id": str(msg.id),
                        "chat_id": msg.chat_id,
                        "text": msg.text or "",
                        "sender_id": msg.sender_id if hasattr(msg, 'sender_id') else None,
                        "date": msg.date if hasattr(msg, 'date') else None,
                        "type": msg.type.value if hasattr(msg.type, 'value') else str(msg.type) if hasattr(msg, 'type') else None,
                    }
                    messages_list.append(msg_dict)
                
                return {"success": True, "messages": messages_list}
            
            return self._run_async(_get_messages())
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def start_client(self) -> Dict[str, Any]:
        """
        Запустить клиент (подключиться и авторизоваться).
        
        :return: Dict с результатом запуска
        """
        if self.client is None:
            result = self.create_client()
            if not result.get("success"):
                return result
        
        try:
            async def _start():
                # Запускаем клиент в фоне, но не ждем бесконечно
                await self.client.connect(self.client.user_agent)
                
                # Если есть сохраненный токен, используем его
                if self.client._token:
                    await self.client._sync(self.client.user_agent)
                    await self.client._post_login_tasks(sync=False)
                    return {
                        "success": True,
                        "connected": self.client.is_connected,
                        "me": {
                            "id": self.client.me.id if self.client.me else None,
                            "first_name": self.client.me.names[0].first_name if self.client.me and self.client.me.names else None,
                        } if self.client.me else None,
                    }
                else:
                    return {
                        "success": True,
                        "connected": self.client.is_connected,
                        "requires_auth": True,
                    }
            
            return self._run_async(_start())
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def stop_client(self) -> Dict[str, Any]:
        """
        Остановить клиент.
        
        :return: Dict с результатом остановки
        """
        if self.client is None:
            return {"success": True, "message": "Client not initialized"}
        
        try:
            async def _stop():
                await self.client.close()
                return {"success": True, "message": "Client stopped"}
            
            return self._run_async(_stop())
        except Exception as e:
            return {"success": False, "error": str(e)}


# Глобальный экземпляр для использования из Swift
_wrapper_instance: Optional[MaxClientWrapper] = None


def create_wrapper(phone: str, work_dir: Optional[str] = None) -> str:
    """Создать глобальный экземпляр обертки."""
    global _wrapper_instance
    if not PYMAX_AVAILABLE:
        return json.dumps({"success": False, "error": "pymax not available - missing dependencies"})
    try:
        _wrapper_instance = MaxClientWrapper(phone, work_dir)
        return json.dumps({"success": True})
    except RuntimeError as e:
        if "pymax not available" in str(e):
            return json.dumps({"success": False, "error": "pymax not available - missing dependencies"})
        return json.dumps({"success": False, "error": str(e)})
    except Exception as e:
        return json.dumps({"success": False, "error": str(e)})


def request_code(phone: Optional[str] = None, language: str = "ru") -> str:
    """Запросить код авторизации."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": False, "error": "Wrapper not initialized"})
    result = _wrapper_instance.request_code(phone, language)
    return json.dumps(result)


def login_with_code(temp_token: str, code: str) -> str:
    """Авторизоваться с кодом."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": False, "error": "Wrapper not initialized"})
    result = _wrapper_instance.login_with_code(temp_token, code)
    return json.dumps(result)


def get_chats() -> str:
    """Получить список чатов."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": False, "error": "Wrapper not initialized"})
    result = _wrapper_instance.get_chats()
    return json.dumps(result)


def get_messages(chat_id: int, limit: int = 50) -> str:
    """Получить сообщения из чата."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": False, "error": "Wrapper not initialized"})
    result = _wrapper_instance.get_messages(chat_id, limit)
    return json.dumps(result)


def start_client() -> str:
    """Запустить клиент."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": False, "error": "Wrapper not initialized"})
    result = _wrapper_instance.start_client()
    return json.dumps(result)


def stop_client() -> str:
    """Остановить клиент."""
    global _wrapper_instance
    if _wrapper_instance is None:
        return json.dumps({"success": True, "message": "Wrapper not initialized"})
    result = _wrapper_instance.stop_client()
    return json.dumps(result)
