#!/usr/bin/env bash

#A bit of Styling
RED='\033[31m'
GREEN='\033[32m'
DGREEN='\033[38;5;28m'
GREY='\033[37m'
BLUE='\033[34m'
YELLOW='\033[33m'
PURPLE='\033[35m'
PINK='\033[38;5;206m'
VIOLET='\033[0;35m'
RESET='\033[0m'
NC='\033[0m'

#Help / Usage
if [[ "$*" == "-help" ]] || [[ "$*" == "--help" ]]; then
    echo "Usage: $0 [-h | --hostname {Tailscale Machine (Device) Hostname}] [-k | --Key {TailScale API Access Token}]"
    echo ""
    echo "Options:"
    echo "-h,    --hostname         {Tailscale Machine (Device) Hostname} [Not needed if using -i (device id)]"    
    echo "-i,    --id               {Tailscale Machine (Device) ID} [Not needed if using -h (device hostname)]"
    echo "-k,    --key              {TailScale API Access Token} (https://login.tailscale.com/admin/settings/keys)"
    echo "-help, --help             Show this Help Message"
 exit 0      
fi   
#cmdline args & opts
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--hostname)
    if [ -z "$2" ]; then
      echo -e "${RED}\u2717 Error${NC} ${YELLOW}TailScale ${PINK}Machine Hostname${YELLOW} missing for option ${BLUE}'-h' | '--hostname'${NC}"
      exit 1
    fi
    DEVICE_HOSTNAME="$2"
    shift
    shift
    ;;
    -i|--id)
    if [ -z "$2" ]; then
      echo -e "${RED}\u2717 Error${NC}: ${YELLOW}TailScale ${PINK}Machine (Device) ID${YELLOW} missing for option ${BLUE}'-i' | '--id'${NC}"
      exit 1
    fi
    DEVICE_ID="$2"
    shift
    shift
    ;;
    -k|--key)
    if [ -z "$2" ]; then
      echo -e "${RED}\u2717 Error${NC}: ${YELLOW}TailScale ${PINK}API Key ${YELLOW}missing for option '-k' | '--key'${NC}"
      exit 1
    fi
    TS_API_KEY="$2"
    shift
    shift
    ;;
    *)
    echo -e "${RED}\u2717 Error${NC}: ${YELLOW}Invalid option '$key'${NC}"
    exit 1
    ;;
esac
done
#See if meets minimum requrement
if [ -z "$DEVICE_HOSTNAME" ] && [ -z "$DEVICE_ID" ]; then
   echo -e "\n${RED}\u2717 Error${NC}: ${YELLOW}Either ${PINK}Hostname${YELLOW} or ${PINK}Device ID${YELLOW} is Required${NC}"
   exit 1
fi
#Check API Key
if [ -n "${TS_API_KEY-}" ]; then
     if [ "$(curl -qsSL "https://api.tailscale.com/api/v2/device/1234?fields=all" -H "Authorization: Bearer $TS_API_KEY" -w "%{http_code}" -o /dev/null)" = "401" ]; then 
         echo -e "\n${RED}\u2717 Invalid ${YELLOW}TailScale ${PINK}API Key ${RED} 401${NC}"
         echo -e "${YELLOW}Regenerate ${PINK}API Access Token${YELLOW} --> ${BLUE}https://login.tailscale.com/admin/settings/keys${NC}\n"
       exit 1
     fi
else
   echo -e "\n${RED}\u2717 Error${NC}: ${YELLOW}TailScale ${PINK}API Key${YELLOW} is Required! ${BLUE}( -k | --key )\n${PINK}API Access Token${YELLOW} --> ${BLUE}https://login.tailscale.com/admin/settings/keys${NC}\n"
   exit 1
fi
#Main
#Get Pre-Requisite
if [ -n "$DEVICE_HOSTNAME" ] && [ -n "$TS_API_KEY" ]; then
     echo -e "\n${DGREEN}[+]${YELLOW} Machine (Device) Hostname = ${PURPLE}$DEVICE_HOSTNAME${NC}"
   #Get Device ID
     DEVICE_ID="$(curl -qfsSL "https://api.tailscale.com/api/v2/tailnet/-/devices" -H "Authorization: Bearer $TS_API_KEY" | jq --arg DEVICE_HOSTNAME "$DEVICE_HOSTNAME" '.devices | map(select(.hostname | test($DEVICE_HOSTNAME; "i")))' | jq -r '.[].id')" && export DEVICE_ID="$DEVICE_ID"
     echo -e "${DGREEN}[+]${YELLOW} Machine (Device) ID = ${PURPLE}$DEVICE_ID${NC}"
   #Get Internal Private Endpoint
     PRIVATE_IP="$(curl -qfsSL "https://api.tailscale.com/api/v2/device/$DEVICE_ID?fields=all" -H "Authorization: Bearer $TS_API_KEY" | jq -r '.clientConnectivity.endpoints[]' | awk -F: '{print $1}' | grep -Eo '^(10\.|172\.|192\.)[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -i "$CUSTOM_PREFIX")" && export PRIVATE_IP="$PRIVATE_IP"
     echo -e "${DGREEN}[+]${YELLOW} PRIVATE_IP = ${PURPLE}$PRIVATE_IP${NC}\n"
   #Export to GH ENV
    echo "$PRIVATE_IP" > "/tmp/tailscale_ddns_internal.txt"
     #echo "PRIVATE_IP=$PRIVATE_IP" >> $GITHUB_ENV 2>/dev/null     
elif [ -n "$DEVICE_ID" ] && [ -n "$TS_API_KEY" ]; then
   #Get Machine Hostname
     DEVICE_HOSTNAME="$(curl -qfsSL "https://api.tailscale.com/api/v2/device/$DEVICE_ID?fields=all" -H "Authorization: Bearer $TS_API_KEY" | jq -r '.hostname')" && export DEVICE_HOSTNAME="$DEVICE_HOSTNAME"
     echo -e "\n${DGREEN}[+]${YELLOW} Machine (Device) Hostname = ${PURPLE}$DEVICE_HOSTNAME${NC}"
   #Get Device ID
     echo -e "${DGREEN}[+]${YELLOW} Machine (Device) ID = ${PURPLE}$DEVICE_ID${NC}"
   #Get Internal Private Endpoint
     PRIVATE_IP="$(curl -qfsSL "https://api.tailscale.com/api/v2/device/$DEVICE_ID?fields=all" -H "Authorization: Bearer $TS_API_KEY" | jq -r '.clientConnectivity.endpoints[]' | awk -F: '{print $1}' | grep -Eo '^(10\.|172\.|192\.)[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -i "$CUSTOM_PREFIX" )" && export PRIVATE_IP="$PRIVATE_IP"
     echo -e "${DGREEN}[+]${YELLOW} PRIVATE_IP = ${PURPLE}$PRIVATE_IP\n"
   #Export to GH ENV
    echo "$PRIVATE_IP" > "/tmp/tailscale_ddns_internal.txt"
     #echo "PRIVATE_IP=$PRIVATE_IP" >> $GITHUB_ENV 2>/dev/null
fi
#EOF
