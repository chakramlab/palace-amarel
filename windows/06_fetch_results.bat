@echo off
rem Fetch the smoke-test result tables (not the field files) to results\cylinder\ and check them.
rem Needs python with numpy on this laptop for the check; otherwise run the check on the cluster
rem (see README section 5).
setlocal
set REPO=%~dp0..
for %%I in ("%REPO%") do set REPO=%%~fI
if not exist "%REPO%\results\cylinder" mkdir "%REPO%\results\cylinder"
ssh amarel "cd /scratch/$USER/palace-tests/cylinder/postpro && tar czf - cavity_pec --exclude=paraview" | tar xzf - -C "%REPO%\results\cylinder" || goto :fail
echo Fetched to %REPO%\results\cylinder\cavity_pec
where python >nul 2>&1 && python "%REPO%\tests\check_cylinder.py" "%REPO%\results\cylinder\cavity_pec"
pause
exit /b 0
:fail
echo Fetch failed. Has the smoke-test job finished? (04_status.bat)
pause
exit /b 1
