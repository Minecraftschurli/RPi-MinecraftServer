#!/bin/bash
# Minecraft Server restart script

USER="@USER@"
DIR="@DIR@"

if [ "$(whoami)" != "$USER" ]; then
  dir=$(pwd)
  cd $DIR/
  sudo -u $USER ./restart.sh
  cd "$dir"
  exit 0
fi

# Check if server is running
if ! screen -list | grep -q "\.minecraft"; then
    echo "Server is not currently running!"
    exit 1
fi

echo "Sending restart notifications to server..."
source ./server_command.sh
# Minecraft Server restart and pi reboot.
counter="30"
while [ ${counter} -gt 0 ]; do
	if [[ "${counter}" =~ ^(30|7|6|5|4|3|2)$ ]]; then
		server say Server is restarting in ${counter} seconds!
	fi
	if [[ "${counter}" = 1 ]]; then
		server say Server is restarting in ${counter} second!
	fi
	counter=$((counter-1))
	sleep 1s
done

server say Closing server...
server stop

# Wait up to 30 seconds for server to close
echo "Closing server..."
StopChecks=0
while [ $StopChecks -lt 30 ]; do
  if ! screen -list | grep -q "\.minecraft"; then
    break
  fi
  sleep 1;
  StopChecks=$((StopChecks+1))
done

echo "Restarting now."
sudo reboot
