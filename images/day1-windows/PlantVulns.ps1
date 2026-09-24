#Requires -RunAsAdministrator
# =============================================================================
# HBA CyberEagles Bootcamp - Day 1 Windows Image - Vulnerability Planting Script
#
# Run this on a clean Windows 11 VM as Administrator BEFORE running aeacus release.
# It plants all the vulnerabilities that scoring.conf checks for.
#
# MANUAL STEPS STILL REQUIRED AFTER THIS SCRIPT:
#   1. Install Wireshark (download from wireshark.org, or winget install WiresharkFoundation.Wireshark)
#   2. Enable SMBv1: Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol (requires reboot)
#   3. Verify password policy defaults in secpol.msc are insecure (they should be on a fresh install)
#   4. Copy scoring.conf to C:\aeacus\scoring.conf
#   5. Copy HintLadder.ps1 to C:\aeacus\HintLadder.ps1 and create Desktop shortcut
#   6. Copy ReadMe.conf to C:\aeacus\ReadMe.conf (edit the template first!)
#   7. Run: C:\aeacus\aeacus.exe --verbose check  (verify all vulns score 0 / all plants work)
#   8. Run: (Get-LocalUser bkahale).PasswordLastSet  and paste the value into scoring.conf
#   9. Run: C:\aeacus\aeacus.exe --verbose release
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=== HBA Day 1 Windows Image - Planting Vulnerabilities ===" -ForegroundColor Yellow
Write-Host ""

# -------------------------------------------------------
# FORENSICS QUESTIONS
# -------------------------------------------------------
Write-Host "[1/16] Creating forensics question files on Desktop..." -ForegroundColor Cyan
$desktop = "C:\Users\cpadmin\Desktop"
if (-not (Test-Path $desktop)) {
    Write-Warning "Desktop path $desktop does not exist. Is the user 'cpadmin' created?"
    Write-Warning "Create the cpadmin user first, log in as them once, then re-run this script."
    exit 1
}

@"
A backdoor listener was installed on this machine. What TCP port
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
Write-Host "[2/16] Creating unauthorized user 'hacker'..." -ForegroundColor Cyan
net user hacker "P@ssw0rd" /add 2>$null
if ($LASTEXITCODE -ne 0) { Write-Warning "hacker may already exist" }

Write-Host "[3/16] Creating authorized user 'jdoe' and adding to Administrators..." -ForegroundColor Cyan
net user jdoe "Str0ngP@ss!" /add 2>$null
net localgroup Administrators jdoe /add 2>$null

Write-Host "[4/16] Activating Guest account..." -ForegroundColor Cyan
net user Guest /active:yes 2>$null

Write-Host "[5/16] Creating authorized user 'mkealoha' with password-never-expires..." -ForegroundColor Cyan
net user mkealoha "Aloha2026!" /add 2>$null
# Set password never expires
$user = [ADSI]"WinNT://./$env:COMPUTERNAME/mkealoha,user"
try {
    $user = [ADSI]"WinNT://$env:COMPUTERNAME/mkealoha,user"
    $flags = $user.UserFlags.Value
    $ADS_UF_DONT_EXPIRE_PASSWD = 0x10000
    $user.UserFlags.Value = $flags -bor $ADS_UF_DONT_EXPIRE_PASSWD
    $user.SetInfo()
} catch {
    Write-Warning "Could not set password-never-expires via ADSI. Set it manually in lusrmgr.msc."
}

Write-Host "[6/16] Creating authorized user 'bkahale' with weak password 'password'..." -ForegroundColor Cyan
net user bkahale "password" /add 2>$null

# -------------------------------------------------------
# SYSTEM HARDENING - RDP
# -------------------------------------------------------
Write-Host "[7/16] Enabling Remote Desktop..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Type DWord

# -------------------------------------------------------
# SYSTEM HARDENING - Remote Registry
# -------------------------------------------------------
Write-Host "[8/16] Setting Remote Registry to Automatic and starting it..." -ForegroundColor Cyan
Set-Service -Name RemoteRegistry -StartupType Automatic
Start-Service -Name RemoteRegistry -ErrorAction SilentlyContinue

# -------------------------------------------------------
# SYSTEM HARDENING - UAC
# -------------------------------------------------------
Write-Host "[9/16] Disabling UAC..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord

# -------------------------------------------------------
# SYSTEM HARDENING - Unauthorized share
# -------------------------------------------------------
Write-Host "[10/16] Creating unauthorized share 'Secrets'..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "C:\Secrets" -Force | Out-Null
"This is a secret file." | Set-Content "C:\Secrets\secret.txt"
net share Secrets="C:\Secrets" /grant:everyone,FULL 2>$null

