#!/bin/bash
# @author madebycm (2025)
# Interactive Hetzner Cloud API script to manage servers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to load defaults from file
load_defaults() {
    local defaults_file="$(dirname "$0")/defaults.txt"
    if [ -f "$defaults_file" ]; then
        # Source the defaults file, ignoring comments and empty lines
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^#.*$ ]] && continue
            [[ -z $key ]] && continue
            # Export the variable
            export "DEFAULT_$key"="$value"
        done < "$defaults_file"
    else
        echo -e "${YELLOW}Warning: defaults.txt not found, using hardcoded defaults${NC}"
        # Hardcoded fallback defaults
        export DEFAULT_SERVER_TYPE="cx22"
        export DEFAULT_IMAGE="ubuntu-24.04"
        export DEFAULT_LOCATION="hel1"
        export DEFAULT_SSH_KEY="majn0923@cm"
        export DEFAULT_START_AFTER_CREATE="true"
        export DEFAULT_DEFAULT_NAME_PREFIX="server"
    fi
}

# Function to validate post-install commands
validate_postinstall_commands() {
    local postinstall_file="$1"
    local errors=0
    
    if [ ! -f "$postinstall_file" ]; then
        echo -e "${YELLOW}No post-install commands file found at: $postinstall_file${NC}"
        return 0  # Not an error, just no commands to run
    fi
    
    echo -e "${BLUE}Validating post-install commands...${NC}"
    
    # Read and validate each command
    local line_num=0
    while IFS= read -r line; do
        line_num=$((line_num + 1))
        
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$(echo "$line" | tr -d '[:space:]')" ]]; then
            continue
        fi
        
        # Basic syntax check using bash -n
        if ! echo "$line" | bash -n 2>/dev/null; then
            echo -e "${RED}Syntax error in line $line_num: $line${NC}"
            errors=$((errors + 1))
        else
            echo -e "${GREEN}✓${NC} Line $line_num: $(echo "$line" | cut -c1-60)..."
        fi
        
        # Check for common issues
        if [[ "$line" =~ \\ ]]; then
            echo -e "${YELLOW}Warning: Line $line_num contains backslash - line continuations may not work over SSH${NC}"
        fi
        
        # Check for sudo without -n or password
        if [[ "$line" =~ sudo ]] && ! [[ "$line" =~ "sudo -n" ]] && ! [[ "$line" =~ "DEBIAN_FRONTEND=noninteractive" ]]; then
            echo -e "${YELLOW}Warning: Line $line_num uses sudo which may prompt for password${NC}"
        fi
        
        # Check for interactive commands
        if [[ "$line" =~ "(apt-get|apt)" ]] && ! [[ "$line" =~ "-y" ]]; then
            echo -e "${YELLOW}Warning: Line $line_num may require interaction (missing -y flag)${NC}"
        fi
    done < "$postinstall_file"
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}Found $errors syntax error(s) in post-install commands${NC}"
        return 1
    else
        echo -e "${GREEN}All post-install commands validated successfully${NC}"
        return 0
    fi
}

# Function to show usage
show_usage() {
    echo -e "${BLUE}Hetzner Cloud Manager${NC}"
    echo ""
    echo "Usage:"
    echo "  $0                    # Login mode (list servers to choose from)"
    echo "  $0 <servername>       # Direct SSH to server"
    echo "  $0 --auto --name NAME # Auto-create server with specified name"
    echo "  $0 --interactive      # Interactive menu mode"
    echo "  $0 --login [NAME]     # SSH to server (list if no name provided)"
    echo "  $0 --delete [NAME]    # Delete server (interactive if no name)"
    echo "  $0 --help            # Show this help"
    echo ""
    echo "Environment variables:"
    echo "  HETZNER_API_TOKEN     # Required: Your Hetzner Cloud API token"
    echo ""
    echo "Auto mode uses defaults from defaults.txt:"
    echo "  Server Type: $DEFAULT_SERVER_TYPE"
    echo "  Image: $DEFAULT_IMAGE"
    echo "  Location: $DEFAULT_LOCATION"
    echo "  SSH Key: $DEFAULT_SSH_KEY"
}

