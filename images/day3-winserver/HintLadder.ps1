# HBA CyberEagles - Hint Ladder (Day 3 - Windows Server 2022)
# Place in C:\aeacus\HintLadder.ps1, create shortcut on Desktop.
# Writes marker files to C:\aeacus\hints\ that scoring.conf checks for penalties.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$HintDir = "C:\aeacus\hints"
if (-not (Test-Path $HintDir)) { New-Item -ItemType Directory -Path $HintDir -Force | Out-Null }

$Salt = "hba-eagles-2026"

function Get-Token($category, $tier) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("${Salt}:d3-${category}:${tier}")
    $hash = $sha.ComputeHash($bytes)
    return ($hash | ForEach-Object { $_.ToString("x2") }) -join "" | ForEach-Object { $_.Substring(0,16) }
}

function Write-HintMarker($category, $tier, $hintText) {
    $token = Get-Token $category $tier
    $path = Join-Path $HintDir "${category}.${tier}"
    if (-not (Test-Path $path)) {
        @"
EAGLE_HINT_USED
token=$token
category=$category
tier=$tier
---
$hintText
"@ | Set-Content -Path $path -Encoding UTF8
    }
}

# Hint data: category -> tier -> hint text
$Hints = @{
    "secpol" = @{
        Label = "Local Security Policy"
        1 = "A server needs stricter rules than a workstation. Where do you set password and account policies?"
        2 = "Try running secpol.msc. Look under Account Policies and Local Policies. On a server, also check Security Options for the Administrator account rename policy."
        3 = "Account Policies: min length 10+, complexity on, max age 30-90, history 5+, lockout 1-10. Local Policies > Audit Policy: audit logon events (both). Security Options: rename the Administrator account to 'CyberAdmin'."
    }
    "iis" = @{
        Label = "IIS / Forensics Q1"
        1 = "The README says a web server is NOT required. Is one running anyway?"
        2 = "Open a browser and go to http://localhost. If you see a page, something is serving it. Where do you manage Windows server roles?"
        3 = "IIS is installed as a Windows Feature. Remove it: Server Manager > Remove Roles and Features > Web Server (IIS). The port it listens on (80) is the forensics Q1 answer."
    }
    "remotereg" = @{
        Label = "Remote Registry"
        1 = "Which services let someone mess with this machine remotely?"
        2 = "services.msc, sort by name, look for anything with 'Remote.'"
        3 = "Remote Registry service: stop it and set Startup Type to Disabled."
    }
    "uac" = @{
        Label = "UAC"
        1 = "Even on a server, UAC matters. Is it turned on?"
        2 = "Search for 'UAC' or check Control Panel > User Accounts > Change User Account Control settings."
        3 = "Slide UAC to the recommended level. Or in regedit: HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\EnableLUA should be 1."
    }
    "smbv1" = @{
        Label = "SMBv1"
        1 = "Old protocols are vulnerabilities. What did WannaCry exploit in 2017?"
        2 = "On a server, features are managed through Server Manager or PowerShell. Look for SMB-related features."
        3 = "Remove the FS-SMB1 feature: Remove-WindowsFeature FS-SMB1, or use Server Manager > Remove Roles and Features."
    }
    "bkahale" = @{
        Label = "bkahale password"
        1 = "Read the README carefully. Does anything in it make you cringe?"
        2 = "Look at the passwords listed for authorized users. Would you use any of those passwords for a server?"
        3 = "bkahale's password is 'password'. Change it with: net user bkahale <NewStrongPassword>"
    }
}

$CategoryOrder = @("secpol","iis","remotereg","uac","smbv1","bkahale")

# Track which hints have been used (check existing marker files)
$Used = @{}
foreach ($cat in $CategoryOrder) {
    $Used[$cat] = 0
    for ($t = 3; $t -ge 1; $t--) {
        if (Test-Path (Join-Path $HintDir "${cat}.${t}")) {
            $Used[$cat] = $t
            break
        }
    }
}

