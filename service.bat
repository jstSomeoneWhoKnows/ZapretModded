@echo off
chcp 866 >nul
setlocal EnableDelayedExpansion

set "LOCAL_VERSION=1.0.1"

:: Внешние команды
if "%~1"=="status_zapret" (
    call :test_service zapret soft
    call :tcp_enable
    exit /b
)

if "%~1"=="check_updates" (
    if exist "%~dp0utils\check_updates.enabled" (
        if not "%~2"=="soft" (
            start /b service check_updates soft
        ) else (
            call :service_check_updates soft
        )
    )
    exit /b
)

if "%~1"=="load_game_filter" (
    call :game_switch_status
    exit /b
)

if "%1"=="admin" (
    call :check_command chcp
    call :check_command find
    call :check_command findstr
    call :check_command netsh
    echo Запущено с правами администратора
) else (
    call :check_extracted
    call :check_command powershell
    echo Запрос прав администратора...
    powershell -NoProfile -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"\"%~f0\" admin\"' -Verb RunAs"
    exit
)

:: МЕНЮ ================================
:menu
cls
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status

set "menu_choice=null"

echo.
echo   ZAPRET МЕНЕДЖЕР  v!LOCAL_VERSION!
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo   Запущенная стратегия: "%%B"
)
echo   ----------------------------------------
echo.
echo   :: СЕРВИСЫ
echo      1. Установить сервис
echo      2. Удалить все запущенные сервисы
echo      3. Проверить статус (Работает/Не работает)
echo.
echo   :: НАСТРОЙКИ
echo      4. Игровой фильтр             [!GameFilterStatus!]
echo      5. Фильтр IP-листа            [!IPsetStatus!]
echo      6. Автообновления             [!CheckUpdatesStatus!]
echo.
echo   :: МЕНЕДЖЕР ОБНОВЛЕНИЙ
echo      7. Обновить список доменов
echo      8. Обновить список хостов
echo      9. Проверить наличие обновлений
echo.
echo   :: ИНСТРУМЕНТЫ
echo      10. Запустить диагностику (проверка совместимости)
echo      11. Запустить тесты
echo.
echo   ----------------------------------------
echo      0. Выход
echo.

set /p "menu_choice=   Выберите пункт (0-11): "

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto game_switch
if "%menu_choice%"=="5" goto ipset_switch
if "%menu_choice%"=="6" goto check_updates_switch
if "%menu_choice%"=="7" goto ipset_update
if "%menu_choice%"=="8" goto hosts_update
if "%menu_choice%"=="9" goto service_check_updates
if "%menu_choice%"=="10" goto service_diagnostics
if "%menu_choice%"=="11" goto run_tests
if "%menu_choice%"=="0" exit /b
goto menu

:: TCP ENABLE ==========================
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b

:: STATUS ==============================
:service_status
cls
chcp 866 > nul

sc query "zapret" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube 2^>nul') do echo Сервисная стратегия установлена из "%%B"
)

call :test_service zapret
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "Файл WinDivert64.sys не обнаружен."
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    call :PrintGreen "Обход DPI (winws.exe) ЗАПУЩЕН."
) else (
    call :PrintRed "Обход DPI (winws.exe) НЕ ЗАПУЩЕН."
)

pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo "%ServiceName%" уже запущен как служба. Используйте "service.bat" и выберите "Remove Services", если хотите запустить standalone-версию.
        pause
        exit /b
    ) else (
        echo "%ServiceName%" служба ЗАПУЩЕНА.
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! остановлена. Это может быть вызвано конфликтом с другой службой. Запустите диагностику для выявления конфликтов."
) else if not "%~2"=="soft" (
    echo "%ServiceName%" служба НЕ ЗАПУЩЕНА.
)

exit /b

:: REMOVE ==============================
:service_remove
cls
chcp 866 > nul

set "SRVCNAME=zapret"
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    net stop !SRVCNAME!
    sc delete !SRVCNAME!
) else (
    echo Служба "!SRVCNAME!" не установлена
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    taskkill /IM winws.exe /F > nul
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    net stop "WinDivert"
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert"
    )
)
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1

pause
goto menu

:: INSTALL =============================
:service_install
cls
chcp 866 > nul

:: Выбор папки со стратегиями
echo Выберите папку со стратегиями:
echo   1. Стандартные стратегии (strategies)
echo   2. Направленные стратегии (Specstrategies)
set "strategies_choice="
set /p "strategies_choice=Ваш выбор (1 или 2): "
if "%strategies_choice%"=="1" (
    set "STRATEGIES_PATH=%~dp0strategies"
) else if "%strategies_choice%"=="2" (
    set "STRATEGIES_PATH=%~dp0specstrategies"
) else (
    echo Неверный выбор. Возврат в меню...
    pause
    goto menu
)

