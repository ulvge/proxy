@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem 尽量避免乱码；失败也不影响运行
chcp 936 >nul 2>&1

cd /d "%~dp0"

rem =========================
rem  管理员判断（最稳）
rem =========================
net session >nul 2>&1 && goto :after_elevate

rem 如果已经带 ELEVATED 参数，认为是管理员二次启动
if /i "%~1"=="ELEVATED" goto :after_elevate

rem =========================
rem  提权（mshta + 短路径）+ FLAG确认，避免“假成功闪退”
rem =========================
set "FLAG=%temp%\clashmeta_elev_%random%%random%.flag"
> "%FLAG%" echo 1

where mshta.exe >nul 2>&1
if not errorlevel 1 (
  rem 用短路径 %~s0，提高兼容性（类似你的老版本）
  mshta "vbscript:CreateObject(""Shell.Application"").ShellExecute(""cmd.exe"",""/c """"%~s0"""" ELEVATED """"%FLAG"""" "","""",""runas"",1)(close)"
)

rem 等待管理员实例启动并删除FLAG（约1秒）
ping 127.0.0.1 -n 1 -w 200 >nul

rem 如果 FLAG 被删，说明管理员实例已成功启动 → 普通窗口退出避免双开
if not exist "%FLAG%" exit /b

rem FLAG 还在：说明提权失败/用户点否/被策略拦截 → 继续用普通权限执行（不闪退）
goto :after_elevate


:after_elevate
rem 关键路径自检，防止压缩包内运行或被防护软件隔离
if not exist "%~dp0Quick" (
  echo [错误] 未找到目录：%~dp0Quick
  echo 请先完整解压到本地磁盘，不要在压缩包内直接运行。
  pause
  exit /b
)
if not exist "%~dp0Quick\quick.exe" (
  echo [错误] 未找到：%~dp0Quick\quick.exe
  echo 可能被安全软件隔离/删除，请检查防毒软件的隔离/历史并加入排除项。
  pause
  exit /b
)

rem -------------------------

title Quick 一键启动

echo 是否执行IP更新？IP更新从云端更新IP配置以解决封锁问题！
echo 按5跳过，按1选择ip1更新，若ip1不好用再按2选ip2更新，如果更新后都用不了，请发邮件到rebeccalane27@gmail.com进行反馈！
choice /C 12345 /T 15 /D 5 /M "1、ip1更新  2、ip2更新  3、ip3更新  4、ip4更新 5、跳过"
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
start "" /D "%~dp0Quick" "%~dp0Quick\quick.exe" -d "%~dp0Quick"
if exist "%~dp0App\chrome.exe" (
  start "" /D "%~dp0App" "%~dp0App\chrome.exe" --proxy-server=127.0.0.1:7890
)
echo 完成。按空格或回车键退出。
pause

