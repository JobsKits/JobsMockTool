@echo off
setlocal
cd /d %~dp0

echo [JobsMockTool] Create / reuse virtual environment...
python -m venv .venv
if errorlevel 1 goto :error

call .venv\Scripts\activate

echo [JobsMockTool] Install dependencies...
python -m pip install --upgrade pip
pip install -r requirements.txt
if errorlevel 1 goto :error

echo [JobsMockTool] Clean old build outputs...
rmdir /s /q build 2>nul
rmdir /s /q dist 2>nul

echo [JobsMockTool] Build Windows executable folder...
echo QtWebEngine is large. The generated exe must stay with the dist\JobsMockTool folder.
pyinstaller --noconfirm --clean --windowed --onedir --name "JobsMockTool" --collect-all PySide6 app.py
if errorlevel 1 goto :error

echo.
echo Windows executable is here:
echo dist\JobsMockTool\JobsMockTool.exe
echo.
pause
exit /b 0

:error
echo.
echo Build failed. Please check the output above.
pause
exit /b 1