:: Проверяем, что папка существует
if not exist "%STRATEGIES_PATH%\" (
    echo Папка "%STRATEGIES_PATH%" не найдена. Создайте её и поместите туда .bat файлы стратегий.
    pause
    goto menu
)

cls
:: Main
cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

:: Поиск .bat файлов в выбранной папке, исключая начинающиеся с "service"
echo Список стратегий в папке "%STRATEGIES_PATH%":
set "count=0"
for /f "delims=" %%F in ('powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%STRATEGIES_PATH%' -Filter '*.bat' | Where-Object { $_.Name -notlike 'service*' } | Sort-Object { [Regex]::Replace($_.Name, '(\d+)', { $args[0].Value.PadLeft(8, '0') }) } | ForEach-Object { $_.Name }"') do (
    set /a count+=1
    echo !count!. %%F
    set "file!count!=%%F"
)

if %count%==0 (
    echo В папке "%STRATEGIES_PATH%" нет подходящих .bat файлов.
    pause
    goto menu
)

:: Выбор файла
set "choice="
set /p "choice=Введите номер файла: "
if "!choice!"=="" (
    echo Ничего не выбрано. Возврат в меню...
    pause
    goto menu
)

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo Неверный выбор. Возврат в меню...
    pause
    goto menu
)

:: Полный путь к выбранному файлу
set "FULL_BAT_PATH=%STRATEGIES_PATH%\!selectedFile!"

:: Аргументы, за которыми должно следовать значение
set "args_with_value=sni host altorder"

:: Разбор аргументов
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

:: ВНИМАНИЕ: НЕ задавайте здесь BIN, чтобы findstr искал просто "winws.exe"

for /f "usebackq tokens=*" %%a in ("%FULL_BAT_PATH%") do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

:: Создание службы с разобранными аргументами
call :tcp_enable

set "ARGS=%args%"
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo Финальные аргументы: !ARGS!
set "SRVCNAME=zapret"

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zapret" start= auto
sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!selectedFile!") do set "filename=%%~nF"
reg add "HKLM\System\CurrentControlSet\Services\zapret" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

pause
goto menu

:: CHECK UPDATES =======================
:service_check_updates
chcp 866 > nul
cls

:: Текущая версия и URL
set "GITHUB_VERSION_URL=https://raw.githubusercontent.com/jstSomeoneWhoKnows/ZapretModded/refs/heads/main/version.txt"
set "GITHUB_RELEASE_URL=https://github.com/jstSomeoneWhoKnows/ZapretModded/releases/tag/"
set "GITHUB_DOWNLOAD_URL=https://github.com/jstSomeoneWhoKnows/ZapretModded/releases/latest"

:: Получить последнюю версию с GitHub
for /f "delims=" %%A in ('powershell -NoProfile -Command "(Invoke-WebRequest -Uri \"%GITHUB_VERSION_URL%\" -Headers @{\"Cache-Control\"=\"no-cache\"} -UseBasicParsing -TimeoutSec 5).Content.Trim()" 2^>nul') do set "GITHUB_VERSION=%%A"

:: Обработка ошибок
if not defined GITHUB_VERSION (
    timeout /T 9
    if "%1"=="soft" exit
    goto menu
)

:: Сравнение версий
if "%LOCAL_VERSION%"=="%GITHUB_VERSION%" (
    echo Установлена последняя версия: %LOCAL_VERSION%
    if "%1"=="soft" exit
    pause
    goto menu
)

echo Доступна новая версия: %GITHUB_VERSION%
echo Страница новой версии: %GITHUB_RELEASE_URL%%GITHUB_VERSION%
echo Открывается страница с новой версией...
start "" "%GITHUB_DOWNLOAD_URL%"

if "%1"=="soft" exit
pause
goto menu

:: DIAGNOSTICS =========================
:service_diagnostics
chcp 866 > nul
cls

:: Базовая служба фильтрации
sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "Служба базовой фильтрации (BFE) запущена."
) else (
    call :PrintRed "[X] Служба базовой фильтрации (BFE) не запущена. Эта служба необходима для работы zapret."
)
echo:

:: Проверка прокси
set "proxyEnabled=0"
set "proxyServer="

