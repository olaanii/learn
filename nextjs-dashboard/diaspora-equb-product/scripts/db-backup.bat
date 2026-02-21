@echo off
REM Daily PostgreSQL backup for Diaspora Equb (Windows).
REM Usage: scripts\db-backup.bat
REM Requires: pg_dump in PATH (installed with PostgreSQL)

setlocal

if exist "%~dp0..\.env" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%~dp0..\.env") do (
    if not "%%A"=="" if not "%%A:~0,1%"=="#" set "%%A=%%B"
  )
)

if not defined DATABASE_HOST set DATABASE_HOST=localhost
if not defined DATABASE_PORT set DATABASE_PORT=5432
if not defined DATABASE_USERNAME set DATABASE_USERNAME=equb
if not defined DATABASE_NAME set DATABASE_NAME=diaspora_equb
if not defined DATABASE_PASSWORD set DATABASE_PASSWORD=change_me

set BACKUP_DIR=%~dp0..\backups
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set DT=%%I
set TIMESTAMP=%DT:~0,8%_%DT:~8,6%
set FILENAME=%DATABASE_NAME%_%TIMESTAMP%.sql

echo [%date% %time%] Starting backup of %DATABASE_NAME%...

set PGPASSWORD=%DATABASE_PASSWORD%
pg_dump -h %DATABASE_HOST% -p %DATABASE_PORT% -U %DATABASE_USERNAME% -d %DATABASE_NAME% --no-owner --no-privileges -f "%BACKUP_DIR%\%FILENAME%"

if %ERRORLEVEL% EQU 0 (
  echo [%date% %time%] Backup complete: %FILENAME%
) else (
  echo [%date% %time%] Backup FAILED
  exit /b 1
)

endlocal