# -------------------------------------------------------
# PROHIBITED FILES - Backdoor binary + scheduled task
# -------------------------------------------------------
Write-Host "[11/16] Planting backdoor binary and scheduled task..." -ForegroundColor Cyan
# Create a dummy ncat.exe (just needs to exist for the PathExistsNot check).
# If you have a real ncat.exe from the nmap distribution, copy it instead
# for a more realistic forensics experience.
$ncatPath = "C:\Windows\Temp\ncat.exe"
if (-not (Test-Path $ncatPath)) {
    # Create a minimal valid PE file (just needs to exist; won't actually run as ncat)
    # For realism, download ncat from nmap.org and copy it here instead.
    "placeholder-for-ncat" | Set-Content $ncatPath -Encoding ASCII
    Write-Warning "Planted a placeholder at $ncatPath. For realism, replace with real ncat.exe from nmap.org."
}

# Create scheduled task "Updater" that would run ncat on port 4444 at logon
$action = New-ScheduledTaskAction -Execute $ncatPath -Argument "-l -p 4444 -e cmd.exe"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Updater" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null

# -------------------------------------------------------
# PROHIBITED FILES - Media file
# -------------------------------------------------------
Write-Host "[12/16] Planting media file..." -ForegroundColor Cyan
$musicDir = "C:\Users\cpadmin\Music"
New-Item -ItemType Directory -Path $musicDir -Force | Out-Null
# Create a tiny file with .mp3 extension (content doesn't matter for the check)
[byte[]]$fakemp3 = 0xFF, 0xFB, 0x90, 0x00  # MP3 sync header
[System.IO.File]::WriteAllBytes("$musicDir\lahaina_remix.mp3", $fakemp3)

# -------------------------------------------------------
# SYSTEM HARDENING - Firewall (disable for the vuln)
# -------------------------------------------------------
Write-Host "[13/16] Disabling Windows Firewall on all profiles..." -ForegroundColor Cyan
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# -------------------------------------------------------
# AEACUS SETUP
# -------------------------------------------------------
Write-Host "[14/16] Creating C:\aeacus directory structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "C:\aeacus" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\aeacus\assets" -Force | Out-Null
New-Item -ItemType Directory -Path "C:\aeacus\assets\img" -Force | Out-Null

# -------------------------------------------------------
# HINT LADDER SHORTCUT
# -------------------------------------------------------
Write-Host "[15/16] Creating Hint Ladder desktop shortcut..." -ForegroundColor Cyan
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
Write-Host "[16/16] Done planting vulnerabilities!" -ForegroundColor Green
Write-Host ""
Write-Host "=== MANUAL STEPS REMAINING ===" -ForegroundColor Yellow
Write-Host "  1. Install Wireshark:  winget install WiresharkFoundation.Wireshark" -ForegroundColor White
Write-Host "  2. Enable SMBv1:       Enable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol" -ForegroundColor White
Write-Host "     (This requires a reboot. Do it BEFORE the remaining steps.)" -ForegroundColor DarkGray
Write-Host "  3. Download aeacus release from GitHub and extract to C:\aeacus\" -ForegroundColor White
Write-Host "  4. Copy scoring.conf -> C:\aeacus\scoring.conf" -ForegroundColor White
Write-Host "  5. Copy HintLadder.ps1 -> C:\aeacus\HintLadder.ps1" -ForegroundColor White
Write-Host "  6. Copy ReadMe.conf -> C:\aeacus\ReadMe.conf (edit template first!)" -ForegroundColor White
Write-Host "  7. Copy logo.png + logo.ico -> C:\aeacus\assets\img\" -ForegroundColor White
Write-Host "  8. Replace ncat placeholder with real ncat.exe from nmap.org (optional)" -ForegroundColor White
Write-Host "  9. Run:  C:\aeacus\aeacus.exe --verbose check" -ForegroundColor White
Write-Host " 10. Run:  (Get-LocalUser bkahale).PasswordLastSet" -ForegroundColor White
Write-Host "     Paste that value into scoring.conf line 99 (the 'after' field)" -ForegroundColor DarkGray
Write-Host " 11. Run:  C:\aeacus\aeacus.exe --verbose readme" -ForegroundColor White
Write-Host " 12. Verify scoring report shows 0/100, then:" -ForegroundColor White
Write-Host "     Run:  C:\aeacus\aeacus.exe --verbose release" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: A reboot is needed after enabling SMBv1 and disabling UAC." -ForegroundColor Yellow
