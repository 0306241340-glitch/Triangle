# Triangle Vương API

FastAPI handles Vương's friends, store, inventory, and 1v1 PvP features.
PostgreSQL stores application data; Firebase is used only to verify sign-in
tokens.

## Endpoints

- `GET /friends`, `/friends/requests`, `/friends/search`
- `POST /friends/{uid}`, `POST /friends/{requestId}/accept`,
  `DELETE /friends/{requestId}`
- `GET /store/items`, `GET /store/inventory`
- `POST /store/purchase`, `POST /store/equip`
- `POST /pvp/queue`, `GET /pvp/queue`, `DELETE /pvp/queue`
- `POST /pvp/invite/{friendUid}`, `GET /pvp/invitations`
- `POST /pvp/rooms/{id}/accept`, `/decline`, `/answer`, `GET /pvp/rooms/{id}`

PvP uses ten questions with a 15-second timer per question. Correct answers
earn 10 points. The API does not send correct answers to the client.

## Run locally

From `api-fastapi/`:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:DATABASE_URL = "postgresql+psycopg://..."
$env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content ..\api\serviceAccountKey.json -Raw
uvicorn main:app --host 0.0.0.0 --port 8000
```

Never commit database credentials or Firebase service-account JSON. For local
development, the API can use SQLite when `DATABASE_URL` is unset.

## Render and Supabase

Keep the Render service root directory as `api-fastapi` and start it with
`uvicorn main:app --host 0.0.0.0 --port $PORT`. Configure these environment
variables in Render:

- `DATABASE_URL`: Supabase PostgreSQL Transaction Pooler connection string.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: existing Firebase service-account JSON.

Vương's Flutter services use
`https://triangle-store-api-vuong-2026.onrender.com` by default. Override it
with `--dart-define=VUONG_API_BASE_URL=...` when needed. The existing
`API_BASE_URL` remains reserved for the app's other API services.
