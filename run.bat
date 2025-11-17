@echo off
setlocal

set "ROOT=%~dp0"

echo ================================================================================
echo Arduino Glitch Controller - Build and Run
echo ================================================================================
echo.

echo [INFO] Сборка и загрузка прошивки Arduino...
pushd "%ROOT%arduino" >nul
platformio run --target upload
if errorlevel 1 goto build_failed
popd >nul

echo.
echo [OK] Прошивка загружена успешно
echo [INFO] Ожидание 3 секунды для стабилизации Arduino...
timeout /t 3 /nobreak >nul

echo.
echo [INFO] Запуск контроллера Python
echo.
python -m ub.cli run --config "%ROOT%config_test.yaml"
if errorlevel 1 goto controller_failed

echo.
echo ================================================================================
echo [OK] Процесс завершён успешно.
echo ================================================================================
exit /b 0

:build_failed
popd >nul
echo.
echo ================================================================================
echo [ERROR] Сборка/загрузка прошивки завершилась с ошибкой.
echo ================================================================================
echo.
echo Возможные причины:
echo - Arduino не подключена
echo - Неверный COM порт
echo - Порт занят другой программой (закройте Serial Monitor)
echo.
exit /b 1

:controller_failed
echo.
echo ================================================================================
echo [ERROR] Контроллер завершился с ошибкой.
echo ================================================================================
echo.
echo Проверьте:
echo - Правильность COM порта в config_test.yaml
echo - Arduino подключена и прошивка загружена
echo - Нет ошибок в логах выше
echo.
exit /b 1
