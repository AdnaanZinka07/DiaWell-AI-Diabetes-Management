# DiaWell AI Diabetes Management

An MSc AI project combining a Flutter diabetes management application with a
FastAPI backend for diabetes risk prediction, glucose forecasting, anomaly
detection and an AI chatbot. AI outputs support review and are not diagnoses.

## Features and technologies

- Flutter/Dart interface with glucose records, medications, reports, profile,
  community feed, Bluetooth glucose support and AI insights screens.
- Firebase Authentication, Cloud Firestore and Firebase Storage integrations.
- FastAPI/Pydantic backend with NumPy, scikit-learn, joblib and TensorFlow/Keras.
- Packaged diabetes classifier, LSTM glucose model, isolation forest and scalers
  in `backend/models/`. The LSTM endpoint expects exactly 12 readings.
- OpenAI chat through FastAPI; the Flutter application contains no OpenAI secret.

## Repository structure

```text
lib/                 Flutter screens, services, widgets and Firebase options
assets/              App logo
backend/main.py      FastAPI application and ML prediction endpoints
backend/chatbot.py   Server-side chat proxy
backend/models/      Trained models and preprocessing artifacts
backend/test_chatbot.py  Chat proxy tests without live API calls
test/                Flutter test (currently a placeholder smoke test)
pubspec.yaml         Flutter dependencies and assets
```

The repository contains inference code and trained model artifacts. No training
scripts or source datasets were found in this project checkout.

## Requirements

- Flutter with Dart compatible with `^3.7.0` and the SDK/toolchain for your target.
- Python 3.10+ (the existing local backend was verified with Python 3.12).
- Access to the configured Firebase project, or your own Firebase project with
  Authentication, Firestore and Storage configured for the features you use.
- A newly issued OpenAI API key with API access for chat. The previously exposed
  key was revoked and must not be reused. Other ML endpoints do not require it.

## Backend setup

Run from the repository root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
```

Edit `backend/.env` locally and set `OPENAI_API_KEY`. Keep `OPENAI_MODEL` as the
existing `gpt-3.5-turbo` default, or select a Chat Completions model available to
your API account. Never put the key in Dart, `--dart-define`, or Git.
Load the file into the backend process before starting:

```bash
set -a
source .env
set +a
python -m uvicorn main:app --host 127.0.0.1 --port 8001
```

Start from `backend/` because the existing model paths are relative to that
directory. API documentation is at `http://127.0.0.1:8001/docs`.
The `.env` file is not loaded automatically; the commands above export it.
Without a key, `/chat` returns a configuration error while the ML routes remain
available. Provider errors are sanitized before reaching the app.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/` | Backend status |
| POST | `/predict-risk` | Diabetes risk from eight clinical inputs |
| POST | `/predict-glucose` | Forecast from 12 glucose readings |
| POST | `/detect-anomaly` | Current/previous glucose anomaly assessment |
| POST | `/chat` | Chat request with JSON `{"message": "..."}` |

TensorFlow/Keras compatibility matters for the included model format;
`requirements.txt` retains the existing dependencies, including
`scikit-learn==1.6.1`. A fresh dependency installation has not been verified.

## Flutter setup

From the repository root:

```bash
flutter pub get
flutter run --dart-define=DIAWELL_API_BASE_URL=http://127.0.0.1:8001
```

`DIAWELL_API_BASE_URL` configures the chatbot backend URL and contains no secret.
For an Android emulator use `http://10.0.2.2:8001`; a physical device needs a
reachable development-machine address and a backend bound to that interface.
The existing ML service in `lib/services/ai_api_service.dart` separately uses
`http://127.0.0.1:8001`; adjust that URL for device-based ML testing.
Backend CORS currently permits local browser origins.

Firebase client configuration is retained in `lib/firebase_options.dart` and
`android/app/google-services.json`. These client identifiers are not server
credentials; access to data still depends on Firebase rules and authentication.
Do not commit Firebase Admin service account files or patient data.

This is a local university review setup. The backend does not implement user
authentication or rate limiting; keep it local for review. No deployment is
performed by these instructions.

## Verification

```bash
flutter analyze
flutter test
cd backend
.venv/bin/python -m unittest test_chatbot -v
```

Use `venv/bin/python` instead if using the existing local `backend/venv`.
Chat tests mock the provider and cover missing configuration, success, invalid
messages, malformed responses and sanitized provider failures. Live chat needs
a replacement key and has not been exercised with a real provider credential.

The backend follows OpenAI's
[server-side key handling guidance](https://developers.openai.com/api/reference/overview)
and [Chat Completions API](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create).
