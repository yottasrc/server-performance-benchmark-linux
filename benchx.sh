#!/usr/bin/env bash
# ==========================================================
#   BenchX v1.4 – Modern Server Benchmark (YottaSrc Inc.)
# ==========================================================

# -----------------------------
# Terminal Capability Check
# -----------------------------
supports_unicode() {
    case "$LANG" in *UTF-8*|*utf8*) return 0 ;; esac
    [[ "$TERM" =~ xterm|screen|tmux ]] && return 0
    return 1
}

# -----------------------------
# Visual Settings
# -----------------------------
BOX_WIDTH=70

if supports_unicode; then
    BOX_TL="╔"; BOX_TR="╗"; BOX_BL="╚"; BOX_BR="╝"
    BOX_H="═"; BOX_V="║"; ARROW="➤"
else
    BOX_TL="+"; BOX_TR="+"; BOX_BL="+"; BOX_BR="+"; BOX_H="-"; BOX_V="|"; ARROW=">"
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; RESET='\033[0m'; BOLD='\033[1m'

# -----------------------------
# Box Drawing
# -----------------------------
box_open() {
    printf "\n${MAGENTA}${BOX_TL}"
    for ((i=1;i<=BOX_WIDTH;i++)); do printf "%s" "$BOX_H"; done
    printf "${BOX_TR}${RESET}\n"
}
box_line() {
    printf "${CYAN}${BOX_V}${RESET} "
    printf "${BOLD}%b${RESET}\n" "$1"
}

box_end() {
    printf "${MAGENTA}${BOX_BL}"
    for ((i=1;i<=BOX_WIDTH;i++)); do printf "%s" "$BOX_H"; done
    printf "${BOX_BR}${RESET}\n"
}

