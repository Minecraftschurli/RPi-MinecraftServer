#!/bin/bash

#################### Config ######################
URL="https://raw.githubusercontent.com/Minecraftschurli/RPi-MinecraftServer/main/"
DIR="/var/lib/minecraft"
USER="minecraft"
SCRIPTS="start.sh stop.sh update.sh restart.sh backup.sh clear_cache.sh"
HELPERS="server_connect.sh server_command.sh"
##################################################

# Terminal colors
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

# Prints a line with color using terminal codes
PrintStyle() {
  printf "%s\n" "${2}$1${NORMAL}"
}

# Configure how much memory to use for the Minecraft server
GetServerMemory() {
  sync
  sleep 1s

  PrintStyle "Getting total system memory..." "$YELLOW"
  TotalMemory=$(awk '/MemTotal/ { printf "%.0f\n", $2/1024 }' /proc/meminfo)
  AvailableMemory=$(awk '/MemAvailable/ { printf "%.0f\n", $2/1024 }' /proc/meminfo)
  CPUArch=$(uname -m)

  PrintStyle "Total memory: $TotalMemory - Available Memory: $AvailableMemory" "$YELLOW"
  if [[ "$CPUArch" == *"armv7"* || "$CPUArch" == *"armhf"* ]]; then
    if [ "$AvailableMemory" -gt 2700 ]; then
      PrintStyle "Warning: You are running a 32 bit operating system which has a hard limit of 3 GB of memory per process" "$RED"
      PrintStyle "You must also leave behind some room for the Java VM process overhead.  It is not recommended to exceed 2700 and if you experience crashes you may need to reduce it further." $RED
      PrintStyle "You can remove this limit by using a 64 bit Raspberry Pi Linux distribution (aarch64/arm64) like Ubuntu, Debian, etc." "$RED"
      AvailableMemory=2700
    fi
  fi
  if [ "$TotalMemory" -lt 700 ]; then
    PrintStyle "Not enough memory to run a Minecraft server.  Requires at least 1024MB of memory!" "$YELLOW"
    exit 1
  fi
  PrintStyle "Total memory: $TotalMemory - Available Memory: $AvailableMemory"
  if [ $AvailableMemory -lt 700 ]; then
    PrintStyle "WARNING:  Available memory to run the server is less than 700MB.  This will impact performance and stability." "$RED"
    PrintStyle "You can increase available memory by closing other processes.  If nothing else is running your distro may be using all available memory." "$RED"
    PrintStyle "It is recommended to use a headless distro (Lite or Server version) to ensure you have the maximum memory available possible." "$RED"
    read -n1 -r -p "Press any key to continue"
  fi

  # Ask user for amount of memory they want to dedicate to the Minecraft server
  PrintStyle "Please enter the amount of memory you want to dedicate to the server.  A minimum of 700MB is recommended." "$CYAN"
  PrintStyle "You must leave enough left over memory for the operating system to run background processes." "$CYAN"
  PrintStyle "If all memory is exhausted the Minecraft server will either crash or force background processes into the paging file (very slow)." "$CYAN"
  if [[ "$CPUArch" == *"aarch64"* || "$CPUArch" == *"arm64"* ]]; then
    PrintStyle "INFO: You are running a 64-bit architecture, which means you can use more than 2700MB of RAM for the Minecraft server." "$YELLOW"
  fi
  MemSelected=0
  while [[ $MemSelected -lt 600 || $MemSelected -ge $TotalMemory ]]; do
    read -p "Enter amount of memory in megabytes to dedicate to the Minecraft server (recommended: $AvailableMemory): " MemSelected
    if [[ $MemSelected -lt 600 ]]; then
      PrintStyle "Please enter a minimum of 600" "$RED"
    elif [[ $MemSelected -gt $TotalMemory ]]; then
      PrintStyle "Please enter an amount less than the total memory in the system ($TotalMemory)" "$RED"
    elif [[ $MemSelected -gt 2700 && "$CPUArch" == *"armv7"* || "$CPUArch" == *"armhf"* ]]; then
      PrintStyle "You are running a 32 bit operating system which has a limit of 2700MB.  Please enter 2700 to use it all." "$RED"
      PrintStyle "If you experience crashes at 2700MB you may need to run SetupMinecraft again and lower it further." "$RED"
      PrintStyle "You can lift this restriction by upgrading to a 64 bit operating system." "$RED"
      MemSelected=0
    fi
  done
  PrintStyle "Amount of memory for Minecraft server selected: $MemSelected MB" "$GREEN"
}