# --- GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "HBA CyberEagles - Hint Ladder"
$form.Size = New-Object System.Drawing.Size(620, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(13, 20, 32)
$form.ForeColor = [System.Drawing.Color]::FromArgb(230, 236, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Hint Ladder"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(212, 169, 60)
$title.Location = New-Object System.Drawing.Point(20, 10)
$title.AutoSize = $true
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Each hint costs points. Tier 1 = -1, Tier 2 = -2, Tier 3 = -3. Once used, it's permanent."
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(122, 134, 153)
$subtitle.Location = New-Object System.Drawing.Point(20, 40)
$subtitle.Size = New-Object System.Drawing.Size(570, 20)
$form.Controls.Add($subtitle)

$catList = New-Object System.Windows.Forms.ListBox
$catList.Location = New-Object System.Drawing.Point(20, 70)
$catList.Size = New-Object System.Drawing.Size(180, 400)
$catList.BackColor = [System.Drawing.Color]::FromArgb(24, 35, 56)
$catList.ForeColor = [System.Drawing.Color]::FromArgb(230, 236, 245)
$catList.BorderStyle = "None"
$catList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
foreach ($cat in $CategoryOrder) {
    $label = $Hints[$cat].Label
    $usedTier = $Used[$cat]
    $suffix = if ($usedTier -gt 0) { " [T$usedTier used]" } else { "" }
    $catList.Items.Add("$label$suffix") | Out-Null
}
$form.Controls.Add($catList)

$rightPanel = New-Object System.Windows.Forms.Panel
$rightPanel.Location = New-Object System.Drawing.Point(210, 70)
$rightPanel.Size = New-Object System.Drawing.Size(385, 400)
$rightPanel.BackColor = [System.Drawing.Color]::FromArgb(19, 29, 46)
$form.Controls.Add($rightPanel)

$btnTier1 = New-Object System.Windows.Forms.Button
$btnTier1.Text = "Tier 1 - 1pt"
$btnTier1.Location = New-Object System.Drawing.Point(10, 10)
$btnTier1.Size = New-Object System.Drawing.Size(115, 32)
$btnTier1.FlatStyle = "Flat"
$btnTier1.BackColor = [System.Drawing.Color]::FromArgb(146, 64, 14)
$btnTier1.ForeColor = [System.Drawing.Color]::White
$btnTier1.Visible = $false
$rightPanel.Controls.Add($btnTier1)

$btnTier2 = New-Object System.Windows.Forms.Button
$btnTier2.Text = "Tier 2 - 2pts"
$btnTier2.Location = New-Object System.Drawing.Point(135, 10)
$btnTier2.Size = New-Object System.Drawing.Size(125, 32)
$btnTier2.FlatStyle = "Flat"
$btnTier2.BackColor = [System.Drawing.Color]::FromArgb(154, 52, 18)
$btnTier2.ForeColor = [System.Drawing.Color]::White
$btnTier2.Visible = $false
$rightPanel.Controls.Add($btnTier2)

$btnTier3 = New-Object System.Windows.Forms.Button
$btnTier3.Text = "Tier 3 - 3pts"
$btnTier3.Location = New-Object System.Drawing.Point(270, 10)
$btnTier3.Size = New-Object System.Drawing.Size(105, 32)
$btnTier3.FlatStyle = "Flat"
$btnTier3.BackColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
$btnTier3.ForeColor = [System.Drawing.Color]::White
$btnTier3.Visible = $false
$rightPanel.Controls.Add($btnTier3)

$hintBox = New-Object System.Windows.Forms.TextBox
$hintBox.Multiline = $true
$hintBox.ReadOnly = $true
$hintBox.WordWrap = $true
$hintBox.ScrollBars = "Vertical"
$hintBox.Location = New-Object System.Drawing.Point(10, 52)
$hintBox.Size = New-Object System.Drawing.Size(365, 330)
$hintBox.BackColor = [System.Drawing.Color]::FromArgb(13, 20, 32)
$hintBox.ForeColor = [System.Drawing.Color]::FromArgb(230, 236, 245)
$hintBox.BorderStyle = "None"
$hintBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$rightPanel.Controls.Add($hintBox)

function Update-RightPanel {
    $idx = $catList.SelectedIndex
    if ($idx -lt 0) { return }
    $cat = $CategoryOrder[$idx]
    $usedTier = $Used[$cat]

    $btnTier1.Visible = $true
    $btnTier2.Visible = $true
    $btnTier3.Visible = $true

    $btnTier1.Enabled = $usedTier -lt 1
    $btnTier2.Enabled = $usedTier -lt 2
    $btnTier3.Enabled = $usedTier -lt 3

    if ($usedTier -ge 1) { $btnTier1.Text = "Tier 1 (used)" }
    else { $btnTier1.Text = "Tier 1 - 1pt" }
    if ($usedTier -ge 2) { $btnTier2.Text = "Tier 2 (used)" }
    else { $btnTier2.Text = "Tier 2 - 2pts" }
    if ($usedTier -ge 3) { $btnTier3.Text = "Tier 3 (used)" }
    else { $btnTier3.Text = "Tier 3 - 3pts" }

    # Show all revealed hints
    $text = ""
    for ($t = 1; $t -le $usedTier; $t++) {
        $cost = switch ($t) { 1 { "-1 pt" } 2 { "-2 pts" } 3 { "-3 pts" } }
        $text += "=== TIER $t ($cost) ===`r`n"
        $text += $Hints[$cat][$t] + "`r`n`r`n"
    }
    if ($usedTier -eq 0) {
        $text = "Select a tier to reveal a hint.`r`n`r`nTier 1 is a gentle nudge.`r`nTier 2 points you in the right direction.`r`nTier 3 is basically the answer.`r`n`r`nEach tier costs more points."
    }
    $hintBox.Text = $text
}

function Use-Hint($tier) {
    $idx = $catList.SelectedIndex
    if ($idx -lt 0) { return }
    $cat = $CategoryOrder[$idx]

    $costTotal = 0
    for ($t = ($Used[$cat] + 1); $t -le $tier; $t++) { $costTotal += $t }
    $label = $Hints[$cat].Label

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Use Tier $tier hint for '$label'?`n`nThis will cost $costTotal additional point(s) and CANNOT be undone.",
        "Confirm Hint",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne "Yes") { return }

    # Write marker files for all tiers up to this one
    for ($t = 1; $t -le $tier; $t++) {
        Write-HintMarker $cat $t $Hints[$cat][$t]
    }
    $Used[$cat] = $tier

    # Update list label
    $suffix = " [T$tier used]"
    $catList.Items[$idx] = $Hints[$cat].Label + $suffix

    Update-RightPanel
}

$catList.Add_SelectedIndexChanged({ Update-RightPanel })
$btnTier1.Add_Click({ Use-Hint 1 })
$btnTier2.Add_Click({ Use-Hint 2 })
$btnTier3.Add_Click({ Use-Hint 3 })

$catList.SelectedIndex = 0

[void]$form.ShowDialog()
