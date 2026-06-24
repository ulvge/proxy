@echo off
setlocal EnableExtensions EnableDelayedExpansion

chcp 936 >nul 2>&1
cd /d "%~dp0"

rem =========================
rem 管理员判断
rem =========================
net session >nul 2>&1 && goto :after_elevate
if /i "%~1"=="ELEVATED" goto :after_elevate

rem =========================
rem 提权（VBS优先 + PS兜底）+ FLAG 防闪退
rem =========================
set "FLAG=%temp%\quick_elev_%random%%random%.flag"
> "%FLAG%" echo 1

call :TryElevateWithVBS "%FLAG%"
call :WaitFlagGone "%FLAG%" && exit /b

call :TryElevateWithPS "%FLAG%"
call :WaitFlagGone "%FLAG%" && exit /b

echo.
echo [提示] 无法自动提权（可能被系统策略/安全软件限制）。
echo 如需管理员权限，请右键脚本选择“以管理员身份运行”。
echo.
goto :after_elevate


:after_elevate
if not "%~2"=="" (
  del /f /q "%~2" >nul 2>&1
)

rem =========================
rem 关键路径自检
rem =========================
if not exist "%~dp0Quick" (
  echo [错误] 未找到目录：%~dp0Quick
  echo 请完整解压到本地磁盘，不要在压缩包内直接运行。
  echo.
  pause
  exit /b
)

if not exist "%~dp0Quick\quick.exe" (
  echo [错误] 未找到：%~dp0Quick\quick.exe
  echo 可能被安全软件隔离，请检查隔离区并加入排除项。
  echo.
  pause
  exit /b
)

title Quick 一键启动

echo 是否执行IP更新？IP更新从云端更新IP配置以解决封锁问题！
echo 按 5 跳过；按 1~4 选择对应 ip 更新。若更新后都用不了，请发邮件到 rebeccalane27@gmail.com 反馈！
echo.

choice /C 12345 /T 15 /D 5 /M "1、ip1更新  2、ip2更新  3、ip3更新  4、ip4更新  5、跳过"
if errorlevel 5 goto startfq
if errorlevel 4 goto ip4
if errorlevel 3 goto ip3
if errorlevel 2 goto ip2
if errorlevel 1 goto ip1


:ip4
start /wait "" "%~dp0Quick\ip_Update\ip_4.bat"
goto startfq

:ip3
start /wait "" "%~dp0Quick\ip_Update\ip_3.bat"
goto startfq

:ip2
start /wait "" "%~dp0Quick\ip_Update\ip_2.bat"
goto startfq

:ip1
start /wait "" "%~dp0Quick\ip_Update\ip_1.bat"
goto startfq


:startfq
echo 等待 Quick 启动，请稍候...

echo 检测config
if exist "%~dp0Quick\config.yaml" (
	echo 修改 config
    powershell -Command "(Get-Content '%~dp0Quick\config.yaml' -Encoding UTF8) -replace 'allow-lan: false', 'allow-lan: true' | Set-Content '%~dp0Quick\config.yaml' -Encoding UTF8"
)
rem 防止重复启动
tasklist /FI "IMAGENAME eq quick.exe" 2>nul | find /I "quick.exe" >nul
if not errorlevel 1 (
  echo Quick 已在运行，跳过重复启动。
) else (
  start "" /D "%~dp0Quick" "%~dp0Quick\quick.exe" -d "%~dp0Quick"
)

echo 等待SSR启动，请稍候...
IF EXIST "C:\Program Files\Qoom Chrome\chrome.exe" (
    start "" "C:\Program Files\Qoom Chrome\chrome.exe" --proxy-server="127.0.0.1:7890"
)

echo.
echo 完成。按空格或回车键退出。
pause
exit /b


rem ==================================================
rem VBS 提权
rem ==================================================
:TryElevateWithVBS
set "FLAGFILE=%~1"
where wscript.exe >nul 2>&1 || goto :eof

set "VBSTMP=%temp%\quick_elev_%random%%random%.vbs"
> "%VBSTMP%"  echo Set UAC = CreateObject("Shell.Application")
>>"%VBSTMP%" echo cmd = "%ComSpec%"
>>"%VBSTMP%" echo args = "/c " ^& Chr(34) ^& Chr(34) ^& "%~f0" ^& Chr(34) ^& " ELEVATED " ^& Chr(34) ^& "%FLAGFILE%" ^& Chr(34) ^& Chr(34)
>>"%VBSTMP%" echo UAC.ShellExecute cmd, args, "%~dp0", "runas", 1

wscript.exe "%VBSTMP%" >nul 2>&1
del /f /q "%VBSTMP%" >nul 2>&1
goto :eof


rem ==================================================
rem PowerShell 提权兜底
rem ==================================================
:TryElevateWithPS
set "FLAGFILE=%~1"
where powershell >nul 2>&1 || goto :eof

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try{Start-Process -FilePath $env:ComSpec -ArgumentList '/c','\"\"%~f0\"\"','ELEVATED','\"\"%FLAGFILE%\"\"' -Verb RunAs | Out-Null}catch{}" ^
 >nul 2>&1
goto :eof


rem ==================================================
rem 快速等待 FLAG 被删除（≤250ms）
rem ==================================================
:WaitFlagGone
set "FLAGFILE=%~1"
set /a i=0
:wg_loop
if not exist "%FLAGFILE%" exit /b 0
set /a i+=1
if !i! GEQ 5 exit /b 1
ping 127.0.0.1 -n 1 -w 50 >nul
goto wg_loop