# Parse command line arguments
AUTO_MODE=false
LOGIN_MODE=false
INTERACTIVE_MODE=false
DELETE_MODE=false
SERVER_NAME=""

# If no arguments, default to login mode
if [ $# -eq 0 ]; then
    LOGIN_MODE=true
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
            LOGIN_MODE=false
            shift
            ;;
        --name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --login)
            LOGIN_MODE=true
            if [[ $# -gt 1 && ! $2 =~ ^-- ]]; then
                SERVER_NAME="$2"
                shift 2
            else
                shift
            fi
            ;;
        --interactive)
            INTERACTIVE_MODE=true
            LOGIN_MODE=false
            shift
            ;;
        --delete)
            DELETE_MODE=true
            LOGIN_MODE=false
            if [[ $# -gt 1 && ! $2 =~ ^-- ]]; then
                SERVER_NAME="$2"
                shift 2
            else
                shift
            fi
            ;;
        --help|-h)
            load_defaults
            show_usage
            exit 0
            ;;
        --*)
            echo -e "${RED}Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
        *)
            # If it's not an option, treat it as server name for login
            SERVER_NAME="$1"
            LOGIN_MODE=true
            shift
            ;;
    esac
done

# Load defaults
load_defaults

# Check if API token is provided
if [ -z "$HETZNER_API_TOKEN" ]; then
    echo -e "${RED}Error: HETZNER_API_TOKEN environment variable is not set${NC}"
    echo -e "${YELLOW}Usage: export HETZNER_API_TOKEN='your_api_token_here' && ./hetzner.sh${NC}"
    echo -e "${YELLOW}Or: HETZNER_API_TOKEN='your_api_token_here' ./hetzner.sh${NC}"
    exit 1
fi


# API base URL
API_BASE="https://api.hetzner.cloud/v1"

# Function to make API requests
make_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [ "$method" = "POST" ]; then
        curl -s -X POST -H "Authorization: Bearer $HETZNER_API_TOKEN" -H "Content-Type: application/json" -d "$data" "$API_BASE$endpoint"
    elif [ "$method" = "DELETE" ]; then
        curl -s -X DELETE -H "Authorization: Bearer $HETZNER_API_TOKEN" "$API_BASE$endpoint"
    else
        curl -s -H "Authorization: Bearer $HETZNER_API_TOKEN" "$API_BASE$endpoint"
    fi
}

# Function to check API response for errors
check_api_error() {
    local response="$1"
    # Check for actual error object (not null error fields)
    local error_check=$(echo "$response" | jq -r '.error // empty')
    if [ -n "$error_check" ] && [ "$error_check" != "null" ]; then
        echo -e "${RED}API Error:${NC}"
        echo "$response" | jq '.error'
        return 1
    fi
    return 0
}

