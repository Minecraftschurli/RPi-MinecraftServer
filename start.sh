#!/bin/bash
# Minecraft Server startup script using screen

VERSION="@VERSION@"
DIR="@DIR@"
MEM="@MEM@"

# Flush out memory to disk so we have the maximum available for Java allocation
sudo ./clear_cache.sh

# Check if server is already running
if screen -list | grep -q "\.minecraft"; then
    echo "Server is already running!  Type connect to open the console"
    exit 1
fi

# Check if network interfaces are up
NetworkChecks=0
DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
while [ -z "$DefaultRoute" ]; do
    echo "Network interface not up, will try again in 1 second";
    sleep 1;
    DefaultRoute=$(route -n | awk '$4 == "UG" {print $2}')
    NetworkChecks=$((NetworkChecks+1))
    if [ $NetworkChecks -gt 20 ]; then
        echo "Waiting for network interface to come up timed out - starting server without network connection ..."
        break
    fi
done

# Switch to server directory
cd $DIR

# Back up server
./backup.sh --auto

# Paper / Spigot / Bukkit Optimization settings
# Original guide by Celebrimbor: https://www.spigotmc.org/threads/guide-server-optimization%E2%9A%A1.283181/

# Configure paper.yml options
if [ -f "paper.yml" ]; then
    sed -i "s/keep-spawn-loaded: true/keep-spawn-loaded: false/g" paper.yml
    sed -i "s/keep-spawn-loaded-range: 10/keep-spawn-loaded-range: -1/g" paper.yml
fi

# Configure bukkit.yml options
if [ -f "bukkit.yml" ]; then
    # autosave
    # This enables Bukkit's world saving function and how often it runs (in ticks). It should be 6000 (5 minutes) by default.
    # This is causing 10 second lag spikes in 1.14 so we are going to increase it to 18000 (15 minutes).
    sed -i "s/autosave: 6000/autosave: 18000/g" bukkit.yml
fi

# Configure spigot.yml options
if [ -f "spigot.yml" ]; then
    # Merging items has a huge impact on tick consumption for ground items. Higher values allow more items to be swept into piles and allow you to avoid plugins like ClearLag.
    # Note: Merging items will lead to the occasional illusion of items disappearing as they merge together a few blocks away. A minor annoyance.
    sed -i "s/exp: 3.0/exp: 6.0/g" spigot.yml
    sed -i "s/item: 2.5/item: 4.0/g" spigot.yml
fi

# Configure server.properties options
if [ -f "server.properties" ]; then
    # Configure server.properties
    # network-compression-threshold
    # This option caps the size of a packet before the server attempts to compress it. Setting it higher can save some resources at the cost of more bandwidth, setting it to -1 disables it.
    # Note: If your server is in a network with the proxy on localhost or the same datacenter (<2 ms ping), disabling this (-1) will be beneficial.
    sed -i "s/network-compression-threshold=256/network-compression-threshold=512/g" server.properties
    # Disable Spawn protection
    sed -i "s/spawn-protection=16/spawn-protection=0/g" server.properties
    # Disable snooper
    sed -i "s/snooper-enabled=true/snooper-enabled=false/g" server.properties
    # Increase server watchdog timer to prevent it from shutting itself down without restarting
    sed -i "s/max-tick-time=60000/max-tick-time=120000/g" server.properties

fi

# Update paperclip.jar
echo "Updating to most recent paperclip version ..."

# Test internet connectivity first
PAPER_URL="https://papermc.io/api/v1/paper/$VERSION/latest/download"
if ! wget --spider --quiet "$PAPER_URL"; then
    echo "Unable to connect to update website (internet connection may be down).  Skipping update ..."
else
    wget -O paperclip.jar "$PAPER_URL"
fi

echo "Starting Minecraft server.  To view window type screen -r minecraft."
echo "To minimize the window and let the server run in the background, press Ctrl+A then Ctrl+D"
screen -dmS minecraft java -jar -Xms400M -Xmx${MEM} $DIR/paperclip.jar
