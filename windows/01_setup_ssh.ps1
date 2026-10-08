# One-time SSH setup on a Windows laptop: key + `Host amarel` alias in ~/.ssh/config.
# Run in PowerShell:  powershell -ExecutionPolicy Bypass -File windows\01_setup_ssh.ps1
# This script never handles your password. It prints the one command (ssh-copy-id style) that you
# run yourself to install the public key on Amarel; that command asks for your NetID password once.
$ErrorActionPreference = "Stop"
$netid = Read-Host "Your Rutgers NetID (the Amarel username)"
if (-not $netid) { throw "NetID required" }
$sshDir = Join-Path $HOME ".ssh"
if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
$key = Join-Path $sshDir "id_ed25519_amarel"
if (-not (Test-Path $key)) {
  Write-Host "Generating an ed25519 key at $key (press Enter for no passphrase, or set one)"
  ssh-keygen -t ed25519 -f $key -C "$netid@amarel"
} else { Write-Host "Key already exists: $key" }
$cfg = Join-Path $sshDir "config"
$block = @"

Host amarel
  HostName amarel.rutgers.edu
  User $netid
  IdentityFile $key
  ServerAliveInterval 60
"@
if ((Test-Path $cfg) -and (Select-String -Path $cfg -Pattern "^Host amarel" -Quiet)) {
  Write-Host "~/.ssh/config already has a 'Host amarel' block; not changing it."
} else {
  Add-Content -Path $cfg -Value $block -Encoding ascii
  Write-Host "Added 'Host amarel' block to $cfg"
}
Write-Host ""
Write-Host "Now install the public key on Amarel (connect the VPN first). Run this yourself; it asks for your password once:"
Write-Host ""
Write-Host "  type `"$key.pub`" | ssh $netid@amarel.rutgers.edu `"mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`""
Write-Host ""
Write-Host "Then test:  ssh amarel hostname"