InstallJava() {
  # Install Java
  PrintStyle "Installing latest Java OpenJDK..." "$YELLOW"

  # Check for the highest available JDK first and then decrement version until we find a candidate for installation
  JavaVer=$(apt-cache show openjdk-16-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-16-jre-headless -y
    return
  fi
  JavaVer=$(apt-cache show openjdk-15-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-15-jre-headless -y
    return
  fi
  JavaVer=$(apt-cache show openjdk-14-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-14-jre-headless -y
    return
  fi
  JavaVer=$(apt-cache show openjdk-13-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-13-jre-headless -y
    return
  fi
  JavaVer=$(apt-cache show openjdk-12-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-12-jre-headless -y
    return
  fi
  JavaVer=$(apt-cache show openjdk-11-jre-headless | grep Version | awk 'NR==1{ print $2 }')
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-11-jre-headless -y
    return
  fi
  if [[ "$JavaVer" ]]; then
    apt-get install openjdk-10-jre-headless -y
    return
  fi

  # Install OpenJDK 9 as a fallback
  if [ ! -n "$(which java)" ]; then
    JavaVer=$(apt-cache show openjdk-9-jre-headless | grep Version | awk 'NR==1{ print $2 }')
    if [[ "$JavaVer" ]]; then
      apt-get install openjdk-9-jre-headless -y
      return
    fi
  fi
  

  # Check if Java installation was successful
  if [ -n "$(which java)" ]; then
    PrintStyle "Java installed successfully" "$GREEN"
  else
    PrintStyle "Java did not install successfully -- please install manually or check the above output to see what went wrong and run the installation script again." "$RED"
    exit 1
  fi
}

GetMCVersion() {
  answer="n" 
  # nested loop for version authentication and user input
  while [[ "$answer" != "y" ]]; do
    while [[ "$answer" != "y" ]]; do
      read -p "Enter the version of minecraft you want to run: " mcVer
      read -p "Do you want to run on version $mcVer? [y/n]" answer
    done

    if [[ "$answer" == "y" ]]; then
      PrintStyle "Getting Paper Minecraft server v$mcVer..." "$YELLOW"
      PAPER_URL="https://papermc.io/api/v1/paper/$mcVer/latest/download"
      wget --spider --quiet "$PAPER_URL"
      if [ $? -ne 0 ]; then 
        PrintStyle "$mcVer is not a valid version, please try again" "$RED"
        answer="n"
      fi
	fi
  done
  VERSION="$mcVer"
}

# Create the user to run the server as
CreateUser() {
  PrintStyle "Creating user $USER for Minecraft Server" "$YELLOW"
  adduser --system --home $DIR $USER
}

# Get all scripts
GetScripts() {
  CWD=$(pwd)
  cd $DIR
  PrintStyle "Getting scripts from repository..." "$YELLOW"
  for SCRIPT in $SCRIPTS; do
    wget -O $SCRIPT $URL/$SCRIPT
    chmod +x $SCRIPT
    sed -i "s+@VERSION@+$VERSION+g" $SCRIPT
    sed -i "s+@DIR@+$DIR+g" $SCRIPT
    sed -i "s+@USER@+$USER+g" $SCRIPT
  done
  PrintStyle "Getting helper scripts from repository..." "$YELLOW"
  for SCRIPT in $HELPERS; do
    wget -O $SCRIPT $URL/$SCRIPT
	echo ". ~/$SCRIPT" >> .bash_aliases
  done
  echo "connect" >> .bashrc
  cd $CWD
}

# Updates Minecraft service
GetService() {
  wget -O /etc/systemd/system/minecraft.service $URL/minecraft.service
  chmod +x /etc/systemd/system/minecraft.service
  sed -i "s+@DIR@+$DIR+g" /etc/systemd/system/minecraft.service
  sed -i "s+@USER@+$USER+g" /etc/systemd/system/minecraft.service
  systemctl daemon-reload
  PrintStyle "Minecraft can automatically start at boot if you wish." "$CYAN"
  echo -n "Start Minecraft server at startup automatically (y/n)?"
  read answer
  if [ "$answer" != "${answer#[Yy]}" ]; then
    systemctl enable minecraft.service
  fi
}

# Configuration of server automatic reboots
ConfigureReboot() {
  # Automatic reboot at 4am configuration
  TimeZone=$(cat /etc/timezone)
  CurrentTime=$(date)
  PrintStyle "Your time zone is currently set to $TimeZone.  Current system time: $CurrentTime" "$CYAN"
  PrintStyle "You can adjust/remove the selected reboot time later by typing crontab -e" "$CYAN"
  echo -n "Automatically reboot Pi and update server at 4am daily (y/n)?"
  read answer
  if [ "$answer" != "${answer#[Yy]}" ]; then
    croncmd="$DIR/restart.sh"
    cronjob="0 4 * * * $croncmd"
    (
      crontab -l | grep -v -F "$croncmd"
      echo "$cronjob"
    ) | crontab -
    PrintStyle "Daily reboot scheduled.  To change time or remove automatic reboot type crontab -e" "$GREEN"
  fi
}

# Install required programs
InstallRequirements() {
  # Install dependencies needed to run minecraft in the background
  PrintStyle "Installing screen, sudo, net-tools, wget..." "$YELLOW"
  if [ ! -n "$(which sudo)" ]; then
    apt-get update && apt-get install sudo -y
  fi
  apt-get update
  apt-get install screen wget -y
  apt-get install net-tools -y
}

# Accept the Minecraft EULA
AcceptEULA() {
  CWD=$(pwd)
  cd $DIR
  # Accept the EULA
  PrintStyle "Accepting the EULA..." "$GREEN"
  echo eula=true > eula.txt
  cd $CWD
}

# Configure the server
ConfigureServer() {
  # Server configuration
  PrintStyle "Enter a name for your server..." "$MAGENTA"
  read -p 'Server Name: ' servername
  echo "server-name=$servername" >> server.properties
  echo "motd=$servername" >> server.properties
}

# Set the owner for all files
FixOwner() {
  chown -R $USER $DIR
}

# Fix execution permissions for clear_cache, reboot and mount
FixPermissions() {
  echo "$USER ALL=(ALL) NOPASSWD: $DIR/clear_cache.sh" >> /etc/sudoers
  echo "$USER ALL=(ALL) NOPASSWD: /sbin/reboot" >> /etc/sudoers
  echo "$USER ALL=(ALL) NOPASSWD: /bin/mount" >> /etc/sudoers
}

# Start the Minecraft Server
StartServer() {
  PrintStyle "Setup is complete.  Starting Minecraft server..." "$GREEN"
  systemctl start minecraft.service
  
  # Wait up to 30 seconds for server to start
  StartChecks=0
  while [ $StartChecks -lt 30 ]; do
    if sudo -u minecraft screen -list | grep -q "\.minecraft"; then
      break
    fi
    sleep 1
    StartChecks=$((StartChecks + 1))
  done

  if [[ $StartChecks == 30 ]]; then
    PrintStyle "Server has failed to start after 30 seconds." "$RED"
  else
    PrintStyle "Server has started! connect to it via 'sudo su $USER'" "$GREEN"
  fi
}

################################################################################

PrintStyle "Minecraft Server installation script by Minecraftschurli - May 8th 2021" "$MAGENTA"
PrintStyle "Don't forget to set up port forwarding on your router!  The default port is 25565" "$MAGENTA"

InstallRequirements

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

InstallJava
GetServerMemory
CreateUser
GetMCVersion
AcceptEULA
GetScripts
ConfigureServer
GetService
FixOwner
FixPermissions
StartServer