for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    call :PrintYellow "[?] Системный прокси-сервер включен: !proxyServer!"
    call :PrintYellow "Убедитесь, что прокси доступен, иначе отключите его."
) else (
    call :PrintGreen "Проверка прокси пройдена успешно."
)
echo:

:: Временные метки TCP
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "Проверка временных меток TCP пройдена успешно."
) else (
    call :PrintYellow "[?] Временные метки TCP отключены. Попытка включения..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "Временные метки TCP успешно включены."
    ) else (
        call :PrintRed "[X] Не удалось включить временные метки TCP."
    )
)
echo:

:: Adguard
tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Обнаружен Adguard. Он может вызывать проблемы с Discord."
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/417"
) else (
    call :PrintGreen "Проверка на Adguard пройдена успешно."
)
echo:

:: Killer Network Service
sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Обнаружены службы Killer. Zapret конфликтует с ними."
    call :PrintRed "https://github.com/Flowseal/zapret-discord-youtube/issues/2512#issuecomment-2821119513"
) else (
    call :PrintGreen "Проверка на Killer пройдена успешно."
)
echo:

:: Intel Connectivity Network Service
sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Обнаружена служба Intel Connectivity Network Service. Она конфликтует с zapret."
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "Проверка на Intel Connectivity пройдена успешно."
)
echo:

:: Check Point
set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)
sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 (
    set "checkpointFound=1"
)
if !checkpointFound!==1 (
    call :PrintRed "[X] Обнаружены службы Check Point. Они конфликтуют с zapret."
    call :PrintRed "Попробуйте удалить Check Point."
) else (
    call :PrintGreen "Проверка на Check Point пройдена успешно."
)
echo:

:: SmartByte
sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Обнаружена служба SmartByte. Она конфликтует с zapret."
    call :PrintRed "Попробуйте удалить или остановить SmartByte через services.msc."
) else (
    call :PrintGreen "Проверка на SmartByte пройдена успешно."
)
echo:

:: Файл WinDivert64.sys
set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "Файл WinDivert64.sys не обнаружен."
    echo:
)

:: VPN
set "VPN_SERVICES="
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
        if not defined VPN_SERVICES (
            set "VPN_SERVICES=!VPN_SERVICES!%%A"
        ) else (
            set "VPN_SERVICES=!VPN_SERVICES!, %%A"
        )
    )
    call :PrintYellow "[?] Обнаружены сторонние VPN-службы:!VPN_SERVICES!. Некоторые VPN-службы конфликтуют с zapret."
    call :PrintYellow "Проверьте, что все VPN-службы удалены или остановлены."
) else (
    call :PrintGreen "Проверка на VPN пройдена успешно."
)
echo:

:: Зашифрованный DNS (DoH)
set "dohfound=0"
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 (
        set "dohfound=1"
    )
)
if !dohfound!==0 (
    call :PrintYellow "[?] Убедитесь, что в браузере настроен DNS-сервер, отличный от системного по умолчанию (например, зашифрованный DNS)."
    call :PrintYellow "В Windows 11 можно включить зашифрованный DNS в параметрах сети, чтобы устранить это предупреждение."
) else (
    call :PrintGreen "Проверка на зашифрованный DNS пройдена успешно."
)
echo:

:: Конфликт WinDivert
tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"
sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe не запущен, но служба WinDivert активна. Попытка удаления WinDivert..."
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintRed "[X] Не удалось удалить WinDivert. Проверка конфликтующих служб..."
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[?] Обнаружена конфликтующая служба: %%s. Попытка остановки и удаления..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "Служба %%s успешно удалена."
                ) else (
                    call :PrintRed "[X] Не удалось удалить службу %%s."
                )
                set "found_conflict=1"
            )
        )
        if !found_conflict!==0 (
            call :PrintRed "[X] Конфликтующих служб не найдено. Возможно, другой обходчик использует WinDivert."
        ) else (
            call :PrintYellow "[?] Повторная попытка удаления WinDivert..."
            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert успешно удалён после удаления конфликтующих служб."
            ) else (
                call :PrintRed "[X] WinDivert не может быть удалён. Проверьте вручную, возможно, другой обходчик использует WinDivert."
            )
        )
    ) else (
        call :PrintGreen "WinDivert успешно удалён."
    )
    echo:
)

