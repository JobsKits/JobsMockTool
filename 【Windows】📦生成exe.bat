@echo off
rem Jobs: forward to the maintained Windows builder.
call "%~dp0build_windows.bat" %*
exit /b %ERRORLEVEL%