# Function to handle login using API
handle_login() {
    echo -e "${BLUE}Fetching servers from Hetzner Cloud API...${NC}"
    
    local response=$(make_api_request "GET" "/servers")
    if ! check_api_error "$response"; then
        echo -e "${RED}Failed to fetch servers from API${NC}"
        exit 1
    fi
    
    local server_count=$(echo "$response" | jq '.servers | length')
    
    if [ "$server_count" -eq 0 ]; then
        echo -e "${YELLOW}No servers found in your Hetzner Cloud project${NC}"
        exit 1
    fi
    
    if [ -n "$SERVER_NAME" ]; then
        # Direct login to specified server
        local server_data=$(echo "$response" | jq -r ".servers[] | select(.name == \"$SERVER_NAME\") | \"\(.name)|\(.public_net.ipv4.ip // \"N/A\")|\(.status)\"")
        
        if [ -z "$server_data" ]; then
            echo -e "${RED}Server '$SERVER_NAME' not found${NC}"
            echo -e "${YELLOW}Available servers:${NC}"
            echo "$response" | jq -r '.servers[] | "  \(.name) (\(.public_net.ipv4.ip // "N/A"))"'
            exit 1
        fi
        
        local server_ip=$(echo "$server_data" | cut -d'|' -f2)
        local server_status=$(echo "$server_data" | cut -d'|' -f3)
        
        if [ "$server_status" != "running" ]; then
            echo -e "${YELLOW}Warning: Server '$SERVER_NAME' is not running (status: $server_status)${NC}"
        fi
        
        if [ "$server_ip" = "N/A" ]; then
            echo -e "${RED}Server '$SERVER_NAME' has no public IP${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}Connecting to $SERVER_NAME ($server_ip)...${NC}"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$server_ip
    else
        # Show list and let user choose
        echo -e "${BLUE}Available servers:${NC}"
        echo ""
        printf "%-15s %-15s %-12s %-10s\\n" "NAME" "IP" "TYPE" "STATUS"
        printf "%-15s %-15s %-12s %-10s\\n" "----" "--" "----" "------"
        
        echo "$response" | jq -r '.servers[] | "\(.name)|\(.public_net.ipv4.ip // "N/A")|\(.server_type.name)|\(.status)"' | \
        while IFS='|' read -r name ip type status; do
            printf "%-15s %-15s %-12s %-10s\\n" "$name" "$ip" "$type" "$status"
        done
        
        echo ""
        read -p "Enter server name to connect: " selected_server
        
        if [ -z "$selected_server" ]; then
            echo -e "${YELLOW}No server selected${NC}"
            exit 0
        fi
        
        local selected_data=$(echo "$response" | jq -r ".servers[] | select(.name == \"$selected_server\") | \"\(.name)|\(.public_net.ipv4.ip // \"N/A\")|\(.status)\"")
        
        if [ -z "$selected_data" ]; then
            echo -e "${RED}Server '$selected_server' not found${NC}"
            exit 1
        fi
        
        local selected_ip=$(echo "$selected_data" | cut -d'|' -f2)
        local selected_status=$(echo "$selected_data" | cut -d'|' -f3)
        
        if [ "$selected_status" != "running" ]; then
            echo -e "${YELLOW}Warning: Server '$selected_server' is not running (status: $selected_status)${NC}"
        fi
        
        if [ "$selected_ip" = "N/A" ]; then
            echo -e "${RED}Server '$selected_server' has no public IP${NC}"
            exit 1
        fi
        
        echo -e "${BLUE}Connecting to $selected_server ($selected_ip)...${NC}"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$selected_ip
    fi
}

# Function to list servers
list_servers() {
    echo -e "${BLUE}Fetching Hetzner Cloud servers...${NC}"
    echo ""
    
    local response=$(make_api_request "GET" "/servers")
    
    if ! check_api_error "$response"; then
        return 1
    fi
    
    local server_count=$(echo "$response" | jq '.servers | length')
    
    if [ "$server_count" -eq 0 ]; then
        echo -e "${YELLOW}No servers found in your Hetzner Cloud project${NC}"
    else
        echo -e "${GREEN}Found $server_count server(s):${NC}"
        echo ""
        
        printf "%-10s %-20s %-12s %-12s %-15s %-12s %-8s\n" "ID" "NAME" "TYPE" "STATUS" "PUBLIC_IP" "LOCATION" "COST/MO"
        printf "%-10s %-20s %-12s %-12s %-15s %-12s %-8s\n" "--" "----" "----" "------" "---------" "--------" "-------"
        
        echo "$response" | jq -r '.servers[] | "\(.id)\t\(.name)\t\(.server_type.name)\t\(.status)\t\(.public_net.ipv4.ip // "N/A")\t\(.datacenter.location.name)\t€\(.server_type.prices[] | select(.location == "fsn1") | .price_monthly.gross)"' | \
        while IFS=$'\t' read -r id name type status ip location cost; do
            printf "%-10s %-20s %-12s %-12s %-15s %-12s %-8s\n" "$id" "$name" "$type" "$status" "$ip" "$location" "$cost"
        done
    fi
    
    echo ""
    echo -e "${BLUE}Total servers: $server_count${NC}"
}

# Function to get available locations
get_locations() {
    local response=$(make_api_request "GET" "/locations")
    if check_api_error "$response"; then
        echo "$response" | jq -r '.locations[] | "\(.name)\t\(.description)"'
    fi
}

