@echo off
setlocal

where cl >nul 2>nul
if errorlevel 1 (
  echo [ERRO] cl.exe nao encontrado. Abra "x64 Native Tools Command Prompt for VS".
  exit /b 1
)

set OUTDIR=%~dp0out
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

cl /nologo /LD /O2 /EHsc /std:c++17 ^
  /Fe"%OUTDIR%\\CSM_Bus.dll" ^
  "%~dp0CSM_Bus.cpp" ^
  /link /NOLOGO

if errorlevel 1 exit /b 1

echo [OK] DLL gerada: %OUTDIR%\CSM_Bus.dll
echo Copie para: %%APPDATA%%\MetaQuotes\Terminal\...\MQL5\Libraries\CSM_Bus.dll
endlocal