wrap_box_text() {
    local text="$1"
    local width=70   # inside-box width
    local color_start="${YELLOW}"
    local color_end="${RESET}"

    # Remove ending RESET if provided
    text="${text%$RESET}"

    while [[ ${#text} -gt $width ]]; do
        # Slice safe-width chunk
        local part="${text:0:$width}"
        box_line "${color_start}${part}${color_end}"

        # Remove printed part
        text="${text:$width}"
    done

    # Print last line
    box_line "${color_start}${text}${color_end}"
}


get_ip_info() {
    # Detect IPv4
    IPV4=$(ip -4 addr show | awk '/inet / && $2 !~ /^127/ {print $2}' | cut -d/ -f1 | head -n1)
    [[ -z "$IPV4" ]] && IPV4="No IPv4 detected"

    # Detect IPv6
    IPV6=$(ip -6 addr show | awk '/inet6/ && $2 !~ /^::1/ && $2 !~ /^fe80/ {print $2}' | cut -d/ -f1 | head -n1)
    [[ -z "$IPV6" ]] && IPV6="No IPv6 detected"
}

center_text() {
    local text="$1"
    local width=$BOX_WIDTH

    # Remove color escape codes for length calc
    local clean=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')

    local pad=$(( (width - ${#clean}) / 2 ))

    printf "${MAGENTA}${BOX_V}${RESET} "
    printf "%*s%b%*s" "$pad" "" "$text" "$pad" ""
    printf "\n"
}


# -----------------------------
# Convert GIB to GB, MIB to MB
# -----------------------------
convert_mem_unit() {
    local value="$1"

    # Extract number and unit separately
    local num=$(echo "$value" | grep -oE '[0-9.]+')
    local unit=$(echo "$value" | grep -oE '[A-Za-z]+')

    case "$unit" in
        Ki) num=$(awk "BEGIN{print $num/1.024}") ; unit="KB" ;;
        Mi) num=$(awk "BEGIN{print $num/1.024}") ; unit="MB" ;;
        Gi) num=$(awk "BEGIN{print $num/1.024}") ; unit="GB" ;;
        Ti) num=$(awk "BEGIN{print $num/1.024}") ; unit="TB" ;;
        B)  ;; # do nothing
        *)
            # Unknown unit → print raw
            echo "$value"
            return
        ;;
    esac

    printf "%.2f%s" "$num" "$unit"
}


# -----------------------------
# System Information
# -----------------------------
get_info() {
    CPU_MODEL=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')
    CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
    CPU_FREQ=$(awk -F: '/cpu MHz/ {print $2; exit}' /proc/cpuinfo | sed 's/^ //')

    CPU_AES=$(grep -qi aes /proc/cpuinfo && echo "Enabled" || echo "Disabled")
    CPU_VIRT=$(grep -qiE 'vmx|svm' /proc/cpuinfo && echo "Enabled" || echo "Disabled")

    RAW_MEM_TOTAL=$(free -h | awk '/Mem/ {print $2}')
    RAW_MEM_USED=$(free -h | awk '/Mem/ {print $3}')

    MEM_TOTAL=$(convert_mem_unit "$RAW_MEM_TOTAL")
    MEM_USED=$(convert_mem_unit "$RAW_MEM_USED")

    DISK_TOTAL=$(df -h --total | awk '/total/ {print $2}')
    DISK_USED=$(df -h --total | awk '/total/ {print $3}')

    OS=$(awk -F= '/PRETTY_NAME/ {print $2}' /etc/os-release | tr -d '"')
    KERN=$(uname -r)
    ARCH=$(uname -m)
    UPTIME=$(uptime -p | sed 's/up //')
    LOAD=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')

    ORG=$(wget -qO- http://ipinfo.io/org)
    CITY=$(wget -qO- http://ipinfo.io/city)
    REGION=$(wget -qO- http://ipinfo.io/region)
    COUNTRY=$(wget -qO- http://ipinfo.io/country)
}


# -----------------------------
# RAID Information
# -----------------------------

detect_raid() {
    RAID_INFO=""

    ############################
    # Detect Linux Software RAID (mdadm)
    ############################
    if cat /proc/mdstat | grep -q "md"; then
        RAID_INFO+="Software RAID detected:\n"

        while read -r line; do
            if [[ "$line" =~ ^md ]]; then
                ARRAY=$(echo "$line" | awk '{print $1}')
                LEVEL=$(echo "$line" | grep -o "raid[0-9]\+")
                STATUS=$(echo "$line")
                RAID_INFO+=" - $ARRAY ($LEVEL) : $STATUS\n"
            fi
        done < <(grep -E "^md" /proc/mdstat)
    fi

    ############################
    # Detect LSI / MegaRAID Hardware RAID
    ############################
    if command -v storcli >/dev/null 2>&1; then
        CTRL=$(storcli show | grep -o "Controller = [0-9]" | awk '{print $3}')
        if [[ -n "$CTRL" ]]; then
            RAID_INFO+="Hardware RAID (LSI/StorCLI) detected:\n"
            RAID_INFO+="$(storcli /${CTRL}/vall show | sed 's/^/  /')\n"
        fi
    elif command -v megacli >/dev/null 2>&1; then
        RAID_INFO+="Hardware RAID (MegaCLI) detected:\n"
        RAID_INFO+="$(megacli -CfgDsply -aALL | sed 's/^/  /')\n"
    fi

    ############################
    # Detect Dell PERC RAID
    ############################
    if command -v omreport >/dev/null 2>&1; then
        RAID_INFO+="Hardware RAID (Dell PERC) detected:\n"
        RAID_INFO+="$(omreport storage vdisk | sed 's/^/  /')\n"
    fi

    ############################
    # Detect ZFS RAID
    ############################
    if command -v zpool >/dev/null 2>&1; then
        if zpool list >/dev/null 2>&1; then
            RAID_INFO+="ZFS storage detected:\n"
            RAID_INFO+="$(zpool status | sed 's/^/  /')\n"
        fi
    fi

    ############################
    # If nothing found
    ############################
    if [[ -z "$RAID_INFO" ]]; then
        RAID_INFO="No RAID detected"
    fi
}


# -----------------------------
# Disk I/O
# -----------------------------
io_speed() {
    result=$( (dd if=/dev/zero of=benchx_test bs=1M count=1024 2>&1; sync) )
    rm -f benchx_test
    echo "$result" | grep -Eo '[0-9.]+ MB/s|[0-9.]+ GB/s' | head -1
}

# -----------------------------
# Speedtest Installer
# -----------------------------
install_speedtest_simple() {

    if command -v speedtest >/dev/null 2>&1; then
        return
    fi

    echo "Installing Ookla Speedtest ..."

    # RPM (CentOS/Alma/Rocky/RHEL)
    if command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh \
            | bash >/dev/null 2>&1
        yum install -y speedtest >/dev/null 2>&1 || dnf install -y speedtest >/dev/null 2>&1
        return
    fi

    # Debian/Ubuntu
    if command -v apt >/dev/null 2>&1; then
        curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh \
            | bash >/dev/null 2>&1
        apt update -y >/dev/null 2>&1
        apt install -y speedtest >/dev/null 2>&1
        return
    fi

    # Manual fallback (tgz)
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64) A="x86_64" ;;
        aarch64|arm64) A="aarch64" ;;
        i386|i686) A="i386" ;;
        *) echo "Unsupported arch"; exit 1 ;;
    esac

    URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${A}.tgz"

    wget -4 -qO speedtest.tgz "$URL" >/dev/null 2>&1
    tar xf speedtest.tgz >/dev/null 2>&1
    mv speedtest*/speedtest /usr/local/bin/speedtest >/dev/null 2>&1
    chmod +x /usr/local/bin/speedtest
    rm -rf speedtest* speedtest.tgz >/dev/null 2>&1
}

# -----------------------------
# SPEEDTEST
# -----------------------------
print_speedtest_simple() {
    echo -e "${MAGENTA}\n=== SPEEDTEST ===${RESET}"

    box_open
    box_line "${YELLOW} Running speedtest, please wait (1–2 minutes)...${RESET}"
    box_line " "

    install_speedtest_simple

    # Run test silently
    # Pick random close server
     RANDOM_SERVER=$(speedtest -L 2>/dev/null | awk 'NR>1 && NR<30 {print $1}' | shuf -n1)

    # Run test using random selected server
     speedtest --server-id="$RANDOM_SERVER" --accept-license --accept-gdpr --progress=no > speedtest.log 2>&1

    # Extract results
    DL=$(awk '/Download/ {print $3" "$4}' speedtest.log)
    UL=$(awk '/Upload/   {print $3" "$4}' speedtest.log)
    LAT=$(awk '/Latency/ {print $3" "$4}' speedtest.log)

    # Extract server info
    SERVER_LINE=$(grep -E "Server:" speedtest.log)

    SERVER_NAME=$(awk -F': ' '/Server:/ {print $2}' speedtest.log \
    | sed 's/[(].*$//' \
    | sed 's/^[ \t]*//;s/[ \t]*$//')

    SERVER_ID=$(echo "$SERVER_LINE" | grep -oP '\(id[:= ]+\K[0-9]+' || echo "")


    DISTANCE=$(awk -F': ' '/Distance:/ {print $2}' speedtest.log)
    SPONSOR=$(awk -F': ' '/Hosted by/ {print $2}' speedtest.log)

    # Output
    if [[ -n "$SERVER_ID" ]]; then
        box_line "${ARROW} Server        : ${SERVER_NAME} (ID: ${SERVER_ID})"
    else
        box_line "${ARROW} Server        : ${SERVER_NAME}"
    fi

    [[ -n "$DISTANCE" ]] && box_line "${ARROW} Distance      : ${DISTANCE}"
    box_line "${ARROW} Download      : ${DL}"
    box_line "${ARROW} Upload        : ${UL}"
    box_line "${ARROW} Latency       : ${LAT}"

    box_line " "
    wrap_box_text "Note: Some Speedtest servers may show lower results due to their own limitations or issues. This does not mean there is a problem with your server. We recommend testing multiple times or using the official Speedtest CLI with a specific server ID for more accurate results."

    box_end

    rm -f speedtest.log
}


# -----------------------------
# Print Sections
# -----------------------------
print_system() {
    echo -e "${MAGENTA}\n=== SERVER / HARDWARE INFORMATION ===${RESET}"
    box_open
    box_line "${ARROW} CPU          : ${CPU_MODEL}"
    box_line "${ARROW} Cores        : ${CPU_CORES} @ ${CPU_FREQ} MHz"
    box_line "${ARROW} AES-NI       : ${CPU_AES}"
    box_line "${ARROW} VMX/AMD-V    : ${CPU_VIRT}"
    box_line "${ARROW} Memory       : ${MEM_TOTAL} (${MEM_USED} used)"
    box_line "${ARROW} Disk         : ${DISK_TOTAL} (${DISK_USED} used)"
    box_line "${ARROW} OS           : ${OS}"
    box_line "${ARROW} Kernel       : ${KERN}"
    box_line "${ARROW} Arch         : ${ARCH}"
    box_line "${ARROW} Uptime       : ${UPTIME}"
    box_line "${ARROW} Load Avg     : ${LOAD}"
    box_end
}

print_network() {
    get_ip_info

    echo -e "${MAGENTA}\n=== NETWORK INFORMATION ===${RESET}"
    box_open
    box_line "${ARROW} ISP          : ${ORG}"
    box_line "${ARROW} Location     : ${CITY}, ${REGION}, ${COUNTRY}"
    box_line "${ARROW} IPv4         : ${IPV4}"
    box_line "${ARROW} IPv6         : ${IPV6}"
    box_end
}

print_raid() {
    echo -e "${MAGENTA}\n=== STORAGE RAID STATUS ===${RESET}"
    box_open

    if [[ "$RAID_INFO" == "No RAID detected" ]]; then
        box_line "${ARROW} No RAID detected"
    else
         while IFS= read -r line; do
            box_line "${line}"
        done <<< "$RAID_INFO"
    fi

    box_end
}


print_io() {
    echo -e "${MAGENTA}\n=== DISK I/O BENCHMARK ===${RESET}"
    box_open
    box_line "${YELLOW} Running I/O BENCHMARK, please wait... ${RESET}"
    box_line " "
    IO1=$(io_speed)
    IO2=$(io_speed)
    IO3=$(io_speed)

    num1=${IO1%% *}; [[ "$IO1" =~ GB ]] && num1=$(awk "BEGIN{print $num1*1024}")
    num2=${IO2%% *}; [[ "$IO2" =~ GB ]] && num2=$(awk "BEGIN{print $num2*1024}")
    num3=${IO3%% *}; [[ "$IO3" =~ GB ]] && num3=$(awk "BEGIN{print $num3*1024}")

    AVG=$(awk -v a=$num1 -v b=$num2 -v c=$num3 'BEGIN {printf "%.2f MB/s", (a+b+c)/3}')

    box_line "${ARROW} I/O #1       : ${IO1}"
    box_line "${ARROW} I/O #2       : ${IO2}"
    box_line "${ARROW} I/O #3       : ${IO3}"
    box_line "${ARROW} Average      : ${AVG}"
    box_end
}

print_footer() {
    box_open
    center_text "${YELLOW}${BOLD}Powered by YottaSrc${RESET}"
    center_text "${CYAN}https://yottasrc.com${RESET}"
    box_end
}



# -----------------------------
# MAIN
# -----------------------------
clear
echo -e "${CYAN}YottaSrc Inc. - BenchX v1.4${RESET}"
echo -e "${MAGENTA}Modern Benchmark Script${RESET}"

get_info
detect_raid
print_system
print_network
print_raid
print_io
print_speedtest_simple
print_footer