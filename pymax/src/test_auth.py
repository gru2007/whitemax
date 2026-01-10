#!/usr/bin/env python3
"""
Тестовый скрипт для проверки работоспособности pymax перед запаковкой в iOS.
Проверяет основные функции: создание клиента, подключение к Socket, запрос кода.
Использует SocketMaxClient для iOS вместо MaxClient (WebSocket).
"""

import asyncio
import sys
import json
from pathlib import Path

# Добавляем путь к pymax
sys.path.insert(0, str(Path(__file__).parent / "src"))

from pymax import SocketMaxClient
from pymax.payloads import RequestCodePayload, UserAgentPayload


async def test_payload_serialization():
    """Тест: проверка сериализации payload."""
    print("=" * 60)
    print("Тест 1: Сериализация RequestCodePayload")
    print("=" * 60)
    
    payload = RequestCodePayload(
        phone="+79001234567",
        type="START_AUTH",  # Попробуем передать строку напрямую
        language="ru"
    )
    
    payload_dict = payload.to_dict()
    print(f"Payload dict: {json.dumps(payload_dict, indent=2, ensure_ascii=False)}")
    print(f"Type of 'type' field: {type(payload_dict.get('type'))}, value: {payload_dict.get('type')}")
    
    # Проверяем, что все поля правильного типа
    assert isinstance(payload_dict.get("phone"), str), "phone должен быть строкой"
    assert isinstance(payload_dict.get("type"), str), "type должен быть строкой"
    assert isinstance(payload_dict.get("language"), str), "language должен быть строкой"
    
    print("✓ Payload сериализация работает корректно\n")


async def test_client_creation():
    """Тест: создание клиента."""
    print("=" * 60)
    print("Тест 2: Создание SocketMaxClient")
    print("=" * 60)
    
    try:
        # Для iOS используем IOS device_type
        ua = UserAgentPayload(device_type="IOS", app_version="25.12.14")
        client = SocketMaxClient(
            phone="+79294007165",
            work_dir="./test_work_dir",
            headers=ua,
            reconnect=False,
        )
        print(f"✓ Клиент создан успешно")
        print(f"  Host: {client.host}")
        print(f"  Port: {client.port}")
        print(f"  Phone: {client.phone}")
        print(f"  Device type: {client.user_agent.device_type}\n")
        return client
    except Exception as e:
        print(f"✗ Ошибка создания клиента: {e}\n")
        return None


async def test_socket_connection(client):
    """Тест: подключение к Socket."""
    print("=" * 60)
    print("Тест 3: Подключение к Socket")
    print("=" * 60)
    
    if client is None:
        print("✗ Клиент не создан, пропускаем тест\n")
        return False
    
    try:
        print(f"Подключение к {client.host}:{client.port}...")
        await client.connect(client.user_agent)
        
        if client.is_connected:
            print("✓ Socket подключен успешно")
            print(f"  Connected: {client.is_connected}\n")
            return True
        else:
            print("✗ Socket не подключен\n")
            return False
    except Exception as e:
        print(f"✗ Ошибка подключения к Socket: {e}")
        import traceback
        traceback.print_exc()
        print()
        return False


async def test_request_code(client):
    """Тест: запрос кода авторизации."""
    print("=" * 60)
    print("Тест 4: Запрос кода авторизации")
    print("=" * 60)
    
    if client is None:
        print("✗ Клиент не создан, пропускаем тест\n")
        return None
    
    if not client.is_connected:
        print("✗ Socket не подключен, пропускаем тест\n")
        return None
    
    try:
        # Проверяем payload перед отправкой
        from pymax.static.enum import AuthType
        payload_obj = RequestCodePayload(
            phone="+79294007165",
            type=AuthType.START_AUTH,
            language="ru"
        )
        payload_dict = payload_obj.to_dict()
        
        print(f"Отправляемый payload:")
        print(json.dumps(payload_dict, indent=2, ensure_ascii=False))
        print(f"Тип поля 'type': {type(payload_dict.get('type'))}\n")
        
        print("Запрос кода...")
        temp_token = await client.request_code("+79001234567", "ru")
        
        if temp_token:
            print(f"✓ Код запрошен успешно")
            print(f"  Temp token: {temp_token[:20]}...\n")
            return temp_token
        else:
            print("✗ Temp token не получен\n")
            return None
    except Exception as e:
        print(f"✗ Ошибка запроса кода: {e}")
        import traceback
        traceback.print_exc()
        print()
        return None


async def test_cleanup(client):
    """Очистка после тестов."""
    if client and client.is_connected:
        try:
            await client.close()
            print("✓ Клиент закрыт\n")
        except Exception as e:
            print(f"⚠ Ошибка при закрытии клиента: {e}\n")


async def main():
    """Основная функция тестирования."""
    print("\n" + "=" * 60)
    print("Тестирование pymax перед запаковкой в iOS")
    print("=" * 60 + "\n")
    
    # Тест 1: Сериализация payload
    await test_payload_serialization()
    
    # Тест 2: Создание клиента
    client = await test_client_creation()
    
    # Тест 3: Подключение к Socket
    connected = await test_socket_connection(client)
    
    # Тест 4: Запрос кода (только если подключено)
    if connected:
        temp_token = await test_request_code(client)
    else:
        print("⚠ Пропускаем тест запроса кода, так как Socket не подключен\n")
    
    # Очистка
    await test_cleanup(client)
    
    print("=" * 60)
    print("Тестирование завершено")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\nТестирование прервано пользователем")
    except Exception as e:
        print(f"\n\n✗ Критическая ошибка: {e}")
        import traceback
        traceback.print_exc()