:: Конфликтующие службы обхода
set "conflicting_services=GoodbyeDPI discordfix_zapret winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Обнаружены конфликтующие службы обхода: !found_conflicts!"
    set "CHOICE="
    set /p "CHOICE=Хотите ли вы удалить эти службы? (Y/N) (по умолчанию N): "
    if "!CHOICE!"=="" set "CHOICE=N"
    if /i "!CHOICE!"=="y" set "CHOICE=Y"
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Остановка и удаление службы: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "Служба %%s успешно удалена."
            ) else (
                call :PrintRed "[X] Не удалось удалить службу %%s."
            )
        )
        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    echo:
)

:: Очистка кэша Discord
set "CHOICE="
set /p "CHOICE=Хотите очистить кэш Discord? (Y/N) (по умолчанию Y): "
if "!CHOICE!"=="" set "CHOICE=Y"
if /i "!CHOICE!"=="y" set "CHOICE=Y"
if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo Discord запущен, закрываю...
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Discord успешно закрыт."
        ) else (
            call :PrintRed "Не удалось закрыть Discord."
        )
    )
    set "discordCacheDir=%appdata%\discord"
    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "Успешно удалена папка !dirPath!"
            ) else (
                call :PrintRed "Не удалось удалить папку !dirPath!"
            )
        ) else (
            call :PrintRed "Папка !dirPath! не существует."
        )
    )
)
echo:

pause
goto menu

:: GAME SWITCH ========================
:game_switch_status
chcp 866 > nul

set "gameFlagFile=%~dp0utils\game_filter.enabled"

if exist "%gameFlagFile%" (
    set "GameFilterStatus=ВКЛЮЧЕН"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=ВЫКЛЮЧЕН"
    set "GameFilter=12"
)
exit /b

:game_switch
chcp 866 > nul
cls

if not exist "%gameFlagFile%" (
    echo Включаем игровой фильтр...
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Перезапустите zapret, чтобы применить изменения."
) else (
    echo Выключаем игровой фильтр...
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Перезапустите zapret, чтобы применить изменения."
)

pause
goto menu

:: CHECK UPDATES SWITCH =================
:check_updates_switch_status
chcp 866 > nul

set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"

if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=ВКЛЮЧЕНЫ"
) else (
    set "CheckUpdatesStatus=ВЫКЛЮЧЕНЫ"
)
exit /b

:check_updates_switch
chcp 866 > nul
cls

if not exist "%checkUpdatesFlag%" (
    echo Включаем проверку обновлений...
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo Выключаем проверку обновлений...
    del /f /q "%checkUpdatesFlag%"
)

pause
goto menu

:: IPSET SWITCH =======================
:ipset_switch_status
chcp 866 > nul

set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"

if !lineCount!==0 (
    set "IPsetStatus=ВСЕ"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=НИЧЕГО"
    ) else (
        set "IPsetStatus=ТОЛЬКО ЗАГРУЖЕННЫЕ"
    )
)
exit /b

:ipset_switch
chcp 866 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="ТОЛЬКО ЗАГРУЖЕННЫЕ" (
    echo Переключаемся в режим <без использования списков>...
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    >"%listFile%" (
        echo 203.0.113.113/32
    )
) else if "%IPsetStatus%"=="НИЧЕГО" (
    echo Переключаемся в режим <работа по всему трафику>...
    >"%listFile%" (
        rem Создаём пустой файл
    )
) else if "%IPsetStatus%"=="ВСЕ" (
    echo Переключаемся в режим <работа по спискам>...
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo Ошибка: нет резервной копии для восстановления. Обновите списки с помощью сервиса.
        pause
        goto menu
    )
)

pause
goto menu

:: IPSET UPDATE =======================
:ipset_update
chcp 866 > nul
cls

set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/ipset-service.txt"

echo Обновление ipset-all.txt...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

echo Завершено.

pause
goto menu

:: HOSTS UPDATE =======================
:hosts_update
chcp 866 > nul
cls

set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/jstSomeoneWhoKnows/ZapretModded/refs/heads/main/hosts"
set "tempFile=%TEMP%\zapret_hosts.txt"
set "needsUpdate=0"

echo Проверка списка хостов...

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -s -o "%tempFile%" "%hostsUrl%"
) else (
    powershell -NoProfile -Command ^
        "$url = '%hostsUrl%';" ^
        "$out = '%tempFile%';" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

if not exist "%tempFile%" (
    call :PrintRed "Не удалось загрузить список хостов из репозитория."
    call :PrintYellow "Проверьте подключение к сети или ссылку: %hostsUrl%"
    pause
    goto menu
)

set "firstLine="
set "lastLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do (
    if not defined firstLine set "firstLine=%%a"
    set "lastLine=%%a"
)

