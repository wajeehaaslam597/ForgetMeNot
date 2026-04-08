import asyncio
import os

import edge_tts

from .paths import AUDIO_DIR

VOICE_MAP = {
    "en": "en-US-JennyNeural",
    "ur": "ur-PK-UzmaNeural",
}


async def _tts_async(text: str, filename_base: str, language: str = "en") -> str:
    voice = VOICE_MAP.get(language, VOICE_MAP["en"])
    path = os.path.join(AUDIO_DIR, f"{filename_base}.mp3")
    communicate = edge_tts.Communicate(text, voice=voice)
    await communicate.save(path)
    return path


def local_tts(text: str, filename_base: str, language: str = "en") -> str:
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures

            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, _tts_async(text, filename_base, language))
                return future.result()
        return loop.run_until_complete(_tts_async(text, filename_base, language))
    except RuntimeError:
        return asyncio.run(_tts_async(text, filename_base, language))