# Function to get available images
get_images() {
    local response=$(make_api_request "GET" "/images?type=system")
    if check_api_error "$response"; then
        echo "$response" | jq -r '.images[] | select(.status == "available") | "\(.name)\t\(.description)"' | head -10
    fi
}

# Function to get SSH public key
get_ssh_public_key() {
    local ssh_key_path="$HOME/.ssh/id_rsa.pub"
    if [ -f "$ssh_key_path" ]; then
        cat "$ssh_key_path"
    else
        echo ""
    fi
}

# Function to create CX22 server automatically with defaults
auto_create_cx22() {
    echo -e "${BLUE}Auto-creating CX22 server with default configuration...${NC}"
    echo ""
    
    # Get server name from user
    read -p "Enter server name: " server_name
    if [ -z "$server_name" ]; then
        echo -e "${RED}Server name is required${NC}"
        return 1
    fi
    
    local location="$DEFAULT_LOCATION"
    local image="$DEFAULT_IMAGE"
    local ssh_key_name="$DEFAULT_SSH_KEY"
    
    # Build JSON payload
    local json_data="{"
    json_data+="\"name\": \"$server_name\","
    json_data+="\"server_type\": \"cx22\","
    json_data+="\"image\": \"$image\","
    json_data+="\"location\": \"$location\","
    json_data+="\"start_after_create\": true,"
    json_data+="\"ssh_keys\": [\"$ssh_key_name\"]"
    
    json_data+="}"
    
    echo -e "${YELLOW}Creating server with the following configuration:${NC}"
    echo "Name: $server_name"
    echo "Type: CX22 (4GB RAM, 2 vCPU, 40GB SSD, €4.15/month)"
    echo "Image: $image"
    echo "Location: $location"
    echo "SSH Key: $ssh_key_name"
    echo ""
    
    echo -e "${BLUE}Creating server...${NC}"
    local response=$(make_api_request "POST" "/servers" "$json_data")
    
    if check_api_error "$response"; then
        local server_id=$(echo "$response" | jq -r '.server.id')
        local server_ip=$(echo "$response" | jq -r '.server.public_net.ipv4.ip // "N/A"')
        echo -e "${GREEN}Server created successfully!${NC}"
        echo "Server ID: $server_id"
        echo "Server IP: $server_ip"
        echo "Status: Creating (will be available shortly)"
        echo ""
        echo -e "${GREEN}You can SSH to the server once it's ready:${NC}"
        echo "ssh root@$server_ip"
    else
        echo -e "${RED}Failed to create server${NC}"
        return 1
    fi
}

# Function to create CX22 server
create_cx22_server() {
    echo -e "${BLUE}Creating new CX22 server...${NC}"
    echo ""
    
    # Get server name
    read -p "Enter server name (must be unique): " server_name
    if [ -z "$server_name" ]; then
        echo -e "${RED}Server name is required${NC}"
        return 1
    fi
    
    # Show available locations
    echo -e "${YELLOW}Available locations:${NC}"
    get_locations | while IFS=$'\t' read -r name desc; do
        printf "  %-8s - %s\n" "$name" "$desc"
    done
    echo ""
    
    read -p "Enter location (default: fsn1): " location
    location=${location:-fsn1}
    
    # Show available images
    echo -e "${YELLOW}Popular images:${NC}"
    get_images | while IFS=$'\t' read -r name desc; do
        printf "  %-15s - %s\n" "$name" "$desc"
    done
    echo ""
    
    read -p "Enter image (default: ubuntu-22.04): " image
    image=${image:-ubuntu-22.04}
    
    read -p "Add SSH key name (optional): " ssh_key
    
    # Build JSON payload
    local json_data="{"
    json_data+="\"name\": \"$server_name\","
    json_data+="\"server_type\": \"cx22\","
    json_data+="\"image\": \"$image\","
    json_data+="\"location\": \"$location\","
    json_data+="\"start_after_create\": true"
    
    if [ -n "$ssh_key" ]; then
        json_data+=",\"ssh_keys\": [\"$ssh_key\"]"
    fi
    
    json_data+="}"
    
    echo -e "${YELLOW}Creating server with the following configuration:${NC}"
    echo "Name: $server_name"
    echo "Type: CX22 (4GB RAM, 2 vCPU, 40GB SSD, €4.15/month)"
    echo "Image: $image"
    echo "Location: $location"
    if [ -n "$ssh_key" ]; then
        echo "SSH Key: $ssh_key"
    fi
    echo ""
    
    read -p "Confirm creation? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Server creation cancelled${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Creating server...${NC}"
    local response=$(make_api_request "POST" "/servers" "$json_data")
    
    if check_api_error "$response"; then
        local server_id=$(echo "$response" | jq -r '.server.id')
        local server_ip=$(echo "$response" | jq -r '.server.public_net.ipv4.ip // "N/A"')
        echo -e "${GREEN}Server created successfully!${NC}"
        echo "Server ID: $server_id"
        echo "Server IP: $server_ip"
        echo "Status: Creating (will be available shortly)"
        
    else
        echo -e "${RED}Failed to create server${NC}"
        return 1
    fi
}

