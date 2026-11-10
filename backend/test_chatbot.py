"""Chat proxy regression tests; no live API calls or real credentials."""

import io
import json
import os
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

from fastapi import HTTPException
from pydantic import ValidationError

from chatbot import ChatInput, chat


class ChatTests(unittest.TestCase):
    def test_missing_key_does_not_call_provider(self):
        with patch.dict(os.environ, {}, clear=True), patch("chatbot.urlopen") as send:
            with self.assertRaises(HTTPException) as error:
                chat(ChatInput(message="Hello"))
            self.assertEqual(error.exception.status_code, 503)
            send.assert_not_called()

    def test_success_returns_only_reply(self):
        payload = {"choices": [{"message": {"content": "Hello from the assistant"}}]}
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-placeholder"}), patch(
            "chatbot.urlopen", return_value=io.BytesIO(json.dumps(payload).encode())
        ) as send:
            self.assertEqual(chat(ChatInput(message="Hello")), {"reply": "Hello from the assistant"})
            request = send.call_args.args[0]
            self.assertEqual(json.loads(request.data)["messages"][-1]["content"], "Hello")
            self.assertEqual(request.get_header("Authorization"), "Bearer test-placeholder")

    def test_provider_errors_are_sanitized(self):
        errors = [
            HTTPError("https://api.openai.com", 401, "private-provider-detail", {}, None),
            URLError("private-provider-detail"),
            TimeoutError("private-provider-detail"),
        ]
        for failure in errors:
            with self.subTest(failure=type(failure).__name__), patch.dict(
                os.environ, {"OPENAI_API_KEY": "test-placeholder"}
            ), patch("chatbot.urlopen", side_effect=failure):
                with self.assertRaises(HTTPException) as error:
                    chat(ChatInput(message="Hello"))
                self.assertEqual(error.exception.status_code, 502)
                self.assertEqual(error.exception.detail, "Chat provider is unavailable.")

    def test_malformed_provider_response(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test-placeholder"}), patch(
            "chatbot.urlopen", return_value=io.BytesIO(b'{}')
        ):
            with self.assertRaises(HTTPException) as error:
                chat(ChatInput(message="Hello"))
            self.assertEqual(error.exception.status_code, 502)

    def test_message_validation(self):
        for message in ["", "x" * 8001]:
            with self.assertRaises(ValidationError):
                ChatInput(message=message)
        with self.assertRaises(HTTPException) as error:
            chat(ChatInput(message="   "))
        self.assertEqual(error.exception.status_code, 422)


if __name__ == "__main__":
    unittest.main()
