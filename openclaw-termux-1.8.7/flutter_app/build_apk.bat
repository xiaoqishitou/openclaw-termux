@echo off
cd /d "%~dp0"
F:\flutter\bin\flutter.bat build apk --release > "%~dp0build_output.txt" 2>&1
flutter build apk --debug --verbose