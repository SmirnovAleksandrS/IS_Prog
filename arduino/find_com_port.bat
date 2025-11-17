@echo off
REM Find Arduino COM port on Windows
REM This script helps identify which COM port the Arduino is connected to

echo ================================================================================
echo Arduino COM Port Finder
echo ================================================================================
echo.

echo Searching for USB Serial devices...
echo.

REM Use PowerShell to query COM ports
powershell -Command "Get-WmiObject Win32_PnPEntity | Where-Object { $_.Name -match 'COM\d+' } | Select-Object Name, DeviceID | Format-Table -AutoSize"

echo.
echo ================================================================================
echo Instructions:
echo ================================================================================
echo 1. Look for devices with "USB Serial" or "Arduino" in the name
echo 2. Note the COM port number (e.g., COM10)
echo 3. Update config.yaml in the project root:
echo.
echo    serial:
echo      port: "COM10"  # Replace with your port
echo      baudrate: 115200
echo.
echo 4. Test connection:
echo    cd arduino
echo    python test_protocol.py
echo.
echo ================================================================================
pause
