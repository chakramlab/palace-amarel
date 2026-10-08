@echo off
rem Is the Rutgers VPN up? amarel.rutgers.edu only resolves through the VPN's DNS.
nslookup amarel.rutgers.edu >nul 2>&1
if %errorlevel%==0 (
  echo VPN is UP: amarel.rutgers.edu resolves.
  ssh -o BatchMode=yes -o ConnectTimeout=10 amarel "echo logged in as $USER on $(hostname)" 2>nul || echo (ssh with the amarel alias failed: run 01_setup_ssh.ps1 first, or your key is not installed yet)
) else (
  echo VPN is DOWN or not connected: amarel.rutgers.edu does not resolve. Connect the Rutgers VPN and retry.
)
pause
