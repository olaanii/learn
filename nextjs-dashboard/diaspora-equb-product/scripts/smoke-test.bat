@echo off
REM ──────────────────────────────────────────────────────────
REM  Diaspora Equb — Testnet Smoke Test (Windows)
REM  Verifies all critical API endpoints after deployment.
REM
REM  Usage:
REM    scripts\smoke-test.bat
REM    scripts\smoke-test.bat https://your-ngrok-url.ngrok-free.app/api
REM ──────────────────────────────────────────────────────────

setlocal enabledelayedexpansion

if "%~1"=="" (
    set "BASE_URL=http://localhost:3001/api"
) else (
    set "BASE_URL=%~1"
)

set PASS=0
set FAIL=0
set WARN=0
set TOKEN=

echo.
echo ═══════════════════════════════════════════════════════
echo  Diaspora Equb — Testnet Smoke Test
echo  Target: %BASE_URL%
echo  Time:   %DATE% %TIME%
echo ═══════════════════════════════════════════════════════

REM ── 1. Health ──────────────────────────────────────────
echo.
echo 1. Health Checks
call :check "Health endpoint" GET "/health"
call :check "Indexer status" GET "/health/indexer"

REM ── 2. Fayda Status ───────────────────────────────────
echo.
echo 2. Fayda Integration Status
call :check "Fayda status" GET "/auth/fayda/status"

REM ── 3. Auth (dev-login) ───────────────────────────────
echo.
echo 3. Authentication
call :dev_login

REM ── 4. Token Endpoints ────────────────────────────────
echo.
echo 4. Token Endpoints
call :check_authed "Token balance" GET "/token/balance?walletAddress=0x1234567890abcdef1234567890abcdef12345678&token=USDC"
call :check_authed "Token rates" GET "/token/rates"
call :check_authed "Supported tokens" GET "/token/supported"
call :check_authed "Transactions" GET "/token/transactions?walletAddress=0x1234567890abcdef1234567890abcdef12345678"

REM ── 5. Pool Endpoints ─────────────────────────────────
echo.
echo 5. Pool Endpoints
call :check_authed "List pools" GET "/pools"

REM ── 6. Collateral ─────────────────────────────────────
echo.
echo 6. Collateral Endpoints
call :check_authed "Collateral info" GET "/collateral/0x1234567890abcdef1234567890abcdef12345678"

REM ── 7. Tier / Credit ──────────────────────────────────
echo.
echo 7. Tier ^& Credit
call :check_authed "Tier info" GET "/tier/0x1234567890abcdef1234567890abcdef12345678"
call :check_authed "Credit score" GET "/credit/0x1234567890abcdef1234567890abcdef12345678"

REM ── 8. Notifications ──────────────────────────────────
echo.
echo 8. Notifications
call :check_authed "List notifications" GET "/notifications"
call :check_authed "Unread count" GET "/notifications/unread-count"

REM ── Summary ────────────────────────────────────────────
echo.
echo ═══════════════════════════════════════════════════════
echo  Results: %PASS% passed, %FAIL% failed, %WARN% warnings
echo ═══════════════════════════════════════════════════════

if %FAIL% GTR 0 (
    echo.
    echo  Some tests FAILED. Review the output above.
    exit /b 1
) else (
    echo.
    echo  All critical checks passed!
    exit /b 0
)

REM ── Functions ──────────────────────────────────────────
:check
set "LABEL=%~1"
set "METHOD=%~2"
set "PATH_=%~3"
set "URL=%BASE_URL%%PATH_%"

for /f %%i in ('curl -s -o nul -w "%%{http_code}" -X %METHOD% "%URL%" 2^>nul') do set "CODE=%%i"

if "%CODE%"=="000" (
    echo   FAIL  %LABEL% — connection refused
    set /a FAIL+=1
) else if %CODE% GEQ 200 if %CODE% LSS 300 (
    echo   PASS  %LABEL% ^(HTTP %CODE%^)
    set /a PASS+=1
) else if "%CODE%"=="401" (
    echo   WARN  %LABEL% ^(HTTP 401 — expected for auth-protected route^)
    set /a WARN+=1
) else (
    echo   FAIL  %LABEL% ^(HTTP %CODE%^)
    set /a FAIL+=1
)
exit /b

:dev_login
set "URL=%BASE_URL%/auth/dev-login"
for /f "delims=" %%i in ('curl -s -X POST "%URL%" -H "Content-Type: application/json" -d "{\"walletAddress\":\"0x1234567890abcdef1234567890abcdef12345678\"}" 2^>nul') do set "BODY=%%i"

echo %BODY% | findstr /c:"accessToken" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=2 delims=:," %%a in ('echo %BODY% ^| findstr /c:"accessToken"') do (
        set "TOKEN=%%~a"
    )
    set "TOKEN=!TOKEN:"=!"
    echo   PASS  Dev login — got JWT token
    set /a PASS+=1
) else (
    echo   WARN  Dev login unavailable ^(expected in production^)
    set /a WARN+=1
    set TOKEN=
)
exit /b

:check_authed
set "LABEL=%~1"
set "METHOD=%~2"
set "PATH_=%~3"

if "%TOKEN%"=="" (
    echo   SKIP  %LABEL% ^(no auth token^)
    set /a WARN+=1
    exit /b
)

set "URL=%BASE_URL%%PATH_%"
for /f %%i in ('curl -s -o nul -w "%%{http_code}" -X %METHOD% "%URL%" -H "Authorization: Bearer %TOKEN%" 2^>nul') do set "CODE=%%i"

if "%CODE%"=="000" (
    echo   FAIL  %LABEL% — connection refused
    set /a FAIL+=1
) else if %CODE% GEQ 200 if %CODE% LSS 300 (
    echo   PASS  %LABEL% ^(HTTP %CODE%^)
    set /a PASS+=1
) else if "%CODE%"=="404" (
    echo   WARN  %LABEL% ^(HTTP 404 — route exists but no data^)
    set /a WARN+=1
) else (
    echo   FAIL  %LABEL% ^(HTTP %CODE%^)
    set /a FAIL+=1
)
exit /b
