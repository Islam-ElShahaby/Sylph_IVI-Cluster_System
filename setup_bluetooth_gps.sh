#!/usr/bin/env bash
# Bind Bluetooth GPS serial for Sylph Navigation.
# The Sylph app opens /dev/rfcomm0 directly and triggers the connection.

if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[Error] Please run as root: sudo ./setup_bluetooth_gps.sh\e[0m"
  exit 1
fi

echo -e "\e[34m==================================================\e[0m"
echo -e "\e[34m    Sylph IVI Bluetooth GPS Setup Script          \e[0m"
echo -e "\e[34m==================================================\e[0m"
echo ""

echo -e "\e[36m--- Paired Bluetooth Devices ---\e[0m"
bluetoothctl devices
echo -e "\e[36m--------------------------------\e[0m"
echo ""

read -p "Enter your phone's Bluetooth MAC address (e.g., AA:BB:CC:DD:EE:FF): " PHONE_MAC

if [[ ! $PHONE_MAC =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
    echo -e "\e[31m[Error] Invalid MAC address format.\e[0m"
    exit 1
fi

echo "Cleaning up old bindings..."
rfcomm release rfcomm0 2>/dev/null
sleep 1

echo -e "\e[33mBinding /dev/rfcomm0 to $PHONE_MAC channel 8...\e[0m"
rfcomm bind rfcomm0 "$PHONE_MAC" 8

if [ $? -eq 0 ]; then
    echo -e "\e[32m[Ready] /dev/rfcomm0 bound to $PHONE_MAC channel 8\e[0m"
    echo ""
    echo "The Sylph app will connect automatically when it opens the device."
    echo "Make sure the GPS server app on your phone is running!"
    echo ""
    echo -e "\e[36mTo release: sudo rfcomm release rfcomm0\e[0m"
    # Make the device readable by everyone so the app doesn't need root
    chmod 666 /dev/rfcomm0 2>/dev/null
else
    echo -e "\e[31m[Error] Failed to bind. Is Bluetooth on?\e[0m"
    exit 1
fi
