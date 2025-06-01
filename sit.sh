#!/bin/bash

read -p "Are you running this script on the IRAN server or the FOREIGN server? (IRAN/FOREIGN): " server_location_en
echo -e "\033[1;33mUpdating and installing required packages...\033[0m"
sudo apt update
sudo apt-get install iproute2 -y
sudo apt install nano -y
sudo apt install netplan.io -y

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
        netplan_file="/etc/netplan/pdtun${i}.yaml"
        tunnel_name="tunel0$i"
        subnet_hex=$(printf "%x" $i)

        sudo bash -c "cat > $netplan_file <<EOF
network:
  version: 2
  tunnels:
    $tunnel_name:
      mode: sit
      local: $iran_ip
      remote: ${foreign_ips[i]}
      addresses:
        - 2619:db8:85a3:1b2e:$subnet_hex::2/64
      mtu: $mtu
      routes:
        - to: 2619:db8:85a3:1b2e:$subnet_hex::1/128
          scope: link
EOF"

        network_file="/etc/systemd/network/${tunnel_name}.network"
        sudo bash -c "cat > $network_file <<EOF
[Match]
Name=$tunnel_name

[Network]
Address=2619:db8:85a3:1b2e:$subnet_hex::2/64
Gateway=2619:db8:85a3:1b2e:$subnet_hex::1
EOF"

        echo -e "\033[1;37mIPv6 for IRAN tunnel #$i: 2619:db8:85a3:1b2e:$subnet_hex::2\033[0m"
    done

    sudo systemctl unmask systemd-networkd.service
    sudo systemctl restart systemd-networkd
    sudo netplan apply

    reboot_choice=$(ask_yes_no "Operation completed. Do you want to reboot?")
    if [ "$reboot_choice" == "yes" ]; then
        echo -e "\033[1;33mRebooting...\033[0m"
        sudo reboot
    else
        echo -e "\033[1;33mReboot required.\033[0m"
    fi
else
    read -p "Please enter the IPv4 address of the FOREIGN server: " foreign_ip
    read -p "Please enter the IPv4 address of the IRAN server: " iran_ip
    read -p "Please enter the MTU (press Enter for default 1420): " mtu
    mtu=${mtu:-1420}
    read -p "Which number is this FOREIGN server? " server_number

    tunnel_name="tunel0$server_number"
    subnet_hex=$(printf "%x" $server_number)

    sudo bash -c "cat > /etc/netplan/pdtun.yaml <<EOF
network:
  version: 2
  tunnels:
    $tunnel_name:
      mode: sit
      local: $foreign_ip
      remote: $iran_ip
      addresses:
        - 2619:db8:85a3:1b2e:$subnet_hex::1/64
      mtu: $mtu
      routes:
        - to: 2619:db8:85a3:1b2e:$subnet_hex::2/128
          scope: link
EOF"

    sudo bash -c "cat > /etc/systemd/network/${tunnel_name}.network <<EOF
[Match]
Name=$tunnel_name

[Network]
Address=2619:db8:85a3:1b2e:$subnet_hex::1/64
Gateway=2619:db8:85a3:1b2e:$subnet_hex::2
EOF"

    echo -e "\033[1;37mIPv6 for FOREIGN tunnel: 2619:db8:85a3:1b2e:$subnet_hex::1\033[0m"

    sudo systemctl unmask systemd-networkd.service
    sudo systemctl restart systemd-networkd
    sudo netplan apply

    reboot_choice=$(ask_yes_no "Operation completed. Do you want to reboot?")
    if [ "$reboot_choice" == "yes" ]; then
        echo -e "\033[1;33mRebooting...\033[0m"
        sudo reboot
    else
        echo -e "\033[1;33mReboot required.\033[0m"
    fi
fi