# Function to delete server
delete_server() {
    echo -e "${BLUE}Delete Server${NC}"
    echo ""
    
    # First list servers to show available options
    local response=$(make_api_request "GET" "/servers")
    
    if ! check_api_error "$response"; then
        return 1
    fi
    
    local server_count=$(echo "$response" | jq '.servers | length')
    
    if [ "$server_count" -eq 0 ]; then
        echo -e "${YELLOW}No servers found to delete${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Available servers:${NC}"
    printf "%-10s %-20s %-12s %-12s %-15s\n" "ID" "NAME" "TYPE" "STATUS" "IP"
    printf "%-10s %-20s %-12s %-12s %-15s\n" "--" "----" "----" "------" "--"
    
    echo "$response" | jq -r '.servers[] | "\(.id)\t\(.name)\t\(.server_type.name)\t\(.status)\t\(.public_net.ipv4.ip // "N/A")"' | \
    while IFS=$'\t' read -r id name type status ip; do
        printf "%-10s %-20s %-12s %-12s %-15s\n" "$id" "$name" "$type" "$status" "$ip"
    done
    
    echo ""
    read -p "Enter server ID to delete (or 'cancel' to abort): " server_id
    
    if [ "$server_id" = "cancel" ] || [ -z "$server_id" ]; then
        echo -e "${YELLOW}Delete operation cancelled${NC}"
        return 0
    fi
    
    # Validate server ID exists
    local server_exists=$(echo "$response" | jq -r ".servers[] | select(.id == $server_id) | .name")
    if [ -z "$server_exists" ]; then
        echo -e "${RED}Error: Server ID $server_id not found${NC}"
        return 1
    fi
    
    local server_name=$(echo "$response" | jq -r ".servers[] | select(.id == $server_id) | .name")
    local server_type=$(echo "$response" | jq -r ".servers[] | select(.id == $server_id) | .server_type.name")
    local server_ip=$(echo "$response" | jq -r ".servers[] | select(.id == $server_id) | .public_net.ipv4.ip // \"N/A\"")
    
    echo -e "${RED}WARNING: This will permanently delete the following server:${NC}"
    echo "ID: $server_id"
    echo "Name: $server_name"
    echo "Type: $server_type"
    echo "IP: $server_ip"
    echo ""
    echo -e "${RED}This action CANNOT be undone!${NC}"
    echo ""
    
    read -p "Type 'DELETE' to confirm deletion: " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        echo -e "${YELLOW}Delete operation cancelled${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Deleting server...${NC}"
    local delete_response=$(make_api_request "DELETE" "/servers/$server_id")
    
    # For DELETE requests, success usually returns empty response or action object
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Server $server_name (ID: $server_id) deleted successfully!${NC}"
        echo -e "${YELLOW}Note: It may take a few moments for the server to be completely removed${NC}"
    else
        echo -e "${RED}Failed to delete server${NC}"
        if [ -n "$delete_response" ]; then
            echo "Response: $delete_response"
        fi
        return 1
    fi
}

