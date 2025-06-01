#!/bin/bash

read -p "Are you running this script on the IRAN server or the FOREIGN server? (IRAN/FOREIGN): " server_location_en
echo -e "\033[1;33mUpdating and installing required packages...\033[0m"
sudo apt update
sudo apt-get install iproute2 -y
sudo apt install nano netplan.io -y

function ask_yes_no() {
    local prompt=$1
    local answer=""
    while true; do
        read -p "$prompt (yes/no): " answer
        if [[ "$answer" == "yes" || "$answer" == "no" ]]; then
            echo "$answer"
            break
        else
            echo -e "\033[1;31mOnly yes or no allowed.\033[0m"
        fi
    done
}

base_ipv6_prefix="2619:db8:85a3:1b2e"

if [[ "$server_location_en" == "IRAN" || "$server_location_en" == "iran" ]]; then
    read -p "Please enter the IPv4 address of the IRAN server: " iran_ip
    read -p "Please enter the MTU (press Enter for default 1420): " mtu
    mtu=${mtu:-1420}
    read -p "How many FOREIGN servers do you have? " n_server
    declare -a foreign_ips

    for (( i=1; i<=$n_server; i++ )); do
        read -p "Enter IPv4 of FOREIGN server #$i: " temp_ip
        foreign_ips[i]=$temp_ip
    done

    for (( i=1; i<=$n_server; i++ )); do
        tunnel_name="tunel$(printf "%02d" $i)"
        netplan_file="/etc/netplan/pdtun${i}.yaml"
        iran_ipv6="${base_ipv6_prefix}::1${i}"
        foreign_ipv6="${base_ipv6_prefix}::2${i}"

        sudo bash -c "cat > $netplan_file <<EOF
network:
  version: 2
  tunnels:
    $tunnel_name:
      mode: sit
      local: $iran_ip
      remote: ${foreign_ips[i]}
      addresses:
        - $iran_ipv6/64
      mtu: $mtu
      routes:
        - to: $foreign_ipv6/128
          scope: link
EOF"

        systemd_file="/etc/systemd/network/${tunnel_name}.network"
        sudo bash -c "cat > $systemd_file <<EOF
[Match]
Name=$tunnel_name

[Network]
Address=$iran_ipv6/64
Gateway=$foreign_ipv6
EOF"

        echo -e "\033[1;37mPrivate-IPv6 for IRAN server #$i: $iran_ipv6\033[0m"
    done

else
    read -p "Please enter the IPv4 address of the FOREIGN server: " foreign_ip
    read -p "Please enter the IPv4 address of the IRAN server: " iran_ip
    read -p "Please enter the MTU (press Enter for default 1420): " mtu
    mtu=${mtu:-1420}
    read -p "Which number is this FOREIGN server? (e.g., 1, 2, 3...): " server_number

    tunnel_name="tunel$(printf "%02d" $server_number)"
    netplan_file="/etc/netplan/pdtun${server_number}.yaml"
    foreign_ipv6="${base_ipv6_prefix}::2${server_number}"
    iran_ipv6="${base_ipv6_prefix}::1${server_number}"

    sudo bash -c "cat > $netplan_file <<EOF
network:
  version: 2
  tunnels:
    $tunnel_name:
      mode: sit
      local: $foreign_ip
      remote: $iran_ip
      addresses:
        - $foreign_ipv6/64
      mtu: $mtu
      routes:
        - to: $iran_ipv6/128
          scope: link
EOF"

    systemd_file="/etc/systemd/network/${tunnel_name}.network"
    sudo bash -c "cat > $systemd_file <<EOF
[Match]
Name=$tunnel_name

[Network]
Address=$foreign_ipv6/64
Gateway=$iran_ipv6
EOF"

    echo -e "\033[1;37mPrivate-IPv6 for FOREIGN server #$server_number: $foreign_ipv6\033[0m"
fi

sudo systemctl unmask systemd-networkd.service
sudo systemctl restart systemd-networkd
sudo netplan apply

reboot_choice=$(ask_yes_no "Operation completed successfully. Please reboot the system")
if [ "$reboot_choice" == "yes" ]; then
    echo -e "\033[1;33mRebooting the system...\033[0m"
    sudo reboot
else
    echo -e "\033[1;33mOperation completed successfully. Reboot required.\033[0m"
fi
