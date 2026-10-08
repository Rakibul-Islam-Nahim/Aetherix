@echo off
REM Local Windows preview: serves the Flutter web bundle on http://localhost:8765
REM while the API lives at https://news.cybersentinel.top/api/v1.
REM Open http://localhost:8765 in any browser.

set ROOT=%~dp0..\..\backend\static
if not exist "%ROOT%\index.html" (
  echo Web bundle not found at %ROOT%
  echo Build it first:  cd flutter\Aetherix_app ^&^& fvm flutter build web --release --dart-define=AETHERIX_API_BASE_URL=https://news.cybersentinel.top/api/v1
  echo Then copy build\web\* into backend\static\
  exit /b 1
)

cd /d "%ROOT%"
echo Serving Aetherix web UI at http://localhost:8765/
echo (API calls go to https://news.cybersentinel.top/api/v1)
echo Press Ctrl+C to stop.
py -3 -m http.server 8765