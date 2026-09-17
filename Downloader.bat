@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

set "SCRIPT_DIR=%~dp0"
set "FFMPEG_DIR="

REM =========================================================
REM ПОИСК FFMPEG
REM =========================================================

for /d %%F in ("%SCRIPT_DIR%ffmpeg*") do (
    if exist "%%F\bin\ffmpeg.exe" (
        if exist "%%F\bin\ffprobe.exe" (
            set "FFMPEG_DIR=%%F\bin"
            goto FFMPEG_FOUND
        )
    )
)

:FFMPEG_FOUND

if not defined FFMPEG_DIR (
    echo.
    echo [ОШИБКА] FFmpeg не найден!
    echo.
    echo Рядом с installer.bat должна находиться папка:
    echo ffmpeg*
    echo.
    echo Внутри:
    echo bin\ffmpeg.exe
    echo bin\ffprobe.exe
    echo.
    pause
    exit /b 1
)

REM =========================================================
REM ВЫБОР БРАУЗЕРА
REM =========================================================

:select_browser

cls

echo ========================================
echo          SOUNDCloud DOWNLOADER
echo ========================================
echo.
echo 1. Chrome
echo 2. Yandex
echo 3. Edge
echo 4. Firefox
echo 5. Opera
echo 6. Без cookies
echo.

set "b_choice="
set /p "b_choice=Выбери браузер (1-6): "

if "%b_choice%"=="1" (
    set "BROWSER=chrome"
    goto select_format
)

if "%b_choice%"=="2" (
    set "BROWSER=yandex"
    goto select_format
)

if "%b_choice%"=="3" (
    set "BROWSER=edge"
    goto select_format
)

if "%b_choice%"=="4" (
    set "BROWSER=firefox"
    goto select_format
)

if "%b_choice%"=="5" (
    set "BROWSER=opera"
    goto select_format
)

if "%b_choice%"=="6" (
    set "BROWSER=none"
    goto select_format
)

goto select_browser


REM =========================================================
REM ВЫБОР ФОРМАТА
REM =========================================================

:select_format

cls

echo ========================================
echo             ФОРМАТ АУДИО
echo ========================================
echo.
echo 1. MP3
echo 2. M4A
echo.

set "f_choice="
set /p "f_choice=Выбери формат (1-2): "

if "%f_choice%"=="1" (
    set "AUDIO_FMT=mp3"
    goto init
)

if "%f_choice%"=="2" (
    set "AUDIO_FMT=m4a"
    goto init
)

goto select_format


REM =========================================================
REM ИНИЦИАЛИЗАЦИЯ
REM =========================================================

:init

cls

echo ========================================
echo             ИНИЦИАЛИЗАЦИЯ
echo ========================================
echo.
echo [i] Папка скрипта:
echo %SCRIPT_DIR%
echo.
echo [i] FFmpeg:
echo %FFMPEG_DIR%
echo.

REM =========================================================
REM YT-DLP
REM =========================================================

if not exist "yt-dlp.exe" (
    echo [!] yt-dlp.exe не найден.
    echo [!] Загружаю последнюю версию...
    echo.

    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' -OutFile 'yt-dlp.exe'"

    if not exist "yt-dlp.exe" (
        echo.
        echo [ОШИБКА] Не удалось скачать yt-dlp.exe
        pause
        exit /b 1
    )
) else (
    echo [!] Проверяю обновление yt-dlp...
    yt-dlp.exe -U
)

echo.
echo [+] Инициализация завершена.
echo.


REM =========================================================
REM ОСНОВНОЙ ЦИКЛ
REM =========================================================

:loop

cls

echo ========================================
echo          SOUNDCloud DOWNLOADER
echo ========================================
echo.
echo [i] Браузер: %BROWSER%
echo [i] Формат:  %AUDIO_FMT%
echo [i] FFmpeg:  %FFMPEG_DIR%
echo.
echo [i] Одна обложка на плейлист: cover.jpg
echo [i] JPG отдельных треков не скачиваются
echo.

set "url="
set /p "url=Вставь ссылку на трек или плейлист: "

if "%url%"=="" goto loop

set "url=%url:"=%"

echo.
echo ========================================
echo             СКАЧИВАНИЕ
echo ========================================
echo.


REM =========================================================
REM СКАЧИВАНИЕ С COOKIES
REM =========================================================

if "%BROWSER%"=="none" goto DOWNLOAD_NO_COOKIES

echo [!] Пробую скачать с cookies от %BROWSER%...
echo.

yt-dlp.exe ^
--download-archive archive.txt ^
-f "bestaudio[abr=192]/bestaudio[abr=128]/bestaudio" ^
-x ^
--audio-format "%AUDIO_FMT%" ^
--audio-quality 0 ^
--add-metadata ^
--yes-playlist ^
--windows-filenames ^
--cookies-from-browser "%BROWSER%" ^
--ffmpeg-location "%FFMPEG_DIR%" ^
-o "%%(uploader,artist)s/%%(playlist_title,playlist)s/%%(title)s.%%(ext)s"
"%url%"

