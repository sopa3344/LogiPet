@echo off
setlocal
set "LOGIPET_EXE=%~dp0dist\LogiPet\LogiPet.exe"

if exist "%LOGIPET_EXE%" (
  start "" "%LOGIPET_EXE%"
  exit /b 0
)

echo.
echo [LogiPet] 실행용 파일을 찾을 수 없습니다.
echo 이 ZIP은 GitHub의 소스 코드이며 설치용 배포본이 아닙니다.
echo Releases 페이지에서 LogiPet-Windows.zip을 받아 주세요.
echo.
start "" "https://github.com/sopa3344/LogiPet/releases/latest"
pause
exit /b 1
