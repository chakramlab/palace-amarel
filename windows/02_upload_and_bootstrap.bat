@echo off
rem Copy this repo to /scratch/$USER/GitHub/palace-amarel on Amarel and start phase A (spack
rem bootstrap) detached on the login node. Watch its log with 04_status.bat.
setlocal
set REPO=%~dp0..
for %%I in ("%REPO%") do set REPO=%%~fI
echo Uploading %REPO% to amarel:/scratch/$USER/GitHub/palace-amarel ...
ssh amarel "mkdir -p /scratch/$USER/GitHub /scratch/$USER/logs" || goto :fail
scp -r -q "%REPO%" amarel:/scratch/$USER/GitHub/ || goto :fail
ssh amarel "cd /scratch/$USER/GitHub/palace-amarel && chmod +x cluster/*.sh tests/*.sh && nohup bash cluster/spack_bootstrap.sh > /scratch/$USER/logs/spack_bootstrap.log 2>&1 < /dev/null & disown; echo started" || goto :fail
echo Phase A started on the login node (about 10 minutes). Log: /scratch/$USER/logs/spack_bootstrap.log
echo When it says "bootstrap done", run 03_submit_build.bat
pause
exit /b 0
:fail
echo Something failed. Is the VPN up (00_check_vpn.bat)? Does "ssh amarel hostname" work?
pause
exit /b 1
