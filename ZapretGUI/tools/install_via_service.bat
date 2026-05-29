@echo off
setlocal EnableDelayedExpansion

:: Параметры
set "FULL_BAT_PATH=%~1"
set "GameFilter=%~2"
set "BIN_PATH=%~3\"
set "LISTS_PATH=%~4\"
set "SRVCNAME=zapret"

if not exist "%FULL_BAT_PATH%" exit /b 1

:: Аргументы, за которыми должно следовать значение
set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "usebackq tokens=*" %%a in ("%FULL_BAT_PATH%") do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "winws.exe" >nul
    if not errorlevel 1 set "capture=1"

    if !capture!==1 (
        if not defined args set "line=!line:*winws.exe"=!"
        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 set "mergeargs=0"

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"
                    if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
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
                    for %%x in (!args_with_value!) do if /i "%%x"=="!arg!" set "mergeargs=3"
                )
            )
        )
        if defined temp_args set "args=!args! !temp_args!"
    )
)

set "ARGS=%args%"
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"

:: Включение TCP timestamps
netsh interface tcp set global timestamps=enabled >nul 2>&1

:: Удаляем старую службу, если есть
sc stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1

:: Создаём службу. Правильный синтаксис: binPath= "путь с аргументами"
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" %ARGS%" DisplayName= "zapret" start= auto

:: Если предыдущая команда вернула ошибку (из-за кавычек), попробуем без лишних кавычек
if errorlevel 1 (
    sc create %SRVCNAME% binPath= "%BIN_PATH%winws.exe %ARGS%" DisplayName= "zapret" start= auto
)

sc description %SRVCNAME% "Zapret DPI bypass software"
sc start %SRVCNAME%

for %%F in ("%FULL_BAT_PATH%") do set "filename=%%~nF"
reg add "HKLM\System\CurrentControlSet\Services\%SRVCNAME%" /v zapret-discord-youtube /t REG_SZ /d "!filename!" /f

exit /b 0
