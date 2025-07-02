#!/bin/bash
# @author madebycm (2025)
# Hetzner Cloud API script to list all available servers using API key

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if API token is provided
if [ -z "$HETZNER_API_TOKEN" ]; then
    echo -e "${RED}Error: HETZNER_API_TOKEN environment variable is not set${NC}"
    echo -e "${YELLOW}Usage: export HETZNER_API_TOKEN='your_api_token_here' && ./hetzner.sh${NC}"
    echo -e "${YELLOW}Or: HETZNER_API_TOKEN='your_api_token_here' ./hetzner.sh${NC}"
    exit 1
fi

# API endpoint
API_URL="https://api.hetzner.cloud/v1/servers"

echo -e "${BLUE}Fetching Hetzner Cloud servers...${NC}"
echo ""

# Make API request
response=$(curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" "$API_URL")

# Check if curl command was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to connect to Hetzner Cloud API${NC}"
    exit 1
fi

# Check if response contains error
if echo "$response" | grep -q '"error"'; then
    echo -e "${RED}API Error:${NC}"
    echo "$response" | jq '.error // .'
    exit 1
fi

# Parse and display server information
server_count=$(echo "$response" | jq '.servers | length')

if [ "$server_count" -eq 0 ]; then
    echo -e "${YELLOW}No servers found in your Hetzner Cloud project${NC}"
else
    echo -e "${GREEN}Found $server_count server(s):${NC}"
    echo ""
    
    # Display servers in a formatted table
    printf "%-15s %-20s %-15s %-12s %-15s %-10s\n" "ID" "NAME" "TYPE" "STATUS" "PUBLIC_IP" "LOCATION"
    printf "%-15s %-20s %-15s %-12s %-15s %-10s\n" "---" "----" "----" "------" "---------" "--------"
    
    echo "$response" | jq -r '.servers[] | "\(.id)\t\(.name)\t\(.server_type.name)\t\(.status)\t\(.public_net.ipv4.ip // "N/A")\t\(.datacenter.location.name)"' | \
    while IFS=$'\t' read -r id name type status ip location; do
        printf "%-15s %-20s %-15s %-12s %-15s %-10s\n" "$id" "$name" "$type" "$status" "$ip" "$location"
    done
fi

echo ""
echo -e "${BLUE}Total servers: $server_count${NC}"