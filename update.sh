#!/bin/bash
# this script updates your server to the latest version available

DIR="@DIR@"


# parse script arguments
force=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      force=true
    ;;
    --force)
      force=true
    ;;
    *)
      echo "bad argument: $1"
      exit 1
    ;;
  esac
  shift
done

# change to server directory
cd $DIR

# check server status
if screen -list | grep -q "\.minecraft"; then
  echo "server is running - stopping server before update"
  # execute stop script
  ./stop.sh
else
  echo "server is not running - updating now"
fi

# check if user wants to force update
if ! [[ ${force} == true ]]; then
  # ask user for update
  echo "Would you like to update your server to the latest version available?"
  read -p "Your choice [y/n]: " choice
  regex="^(Y|y|N|n)$"
  while [[ ! ${choice} =~ ${regex} ]]; do
    read -p "Please press Y or N: " choice
  done
  if [[ $choice =~ ^[Yy]$ ]]; then
    # grep latest verion from papermc.io
    Version=$(wget -q -O - https://papermc.io/api/v2/projects/paper | rev | cut -d, -f1 | rev)
    Version="${Version:1}"
    Version="${Version::-3}"
    echo "latest server version seems to be ${Version}"
  else
    read -p "Please enter the version you want to update to: " Version
	# check if version is available
    wget --spider --quiet https://papermc.io/api/v1/paper/${Version}/latest/download
	if [ "$?" != 0 ]; then
      echo "The version you entered doesn't seem to exist!"
	  exit 1
    else
    fi
  fi
fi


echo "trying to update to version ${Version} ..."

# test if papermc is avalable and update on success
wget --spider --quiet https://papermc.io/api/v1/paper/${Version}/latest/download
if [ "$?" != 0 ]; then
  echo "Warning: Unable to connect to papermc API. Skipping update..."
else
  echo "Success: Updating to latest papermc version..."
  rm paperclip.jar
  wget -q -O paperclip.jar https://papermc.io/api/v1/paper/${Version}/latest/download
fi

# execute start script
./start.sh