findstr /C:"%firstLine%" "%hostsFile%" >nul 2>&1
if errorlevel 1 set "needsUpdate=1"

findstr /C:"%lastLine%" "%hostsFile%" >nul 2>&1
if errorlevel 1 set "needsUpdate=1"

if "%needsUpdate%"=="0" (
    call :PrintGreen "Файл hosts не требует обновления."
    if exist "%tempFile%" del /f /q "%tempFile%"
    echo:
    pause
    goto menu
)

echo:
call :PrintYellow "Файл hosts требует обновления."
echo.

set "user_choice=N"
set /p "user_choice=Хотите обновить файл hosts автоматически? (Y/N) [по умолчанию N]: "

if /i "%user_choice%" neq "y" (
    goto hosts_interactive
)

echo Обновление файла hosts...

:: Снимаем защиту от записи и системные атрибуты
attrib -r -s -h "%hostsFile%" >nul 2>&1

:: Попытка А: Прямая автоматическая перезапись
powershell -NoProfile -Command "[System.IO.File]::WriteAllText('%hostsFile%', [System.IO.File]::ReadAllText('%tempFile%'))" >nul 2>&1

:: Проверка Попытки А
findstr /C:"%firstLine%" "%hostsFile%" >nul 2>&1
if errorlevel 1 (
    goto hosts_interactive
) else (
    call :PrintGreen "Файл hosts успешно обновлен автоматически!"
    goto hosts_done
)

:hosts_interactive
cls
call :PrintYellow "[ИНФО] Автоматическая запись ограничена защитой Windows."
call :PrintYellow "Переходим в безопасный ручной режим..."
echo __________________________________________________________________
echo:
call :PrintRed "  ВАЖНО: Если у вас установлен Касперский или другой антивирус,"
call :PrintRed "  он может заблокировать Блокнот или выдать ошибку прав доступа!"
call :PrintYellow "  В таком случае ВРЕМЕННО ПРИОСТАНОВИТЕ АНТИВИРУС на 1 минуту."
echo __________________________________________________________________
echo:
call :PrintGreen " Шаг 1: Обновленный список хостов УЖЕ СКОПИРОВАН в буфер обмена."
echo  Шаг 2: Сейчас откроется оригинальный файл hosts в Блокноте.
echo  Шаг 3: Выделите ВСЁ (Ctrl + A), удалите старый текст и нажмите Ctrl + V.
echo  Шаг 4: Сохраните изменения (Ctrl + S) и закройте Блокнот.
echo __________________________________________________________________
echo:
echo Нажмите любую клавишу, чтобы открыть Блокнот и применить хосты...
pause >nul

:: Безопасное копирование в буфер обмена без парсинга кавычек
powershell -NoProfile -Command "Get-Content -LiteralPath '%tempFile%' | Set-Clipboard" >nul 2>&1

:: Прямой запуск Блокнота от имени Администратора
powershell -NoProfile -Command "Start-Process notepad.exe -ArgumentList '%hostsFile%' -Verb RunAs" >nul 2>&1

echo:
call :PrintYellow "Ожидаю, пока вы сохраните файл и вернетесь в это окно..."
echo После того как закроете Блокнот, нажмите здесь любую клавишу для проверки.
pause >nul

:: Финальная проверка того, что сделал пользователь
findstr /C:"%firstLine%" "%hostsFile%" >nul 2>&1
if errorlevel 1 (
    call :PrintRed "[ВНИМАНИЕ] Изменения не зафиксированы."
    call :PrintYellow "Возможно, вы забыли сохранить файл (Ctrl+S) или Касперский заблокировал Блокнот."
    call :PrintYellow "Попробуйте приостановить защиту антивируса и повторить операцию."
) else (
    call :PrintGreen "Файл hosts успешно обновлен ручным методом!"
)

:hosts_done
if exist "%tempFile%" del /f /q "%tempFile%"
echo:
pause
goto menu
:: Вспомогательные функции
:PrintGreen
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Green"
exit /b

:PrintRed
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Red"
exit /b

:PrintYellow
powershell -NoProfile -Command "Write-Host \"%~1\" -ForegroundColor Yellow"
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo [ОШИБКА] %1 не найден в PATH.
    echo Исправьте переменную PATH согласно инструкции: https://github.com/Flowseal/zapret-discord-youtube/issues/7490
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"
if not exist "%~dp0bin\" set "extracted=0"
if "%extracted%"=="0" (
    echo Zapret должен быть распакован из архива. Папка bin не найдена.
    pause
    exit
)
exit /b 0