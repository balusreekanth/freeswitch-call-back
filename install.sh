#!/bin/bash

# Author: Sreekanth Balu
# Date: 2024-12-21
# Email: balusreekanth@gmail.com
# Description: Shell script to install and configure FreeSWITCH Lua scripts for session-based callbacks, 
#              database interaction, and call origination management in FreeSWITCH.

# Define the service and timer file paths
config_file="/etc/fusionpbx/config.conf"
script_file="/usr/share/freeswitch/scripts/call-b.py"
SERVICE_FILE="/etc/systemd/system/call-b.service"
TIMER_FILE="/etc/systemd/system/call-b.timer"


LUA_DEPENDENCIES="luarocks lua-sql-sqlite3 lua-sql-postgres"
PYTHON_DEPENDENCIES="psycopg2 sqlite3"
PACKAGES="git wget curl freeswitch freeswitch-mod-lua sqlite3 postgresql-client"

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Update package lists and upgrade system
echo "Updating package lists and upgrading system..."
sudo apt-get update && sudo apt-get upgrade -y

# Check if Python is installed
if ! command_exists python3; then
    echo "Python3 is not installed. Installing Python3..."
    sudo apt-get install -y python3 python3-pip
else
    echo "Python3 is already installed."
fi

# Install system packages
echo "Installing system packages: $PACKAGES"
sudo apt-get install -y $PACKAGES

# Install Lua dependencies
echo "Installing Lua dependencies..."
for dep in $LUA_DEPENDENCIES; do
    sudo luarocks install "$dep"
done

# Install Python dependencies
echo "Installing Python dependencies..."
python3 -m pip install --upgrade pip
for dep in $PYTHON_DEPENDENCIES; do
    python3 -m pip install "$dep"
done

echo "Checking if FusionPBX and FreeSWITCH are installed..."

# Check if FusionPBX is installed
if [ -f "/etc/fusionpbx/config.conf" ]; then
    echo "FusionPBX is installed -----------OK"
else
    echo "FusionPBX is not installed.. exiting"
    exit 1
fi

# Check if FreeSWITCH directories exist
if [ -d "/usr/share/freeswitch/scripts/" ]; then
    echo "FreeSWITCH scripts directory exists ------OK"
    
    # Check if required files exist before copying
    if [ -f "./scripts/call-b.py" ] && [ -f "./scripts/dest_exist.lua" ]; then
        echo "Files exist, copying them..."
        sudo cp -r ./scripts/call-b.py /usr/share/freeswitch/scripts/call-b.py
        sudo cp -r ./scripts/dest_exist.lua /usr/share/freeswitch/scripts/dest_exist.lua
        sudo chown www-data:www-data /usr/share/freeswitch/scripts/call-b.py /usr/share/freeswitch/scripts/dest_exist.lua
        sudo chmod +x /usr/share/freeswitch/scripts/call-b.py /usr/share/freeswitch/scripts/dest_exist.lua
    else
        echo "Required files are missing."
        exit 1
    fi
else
    echo "FreeSWITCH scripts directory does not exist.. exiting"
    exit 1
fi

# Check if FreeSWITCH sound directories exist
if [ -d "/usr/share/freeswitch/sounds/" ]; then
    echo "FreeSWITCH sound directories exist ------OK"
    
    # Check if required sound files exist
    if [ -f "./sounds/busy_ivr.wav" ]; then
    sudo cp -r ./sounds/conf_announce.wav /usr/share/freeswitch/sounds/music/default/8000/
	sudo cp -r ./sounds/busy_ivr.wav /usr/share/freeswitch/sounds/en/us/callie/ivr/8000/busy_ivr.wav
	sudo chown www-data:www-data /usr/share/freeswitch/sounds/en/us/callie/ivr/8000/busy_ivr.wav
    else
        echo "Sound file busy_ivr.wav is missing."
        exit 1
    fi
else
    echo "FreeSWITCH sound directories do not exist.. exiting"
    exit 1
fi

# Check if PostgreSQL is accepting connections
if pg_isready > /dev/null 2>&1; then
    echo "PostgreSQL is accepting connections."
    echo "Creating tables..."
    sudo -u postgres psql -d fusionpbx -f ./db/v_busy_schema.sql
else
    echo "PostgreSQL is not accepting connections."
    exit 1
fi


# Extract the password value from the fusionpbx config file
password=$(grep -oP 'database\.0\.password\s*=\s*\K.+' "$config_file")

# Update the password in the Python script file
sed -i "s/^pg_password = .*/pg_password = \"$password\"/" "$script_file"

echo "Password has been updated in the script file."

# Create the systemd service file
echo "Creating the systemd service file: $SERVICE_FILE"

cat <<EOL > $SERVICE_FILE
[Unit]
Description=Run Python script every 15 seconds

[Service]
ExecStart=/usr/bin/python3 /usr/share/freeswitch/scripts/call-b.py
Restart=on-failure
User=www-data
Group=www-data
RestartSec=10
StartLimitIntervalSec=500
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOL

# Create the systemd timer file
echo "Creating the systemd timer file: $TIMER_FILE"

cat <<EOL > $TIMER_FILE
[Unit]
Description=Timer to run the call-b service every 15 seconds

[Timer]
OnBootSec=15
OnUnitActiveSec=15
Unit=call-b.service

[Install]
WantedBy=timers.target
EOL

# create a log file
sudo touch /var/log/call-b.log
sudo chown www-data:www-data /var/log/call-b.log
sudo chmod 644 /var/log/call-b.log


echo "Reloading systemd daemon"
sudo systemctl daemon-reload

# Enable and start the timer
echo "Enabling and starting the timer"
sudo systemctl enable call-b.timer
sudo systemctl start call-b.timer



echo "Further steps..."
echo "Create a dialplan named check_active_call with sequence 11 or something and copy below:"

cat <<EOF
   <condition field="destination_number" expression="^\d+$">
        <action application="log" data="WARNING Checking activity status for extension \${destination_number}"/>
        <action application="lua" data="dest_exist.lua \${destination_number} \${caller_id_number} \${domain_name}"/>
        <action application="log" data="WARNING extension activity status is \${sip_dialogs_status}"/>
        <action application="sleep" data="200"/>
    </condition>
EOF

