#!/bin/bash
# HBA CyberEagles - Hint Ladder (Day 2 - Linux)
# Place in /opt/aeacus/HintLadder.sh, chmod +x, create Desktop launcher.
# Writes marker files to /opt/aeacus/hints/ that scoring.conf checks for penalties.
# Uses zenity for GUI (apt install zenity if missing).

HINT_DIR="/opt/aeacus/hints"
SALT="hba-eagles-2026"
mkdir -p "$HINT_DIR"

get_token() {
    echo -n "${SALT}:${1}:${2}" | sha256sum | cut -c1-16
}

write_marker() {
    local cat="$1" tier="$2" text="$3"
    local path="${HINT_DIR}/${cat}.${tier}"
    if [ ! -f "$path" ]; then
        local token
        token=$(get_token "$cat" "$tier")
        cat > "$path" <<EOF
EAGLE_HINT_USED
token=$token
category=$cat
tier=$tier
---
$text
EOF
    fi
}

# Hint data
declare -A LABELS
LABELS[passwords]="Password Policy"
LABELS[sshconfig]="SSH Configuration"
LABELS[shadowperms]="/etc/shadow Permissions"
LABELS[cronbackdoor]="Forensics Q1 / Cron Backdoor"
LABELS[sudoers]="Sudoers / NOPASSWD"
LABELS[firewall]="Firewall"

declare -A HINTS
HINTS[passwords.1]="How do you enforce password rules on Linux? It's not a GUI."
HINTS[passwords.2]="Look at /etc/login.defs for aging. For complexity, search for 'pam pwquality'."
HINTS[passwords.3]="Set PASS_MAX_DAYS to 90 in /etc/login.defs. Install libpam-pwquality and set minlen=10 in /etc/security/pwquality.conf."

HINTS[sshconfig.1]="SSH is a required service — but is it configured safely?"
HINTS[sshconfig.2]="Read /etc/ssh/sshd_config. Look for settings about who can log in and how."
HINTS[sshconfig.3]="Set PermitRootLogin no and PermitEmptyPasswords no in /etc/ssh/sshd_config. Also check /root/.ssh/ for unauthorized keys. Restart sshd after."

HINTS[shadowperms.1]="Some files on Linux should never be readable by regular users. Which ones hold passwords?"
HINTS[shadowperms.2]="Run ls -la /etc/shadow. What do the permissions look like? What should they be?"
HINTS[shadowperms.3]="chmod 640 /etc/shadow (owner=root read/write, group=shadow read, others=none)."

HINTS[cronbackdoor.1]="Backdoors need to survive a reboot. Where does Linux schedule recurring tasks?"
HINTS[cronbackdoor.2]="Check /etc/cron.d/, /etc/crontab, and each user's crontab. Look for anything suspicious."
HINTS[cronbackdoor.3]="Look at /etc/cron.d/updater — it runs a netcat listener on port 4444. Delete the cron job AND the binary at /var/tmp/.cache-nc."

HINTS[sudoers.1]="Not every admin should have unlimited power. Where are sudo rules configured?"
HINTS[sudoers.2]="Check /etc/sudoers.d/ for extra files. Read each one — look for anything too permissive."
HINTS[sudoers.3]="Delete /etc/sudoers.d/91-jdoe (it grants NOPASSWD sudo). Also remove jdoe from the sudo group: sudo deluser jdoe sudo."

HINTS[firewall.1]="Does this machine have a firewall? Is it actually running?"
HINTS[firewall.2]="Run sudo ufw status. If it says 'inactive', that's a problem."
HINTS[firewall.3]="sudo ufw enable. That's it."

CATEGORIES=(passwords sshconfig shadowperms cronbackdoor sudoers firewall)

get_used_tier() {
    local cat="$1"
    for t in 3 2 1; do
        [ -f "${HINT_DIR}/${cat}.${t}" ] && echo "$t" && return
    done
    echo 0
}

tier_cost() {
    local total=0
    for ((t=1; t<=$1; t++)); do total=$((total + t)); done
    echo $total
}

show_hints() {
    local cat="$1"
    local used
    used=$(get_used_tier "$cat")
    local text=""
    for ((t=1; t<=used; t++)); do
        text="${text}=== TIER ${t} (-${t} pt) ===\n${HINTS[${cat}.${t}]}\n\n"
    done
    if [ "$used" -eq 0 ]; then
        text="No hints used yet for ${LABELS[$cat]}."
    fi
    echo -e "$text"
}

while true; do
    # Build category list with usage status
    menu_items=()
    for cat in "${CATEGORIES[@]}"; do
        used=$(get_used_tier "$cat")
        status=""
        [ "$used" -gt 0 ] && status=" [T${used} used]"
        menu_items+=("$cat" "${LABELS[$cat]}${status}")
    done

    choice=$(zenity --list \
        --title="HBA CyberEagles - Hint Ladder" \
        --text="Select a category. Each hint costs points.\nTier 1 = -1pt | Tier 2 = -2pts | Tier 3 = -3pts" \
        --column="Key" --column="Category" \
        --hide-column=1 \
        --width=450 --height=380 \
        "${menu_items[@]}" 2>/dev/null)

    [ -z "$choice" ] && break

    used=$(get_used_tier "$choice")
    current_hints=$(show_hints "$choice")

    if [ "$used" -ge 3 ]; then
        zenity --info --title="${LABELS[$choice]}" \
            --text="All tiers used.\n\n${current_hints}" \
            --width=500 2>/dev/null
        continue
    fi

    next_tier=$((used + 1))
    available=""
    for ((t=next_tier; t<=3; t++)); do
        cost=$(tier_cost "$t")
        available="${available}${t}  Tier ${t} - ${t}pts (${cost}pts total)\n"
    done

    tier_choice=$(zenity --list \
        --title="${LABELS[$choice]} - Pick a tier" \
        --text="${current_hints}\nAvailable hints:" \
        --column="Tier" --column="Description" \
        --width=500 --height=400 \
        $(for ((t=next_tier; t<=3; t++)); do
            cost=$(tier_cost "$t")
            echo "$t"
            echo "Tier ${t} - ${t}pts (-${cost}pts total for this category)"
        done) 2>/dev/null)

    [ -z "$tier_choice" ] && continue

    cost=$(tier_cost "$tier_choice")
    zenity --question \
        --title="Confirm Hint" \
        --text="Use Tier ${tier_choice} hint for '${LABELS[$choice]}'?\n\nThis will cost ${cost} point(s) total and CANNOT be undone." \
        --width=400 2>/dev/null

    if [ $? -eq 0 ]; then
        for ((t=1; t<=tier_choice; t++)); do
            write_marker "$choice" "$t" "${HINTS[${choice}.${t}]}"
        done

        new_hints=$(show_hints "$choice")
        zenity --info --title="${LABELS[$choice]}" \
            --text="${new_hints}" \
            --width=500 2>/dev/null
    fi
done