if %ERRORLEVEL% EQU 0 goto DOWNLOAD_DONE

echo.
echo [!] Не удалось скачать с cookies.
echo [!] Пробую без cookies...
echo.


REM =========================================================
REM СКАЧИВАНИЕ БЕЗ COOKIES
REM =========================================================

:DOWNLOAD_NO_COOKIES

echo [!] Скачивание без cookies...
echo.

yt-dlp.exe ^
--download-archive archive.txt ^
-f "bestaudio[abr=192]/bestaudio[abr=128]/bestaudio" ^
-x ^
--audio-format "%AUDIO_FMT%" ^
--audio-quality 0 ^
--add-metadata ^
--yes-playlist ^
--windows-filenames ^
--ffmpeg-location "%FFMPEG_DIR%" ^
-o "%%(uploader,artist)s/%%(playlist_title,playlist)s/%%(title)s.%%(ext)s"
"%url%"


:DOWNLOAD_DONE

echo.
echo ========================================
echo        ПОЛУЧЕНИЕ ОБЛОЖКИ
echo ========================================
echo.

REM =========================================================
REM ПЕРЕДАЁМ ДАННЫЕ В POWERSHELL ЧЕРЕЗ ENV
REM =========================================================

set "SC_URL=%url%"
set "SC_BROWSER=%BROWSER%"
set "SC_SCRIPT_DIR=%SCRIPT_DIR%"
set "SC_FFMPEG_DIR=%FFMPEG_DIR%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$args=@('--dump-single-json','--flat-playlist','--skip-download','--no-warnings','--quiet'); if($env:SC_BROWSER -ne 'none'){$args+=@('--cookies-from-browser',$env:SC_BROWSER)}; $args+=$env:SC_URL; $json=(& (Join-Path $env:SC_SCRIPT_DIR 'yt-dlp.exe') @args) -join [Environment]::NewLine; $j=$null; try{$j=ConvertFrom-Json -InputObject $json}catch{}; if($null -eq $j -and $env:SC_BROWSER -ne 'none'){$args=@('--dump-single-json','--flat-playlist','--skip-download','--no-warnings','--quiet',$env:SC_URL); $json=(& (Join-Path $env:SC_SCRIPT_DIR 'yt-dlp.exe') @args) -join [Environment]::NewLine; try{$j=ConvertFrom-Json -InputObject $json}catch{}}; if($null -eq $j){Write-Host '[!] Не удалось получить данные SoundCloud.';exit 1}; $title=$j.title; $best=$null; if($j.thumbnails){foreach($t in $j.thumbnails){if($t.id -eq 'original'){$best=$t;break};if($null -eq $best -or [int]$t.width -gt [int]$best.width){$best=$t}}}; $thumb=$null;if($null -ne $best){$thumb=$best.url};if([string]::IsNullOrWhiteSpace($thumb) -and $j.thumbnail){$thumb=$j.thumbnail};if([string]::IsNullOrWhiteSpace($thumb)){Write-Host '[!] Обложка не найдена.';exit 1};$safe=$title;foreach($c in [IO.Path]::GetInvalidFileNameChars()){$safe=$safe.Replace([string]$c,'_')};$safe=$safe.TrimEnd(' ','.');if($j._type -eq 'playlist' -or $null -ne $j.entries){$dir=Join-Path $env:SC_SCRIPT_DIR $safe}else{$dir=$env:SC_SCRIPT_DIR};New-Item -ItemType Directory -Force -Path $dir | Out-Null;$src=Join-Path $env:TEMP ('sc_cover_'+[guid]::NewGuid().ToString()+'.img');try{Invoke-WebRequest -Uri $thumb -OutFile $src -UseBasicParsing;& (Join-Path $env:SC_FFMPEG_DIR 'ffmpeg.exe') -y -i $src -frames:v 1 -q:v 2 (Join-Path $dir 'cover.jpg') | Out-Null}catch{Write-Host '[!] Ошибка при создании cover.jpg.';Remove-Item $src -Force -ErrorAction SilentlyContinue;exit 1};Remove-Item $src -Force -ErrorAction SilentlyContinue;if(Test-Path (Join-Path $dir 'cover.jpg')){Write-Host '[+] Обложка сохранена:';Write-Host (Join-Path $dir 'cover.jpg')}else{Write-Host '[!] cover.jpg не создан.';exit 1}"


echo.
echo ========================================
echo                    ГОТОВО
echo ========================================
echo.
echo [+] Треки обработаны.
echo [+] Отдельные JPG не создавались.
echo [+] Обложка: cover.jpg
echo.


REM =========================================================
REM ЕЩЁ?
REM =========================================================

set "choice="
set /p "choice=Скачать что-нибудь ещё? (Y/N): "

if /i "%choice%"=="Y" goto loop
if /i "%choice%"=="y" goto loop
echo.
echo ================================
echo       КРАШ-ЛОГ / ОШИБКА
echo ================================
echo ERRORLEVEL=%ERRORLEVEL%
pause
