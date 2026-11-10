"""Server-side chat proxy. Credentials never leave the backend."""

import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()


class ChatInput(BaseModel):
    message: str = Field(min_length=1, max_length=8000)


@router.post("/chat")
def chat(data: ChatInput):
    if not data.message.strip():
        raise HTTPException(status_code=422, detail="Message must not be blank.")
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        raise HTTPException(status_code=503, detail="Chatbot is not configured.")

    request = Request(
        "https://api.openai.com/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        data=json.dumps({
            "model": os.environ.get("OPENAI_MODEL", "gpt-3.5-turbo"),
            "messages": [
                {"role": "system", "content": "You are a helpful medical assistant chatbot. Provide general diabetes information, not a diagnosis. Encourage consulting a healthcare professional."},
                {"role": "user", "content": data.message},
            ],
        }).encode("utf-8"),
        method="POST",
    )
    try:
        with urlopen(request, timeout=30) as response:
            result = json.load(response)
        reply = result["choices"][0]["message"]["content"]
        if not isinstance(reply, str) or not reply.strip():
            raise ValueError("Empty response")
        return {"reply": reply}
    except (HTTPError, URLError, TimeoutError, OSError, ValueError, KeyError, IndexError, TypeError):
        # Never return upstream error bodies or credentials to the app/logs.
        raise HTTPException(status_code=502, detail="Chat provider is unavailable.") from None
