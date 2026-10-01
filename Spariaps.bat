@echo off
rem Avvia Spariaps su Windows: apre index.html in una finestra dedicata di Chrome o Edge
rem (profilo separato, cosi' la musica parte subito e il tasto ESCI del gioco chiude la finestra).
setlocal
set "GAME=%~dp0index.html"
if not exist "%GAME%" (
  echo Non trovo index.html. Tieni Spariaps.bat nella cartella del gioco.
  pause
  exit /b 1
)

rem file:///C:/percorso/index.html con gli spazi codificati
set "URL=%GAME:\=/%"
setlocal EnableDelayedExpansion
set "URL=file:///!URL: =%%20!"
endlocal & set "URL=%URL%"

set "BROWSER="
for %%P in (
  "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
  "%LocalAppData%\Google\Chrome\Application\chrome.exe"
  "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
  "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
) do if not defined BROWSER if exist "%%~P" set "BROWSER=%%~P"

if not defined BROWSER (
  rem nessun Chrome/Edge: apre il gioco nel browser predefinito
  start "" "%GAME%"
  exit /b 0
)

set "PROFILE=%LocalAppData%\Spariaps\Browser"
if not exist "%PROFILE%" mkdir "%PROFILE%"
start "" "%BROWSER%" --user-data-dir="%PROFILE%" --autoplay-policy=no-user-gesture-required --no-first-run --no-default-browser-check --app="%URL%"
exit /b 0
