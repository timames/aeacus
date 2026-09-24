#Requires -RunAsAdministrator
# =============================================================================
# HBA CyberEagles Bootcamp - Day 3 Windows Server 2022 - Vulnerability Planting
#
# Run this on a clean Windows Server 2022 VM as Administrator BEFORE aeacus release.
# It plants all the vulnerabilities that scoring.conf checks for.
#
# PREREQUISITES:
#   - DNS Server role must already be installed and running (it's a required service).
#   - The built-in Administrator account is the primary user for this image.
#
# MANUAL STEPS STILL REQUIRED AFTER THIS SCRIPT:
#   1. Install Wireshark (download from wireshark.org)
#   2. Wait for IIS and SMBv1 feature installs to finish (may need a reboot)
#   3. Verify password policy defaults in secpol.msc are insecure
#   4. Copy scoring.conf to C:\aeacus\scoring.conf
#   5. Copy HintLadder.ps1 to C:\aeacus\HintLadder.ps1 and create Desktop shortcut
#   6. Copy ReadMe.conf to C:\aeacus\ReadMe.conf (edit the template first!)
#   7. Run: C:\aeacus\aeacus.exe --verbose check  (verify all vulns score 0)
#   8. Run: C:\aeacus\aeacus.exe --verbose release
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=== HBA Day 3 Windows Server 2022 - Planting Vulnerabilities ===" -ForegroundColor Yellow
Write-Host ""

# -------------------------------------------------------
# FORENSICS QUESTIONS
# -------------------------------------------------------
Write-Host "[1/14] Creating forensics question files on Desktop..." -ForegroundColor Cyan
$desktop = "C:\Users\Administrator\Desktop"
if (-not (Test-Path $desktop)) {
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null
}

@"
An unauthorized web server is running on this machine. What TCP port
does it listen on?

ANSWER:
"@ | Set-Content "$desktop\Forensics Question 1.txt" -Encoding UTF8

@"
One user account on this machine does not belong to any authorized
user in the README. What is its username?

ANSWER:
"@ | Set-Content "$desktop\Forensics Question 2.txt" -Encoding UTF8

# -------------------------------------------------------
# ACCOUNT MANAGEMENT
# -------------------------------------------------------
Write-Host "[2/14] Creating unauthorized user 'backdoor'..." -ForegroundColor Cyan
net user backdoor "P@ssw0rd" /add 2>$null
if ($LASTEXITCODE -ne 0) { Write-Warning "backdoor may already exist" }

Write-Host "[3/14] Creating authorized user 'jdoe' and adding to Administrators..." -ForegroundColor Cyan
net user jdoe "Str0ngP@ss!" /add 2>$null
net localgroup Administrators jdoe /add 2>$null

Write-Host "[4/14] Activating Guest account..." -ForegroundColor Cyan
net user Guest /active:yes 2>$null

Write-Host "[5/14] Creating authorized user 'mkealoha' with password-never-expires..." -ForegroundColor Cyan
net user mkealoha "Aloha2026!" /add 2>$null
try {
    $user = [ADSI]"WinNT://$env:COMPUTERNAME/mkealoha,user"
    $flags = $user.UserFlags.Value
    $ADS_UF_DONT_EXPIRE_PASSWD = 0x10000
    $user.UserFlags.Value = $flags -bor $ADS_UF_DONT_EXPIRE_PASSWD
    $user.SetInfo()
} catch {
    Write-Warning "Could not set password-never-expires via ADSI. Set it manually in lusrmgr.msc."
}

Write-Host "[6/15] Creating authorized user 'bkahale' with weak password 'password'..." -ForegroundColor Cyan
net user bkahale "password" /add 2>$null
if ($LASTEXITCODE -ne 0) { Write-Warning "bkahale may already exist" }

# -------------------------------------------------------
# SYSTEM HARDENING - RDP
# -------------------------------------------------------
Write-Host "[7/15] Enabling Remote Desktop..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Type DWord

# -------------------------------------------------------
# SYSTEM HARDENING - Remote Registry
# -------------------------------------------------------
Write-Host "[8/15] Setting Remote Registry to Automatic and starting it..." -ForegroundColor Cyan
Set-Service -Name RemoteRegistry -StartupType Automatic
Start-Service -Name RemoteRegistry -ErrorAction SilentlyContinue

# -------------------------------------------------------
# SYSTEM HARDENING - UAC
# -------------------------------------------------------
Write-Host "[9/15] Disabling UAC..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord

