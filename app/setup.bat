@echo off
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)
call venv\Scripts\activate.bat
echo Installing dependencies...
pip install -r requirements.txt
echo Setup complete. Run start_server.bat to start the application.
pause
