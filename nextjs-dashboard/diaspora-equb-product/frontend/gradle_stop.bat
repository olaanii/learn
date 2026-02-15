@echo off
REM Stop Gradle daemons to fix "Address already in use: bind". Run from frontend folder.
cd /d "%~dp0"
cd android
call gradlew.bat --stop
cd ..
echo Gradle daemons stopped. You can retry: flutter build apk --release --split-per-abi
pause