# -------------------------------------------------------
# SYSTEM HARDENING - IIS (Forensics Q1 evidence)
# -------------------------------------------------------
Write-Host "[10/15] Installing IIS Web Server (this is the Forensics Q1 evidence)..." -ForegroundColor Cyan
Install-WindowsFeature Web-Server -IncludeManagementTools -ErrorAction SilentlyContinue | Out-Null
Write-Host "  IIS installed. Default site listening on port 80." -ForegroundColor DarkGray

# -------------------------------------------------------
# SYSTEM HARDENING - SMBv1
# -------------------------------------------------------
Write-Host "[11/15] Enabling SMBv1..." -ForegroundColor Cyan
Install-WindowsFeature FS-SMB1 -ErrorAction SilentlyContinue | Out-Null

# -------------------------------------------------------
# SYSTEM HARDENING - Unauthorized share
# -------------------------------------------------------
Write-Host "[12/15] Creating unauthorized share 'Secrets'..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "C:\Secrets" -Force | Out-Null
"This is a secret file." | Set-Content "C:\Secrets\secret.txt"
net share Secrets="C:\Secrets" /grant:everyone,FULL 2>$null

# -------------------------------------------------------
# SYSTEM HARDENING - Firewall
# -------------------------------------------------------
Write-Host "[13/15] Disabling Windows Firewall on all profiles..." -ForegroundColor Cyan
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# -------------------------------------------------------
# PROHIBITED FILES - Media file
# -------------------------------------------------------
Write-Host "[14/15] Planting media file..." -ForegroundColor Cyan
$musicDir = "C:\Users\Administrator\Music"
New-Item -ItemType Directory -Path $musicDir -Force | Out-Null
[byte[]]$fakemp3 = 0xFF, 0xFB, 0x90, 0x00
[System.IO.File]::WriteAllBytes("$musicDir\lahaina_remix.mp3", $fakemp3)

# -------------------------------------------------------
# AEACUS SETUP
# -------------------------------------------------------
Write-Host "[15/15] Creating C:\aeacus directory structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "C:\aeacus" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\aeacus\assets" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\aeacus\assets\img" -Force | Out-Null

# Hint Ladder shortcut
$shortcutPath = "$desktop\Hint Ladder.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-ExecutionPolicy Bypass -File C:\aeacus\HintLadder.ps1"
$shortcut.WorkingDirectory = "C:\aeacus"
$shortcut.Description = "HBA CyberEagles Hint Ladder"
$shortcut.Save()

# -------------------------------------------------------
# SUMMARY
# -------------------------------------------------------
Write-Host ""
Write-Host "Done planting vulnerabilities!" -ForegroundColor Green
Write-Host ""
Write-Host "=== VERIFY BEFORE CONTINUING ===" -ForegroundColor Yellow
Write-Host "  - DNS Server role is installed and running (required service, -5 penalty if stopped)" -ForegroundColor White
Write-Host "  - IIS is running: open http://localhost in a browser to confirm" -ForegroundColor White
Write-Host ""
Write-Host "=== MANUAL STEPS REMAINING ===" -ForegroundColor Yellow
Write-Host "  1. Install Wireshark:  download from wireshark.org" -ForegroundColor White
Write-Host "  2. Reboot (needed for SMBv1 and UAC changes)" -ForegroundColor White
Write-Host "  3. Download aeacus release from GitHub and extract to C:\aeacus\" -ForegroundColor White
Write-Host "  4. Copy scoring.conf -> C:\aeacus\scoring.conf" -ForegroundColor White
Write-Host "  5. Copy HintLadder.ps1 -> C:\aeacus\HintLadder.ps1" -ForegroundColor White
Write-Host "  6. Copy ReadMe.conf -> C:\aeacus\ReadMe.conf (edit template first!)" -ForegroundColor White
Write-Host "  7. Copy logo.png + logo.ico -> C:\aeacus\assets\img\" -ForegroundColor White
Write-Host "  8. Run:  C:\aeacus\aeacus.exe --verbose check" -ForegroundColor White
Write-Host "  9. Run:  (Get-LocalUser bkahale).PasswordLastSet" -ForegroundColor White
Write-Host "     Paste that value into scoring.conf (the 'after' field for bkahale)" -ForegroundColor DarkGray
Write-Host " 10. Verify scoring report shows 0/100, then:" -ForegroundColor White
Write-Host "     Run:  C:\aeacus\aeacus.exe --verbose release" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: The 'Rename Administrator' check expects the account renamed to 'CyberAdmin'" -ForegroundColor Yellow
Write-Host "in secpol.msc. Do NOT rename it yourself -- that's a vuln for students to find." -ForegroundColor Yellow
