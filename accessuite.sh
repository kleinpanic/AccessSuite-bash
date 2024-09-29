#!/usr/bin/env bash

# Define the path to the file containing approved SSH hosts
APPROVED_HOSTS_FILE="/path/to/approved_hosts.txt"
LOG_FILE="/var/log/AccessSuite.log"

# Function to log activities
log_activity() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to perform a background check on the SSHing computer
background_check() {
    SSH_CLIENT_INFO=$(echo $SSH_CLIENT)
    IP_ADDRESS=$(echo $SSH_CLIENT_INFO | awk '{print $1}')
    USERNAME=$(whoami)
    TERM_TYPE=$TERM

    # Fetch fonts from the SSHing computer
    FONTS=$(ssh -q "$USERNAME@$IP_ADDRESS" 'fc-list' 2>/dev/null)

    # Check if the terminal supports LSD (ls deluxe) fonts
    if [[ ! "$FONTS" =~ "nerd font" ]]; then
        log_activity "User $USERNAME at $IP_ADDRESS does not have the appropriate LSD fonts installed."
        # Add your logic for what to do here
    fi

    # Check if the IP is on the local network
    if [[ $IP_ADDRESS =~ ^192\.168\.|10\.|172\.16\. ]]; then
        LOCAL=true
        log_activity "User $USERNAME is connecting from a local network with IP $IP_ADDRESS."
    else
        LOCAL=false
        log_activity "User $USERNAME is connecting from an external network with IP $IP_ADDRESS."
    fi

    # Check if the IP address is approved
    if ! grep -q "$IP_ADDRESS" "$APPROVED_HOSTS_FILE"; then
        log_activity "Unauthorized SSH connection detected from $IP_ADDRESS. Initiating safeguard daemon."
        safeguard_daemon &
    fi

    # Call the GTK C program to notify of a connection (replace with your C program execution)
    /path/to/your/gtk_notification_program "$USERNAME" "$IP_ADDRESS" "$TERM_TYPE" &
}

# Function to monitor and safeguard the system against unauthorized SSH users
safeguard_daemon() {
    ATTEMPT_COUNTER=0
    log_activity "Safeguard daemon started for user $USERNAME from $IP_ADDRESS."

    # Monitor `/var/log/auth.log` for sudo attempts (adapt for your system's auth log)
    tail -Fn0 /var/log/auth.log | while read LINE; do
        if echo "$LINE" | grep -q "sudo:"; then
            ATTEMPT_COUNTER=$((ATTEMPT_COUNTER + 1))
            log_activity "Unauthorized sudo attempt detected from $USERNAME at $IP_ADDRESS. Attempt #$ATTEMPT_COUNTER."

            if [[ $ATTEMPT_COUNTER -ge 3 ]]; then
                log_activity "User $USERNAME at $IP_ADDRESS has been kicked off for excessive privilege attempts."
                pkill -KILL -u "$USERNAME"
                exit 0
            fi
        fi
    done
}

# Start the background check process
background_check &