# Function to show main menu
show_menu() {
    echo -e "${BLUE}=== Hetzner Cloud Manager ===${NC}"
    echo ""
    echo "1. List all servers"
    echo "2. Create new CX22 server (interactive)"
    echo "3. Auto-create CX22 server (ubuntu-24.04/hel1/~/.ssh/id_rsa.pub)"
    echo "4. Delete server"
    echo "5. Exit"
    echo ""
    read -p "Select an option (1-5): " choice
    echo ""
    
    case $choice in
        1)
            list_servers
            ;;
        2)
            create_cx22_server
            ;;
        3)
            auto_create_cx22
            ;;
        4)
            delete_server
            ;;
        5)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-5.${NC}"
            ;;
    esac
}

# Handle login mode
if [ "$LOGIN_MODE" = true ]; then
    handle_login
    exit 0
fi

# Handle auto mode
if [ "$AUTO_MODE" = true ]; then
    if [ -z "$SERVER_NAME" ]; then
        echo -e "${RED}Error: --name is required when using --auto mode${NC}"
        show_usage
        exit 1
    fi
    
    echo -e "${BLUE}Auto-creating server: $SERVER_NAME${NC}"
    
    # Validate post-install commands first
    postinstall_file="$(dirname "$0")/auto-postinstall-commands.txt"
    if ! validate_postinstall_commands "$postinstall_file"; then
        echo -e "${RED}Post-install command validation failed. Please fix the errors before creating the server.${NC}"
        exit 1
    fi
    echo ""
    
    # Use defaults from file
    location="$DEFAULT_LOCATION"
    image="$DEFAULT_IMAGE"
    ssh_key_name="$DEFAULT_SSH_KEY"
    server_type="$DEFAULT_SERVER_TYPE"
    
    # Build JSON payload
    json_data="{"
    json_data+="\"name\": \"$SERVER_NAME\","
    json_data+="\"server_type\": \"$server_type\","
    json_data+="\"image\": \"$image\","
    json_data+="\"location\": \"$location\","
    json_data+="\"start_after_create\": $DEFAULT_START_AFTER_CREATE,"
    json_data+="\"ssh_keys\": [\"$ssh_key_name\"]"
    json_data+="}"
    
    echo -e "${YELLOW}Creating server with configuration:${NC}"
    echo "Name: $SERVER_NAME"
    echo "Type: $server_type"
    echo "Image: $image"
    echo "Location: $location"
    echo "SSH Key: $ssh_key_name"
    echo ""
    
    echo -e "${BLUE}Creating server...${NC}"
    response=$(make_api_request "POST" "/servers" "$json_data")
    
    if check_api_error "$response"; then
        server_id=$(echo "$response" | jq -r '.server.id')
        server_ip=$(echo "$response" | jq -r '.server.public_net.ipv4.ip // "N/A"')
        echo -e "${GREEN}Server created successfully!${NC}"
        echo "Server ID: $server_id"
        echo "Server IP: $server_ip"
        echo "Status: Creating (will be available shortly)"
        echo ""
        
        
        # Wait for SSH to become available and run post-install commands
        echo -e "${BLUE}Waiting for SSH connectivity...${NC}"
        ssh_attempts=0
        max_attempts=60  # 5 minutes max (60 * 5 seconds)
        
        while [ $ssh_attempts -lt $max_attempts ]; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$server_ip "echo 'SSH connection successful'" >/dev/null 2>&1; then
                echo -e "${GREEN}SSH connection established!${NC}"
                break
            else
                echo -n "."
                sleep 5
                ssh_attempts=$((ssh_attempts + 1))
            fi
        done
        
        if [ $ssh_attempts -eq $max_attempts ]; then
            echo -e "${RED}Failed to establish SSH connection after 5 minutes${NC}"
            echo -e "${YELLOW}You can manually SSH later: ssh root@$server_ip${NC}"
        else
            # Execute post-install commands if file exists
            postinstall_file="$(dirname "$0")/auto-postinstall-commands.txt"
            if [ -f "$postinstall_file" ]; then
                echo -e "${BLUE}Running post-install commands...${NC}"
                
                # Create a single script with all commands and execute it
                temp_script="/tmp/postinstall_commands.sh"
                
                # Build the script content
                script_content="#!/bin/bash\n"
                script_content+="export CLOUDPANEL_ADMIN_USERNAME='$DEFAULT_CLOUDPANEL_ADMIN_USERNAME'\n"
                script_content+="export CLOUDPANEL_ADMIN_PASSWORD='$DEFAULT_CLOUDPANEL_ADMIN_PASSWORD'\n"
                script_content+="export CLOUDPANEL_ADMIN_EMAIL='$DEFAULT_CLOUDPANEL_ADMIN_EMAIL'\n"
                script_content+="export CLOUDPANEL_ADMIN_FIRSTNAME='$DEFAULT_CLOUDPANEL_ADMIN_FIRSTNAME'\n"
                script_content+="export CLOUDPANEL_ADMIN_LASTNAME='$DEFAULT_CLOUDPANEL_ADMIN_LASTNAME'\n"
                script_content+="export CLOUDPANEL_ADMIN_TIMEZONE='$DEFAULT_CLOUDPANEL_ADMIN_TIMEZONE'\n\n"
                
                # Add each command from the post-install file
                while IFS= read -r cmd; do
                    if [[ ! "$cmd" =~ ^[[:space:]]*# ]] && [[ -n "$(echo "$cmd" | tr -d '[:space:]')" ]]; then
                        echo -e "${YELLOW}Adding command: $cmd${NC}"
                        script_content+="echo 'Executing: $cmd'\n"
                        script_content+="$cmd\n"
                        script_content+="echo 'Command completed'\n\n"
                    fi
                done < "$postinstall_file"
                
                # Write script to temp file and execute
                echo -e "$script_content" > "$temp_script"
                chmod +x "$temp_script"
                
                echo -e "${BLUE}Uploading and executing post-install script...${NC}"
                scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$temp_script" root@$server_ip:/tmp/postinstall.sh
                ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$server_ip "chmod +x /tmp/postinstall.sh && /tmp/postinstall.sh"
                
                # Clean up
                rm -f "$temp_script"
                
                echo -e "${GREEN}Post-install commands completed!${NC}"
            else
                echo -e "${YELLOW}No auto-postinstall-commands.txt found, skipping post-install${NC}"
            fi
            
            echo ""
            echo -e "${GREEN}Server setup complete! You can now SSH:${NC}"
            echo "ssh root@$server_ip"
        fi
    else
        echo -e "${RED}Failed to create server${NC}"
        exit 1
    fi
    
    exit 0
fi

# Handle delete mode
if [ "$DELETE_MODE" = true ]; then
    if [ -n "$SERVER_NAME" ]; then
        # Direct delete by name
        echo -e "${BLUE}Looking up server: $SERVER_NAME${NC}"
        response=$(make_api_request "GET" "/servers")
        
        if ! check_api_error "$response"; then
            echo -e "${RED}Failed to fetch servers${NC}"
            exit 1
        fi
        
        server_id=$(echo "$response" | jq -r ".servers[] | select(.name == \"$SERVER_NAME\") | .id")
        
        if [ -z "$server_id" ]; then
            echo -e "${RED}Server '$SERVER_NAME' not found${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}Found server '$SERVER_NAME' (ID: $server_id)${NC}"
        echo -e "${RED}This will permanently delete the server. Type 'DELETE' to confirm:${NC}"
        read confirm
        
        if [ "$confirm" = "DELETE" ]; then
            echo -e "${BLUE}Deleting server...${NC}"
            delete_response=$(make_api_request "DELETE" "/servers/$server_id")
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Server '$SERVER_NAME' deleted successfully!${NC}"
            else
                echo -e "${RED}Failed to delete server${NC}"
            fi
        else
            echo -e "${YELLOW}Delete cancelled${NC}"
        fi
    else
        # Interactive delete
        delete_server
    fi
    exit 0
fi

# Handle interactive mode
if [ "$INTERACTIVE_MODE" = true ]; then
    # Main interactive loop
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue or Ctrl+C to exit..."
        clear
    done
fi