# FastAPI store service

This service implements the store endpoints while the rest of the app continues
to use the existing Express API:

- `GET /store/items`
- `POST /store/purchase`
- `POST /store/equip`

It verifies Firebase ID tokens and uses the existing Firestore collections:
`items`, `users`, `user_items`, and `transactions`.

## Run locally

From `api-fastapi/`:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content ..\api\serviceAccountKey.json -Raw
uvicorn main:app --host 0.0.0.0 --port 8000
```

Do not commit service-account credentials. The Android emulator reaches the
host machine at `http://10.0.2.2:8000`; pass this URL to Flutter with:

```powershell
flutter run --dart-define=STORE_API_BASE_URL=http://10.0.2.2:8000
```

The Android debug manifest permits cleartext traffic for local development;
release builds do not enable it.

## Deploy to Render

The root `render.yaml` defines this as a separate Python web service. Deploy the
Blueprint and provide `FIREBASE_SERVICE_ACCOUNT_JSON` when Render asks for the
secret. The Flutter service defaults to `https://triangle-store-api.onrender.com`;
if Render assigns a different URL, pass it with `--dart-define=STORE_API_BASE_URL=...`
when building or running the app.
