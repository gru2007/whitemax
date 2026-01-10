"""
Утилиты для работы с pymax.
"""
import asyncio
import re
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any, NoReturn

import aiohttp

from pymax.exceptions import Error, RateLimitError


class MixinsUtils:
    @staticmethod
    def handle_error(data: dict[str, Any]) -> NoReturn:
        error = data.get("payload", {}).get("error")
        localized_message = data.get("payload", {}).get("localizedMessage")
        title = data.get("payload", {}).get("title")
        message = data.get("payload", {}).get("message")

        if error == "too.many.requests":  # TODO: вынести в статик
            raise RateLimitError(
                error=error,
                message=message,
                title=title,
                localized_message=localized_message,
            )

        raise Error(
            error=error,
            message=message,
            title=title,
            localized_message=localized_message,
        )

    @staticmethod
    async def _fetch_and_extract_async(url: str, session: aiohttp.ClientSession) -> str | None:
        """Асинхронно получает URL и извлекает версию."""
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as response:
                js_code = await response.text()
        except (aiohttp.ClientError, asyncio.TimeoutError):
            return None
        return MixinsUtils._extract_version(js_code)

    @staticmethod
    def _extract_version(js_code: str) -> str | None:
        ws_anchor = "wss://ws-api.oneme.ru/websocket"
        pos = js_code.find(ws_anchor)
        if pos == -1:
            return None

        snippet = js_code[pos : pos + 2000]

        match = re.search(r'[:=]\s*"(\d{1,2}\.\d{1,2}\.\d{1,2})"', snippet)
        if match:
            version = match.group(1)
            return version

        return None

    @staticmethod
    async def _get_current_web_version_async() -> str | None:
        """Асинхронная версия получения текущей версии веб-сайта."""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get("https://web.max.ru/", timeout=aiohttp.ClientTimeout(total=10)) as response:
                    html = await response.text()
        except (aiohttp.ClientError, asyncio.TimeoutError):
            return None

        try:
            main_chunk_import = html.split("import(")[2].split(")")[0].strip("\"'")
            main_chunk_url = f"https://web.max.ru{main_chunk_import}"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(main_chunk_url, timeout=aiohttp.ClientTimeout(total=10)) as response:
                    main_chunk_code = await response.text()
        except (aiohttp.ClientError, asyncio.TimeoutError, IndexError):
            return None

        try:
            arr = main_chunk_code.split("\n")[0].split("[")[1].split("]")[0].split(",")
            urls = []
            for i in arr:
                if "/chunks/" in i:
                    url = "https://web.max.ru/_app/immutable" + i[3 : len(i) - 1]
                    urls.append(url)

            if urls:
                async with aiohttp.ClientSession(headers={"User-Agent": "Mozilla/5.0"}) as session:
                    tasks = [
                        MixinsUtils._fetch_and_extract_async(url, session) 
                        for url in urls
                    ]
                    results = await asyncio.gather(*tasks, return_exceptions=True)
                    for ver in results:
                        if ver and isinstance(ver, str):
                            return ver
        except (aiohttp.ClientError, asyncio.TimeoutError, IndexError):
            pass
        return None

    @staticmethod
    def get_current_web_version() -> str | None:
        """Получить текущую версию веб-сайта (синхронный интерфейс)."""
        try:
            loop = asyncio.get_event_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
        
        if loop.is_running():
            # Если loop уже запущен, используем новый
            new_loop = asyncio.new_event_loop()
            try:
                return new_loop.run_until_complete(MixinsUtils._get_current_web_version_async())
            finally:
                new_loop.close()
        else:
            return loop.run_until_complete(MixinsUtils._get_current_web_version_async())
