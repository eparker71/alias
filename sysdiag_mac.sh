#!/bin/bash

# ##################################################################
# Comprehensive macOS Performance Diagnosis Script
#
# This script runs a full suite of diagnostic tools to identify
# performance bottlenecks (CPU, Memory, I/O) and pinpoint the
# specific processes responsible.
#
# Red    = Critical Value (potential cause of freezing/slowness)
# Yellow = Warning Value (potential cause of latency)
# Cyan   = Informational Title
# ##################################################################

# --- OS Check ---
if [[ "$(uname)" != "Darwin" ]]; then
    echo "This script is for macOS only. On Linux, use sysdiag.sh instead."
    exit 1
fi

# --- Color Definitions ---
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Function ---
command_exists() {
    command -v "$1" &> /dev/null
}

echo "====================================================================="
echo "         Comprehensive macOS Performance Diagnostic Script"
echo "====================================================================="
echo "Timestamp: $(date)"
echo -e "Interpreting Colors: ${RED}Red (Critical),${YELLOW} Yellow (Warning),${CYAN} Cyan (Info)${NC}\n"


# =====================================================================
#  Part 1: System-Wide Overview
# =====================================================================
echo "## Part 1: System-Wide Overview ##"

# --- 1. Uptime and Load Average ---
echo -e "\n${CYAN}## 1. Uptime and Load Average ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} The 'load averages' values (1-min, 5-min, 15-min).
   A load average is the average number of processes in the run queue (running or waiting for CPU).
   - ${RED}High Load (> # of Cores):${NC} If consistently higher than your CPU core count, processes are waiting for CPU time.
   - ${YELLOW}Trend:${NC} If the 1-min is much higher than the 15-min, load is increasing. If lower, it is decreasing."
NUM_CORES=$(sysctl -n hw.logicalcpu)
echo "   Number of CPU cores on this system: $NUM_CORES"
uptime | awk -v nproc="$NUM_CORES" -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '{
    load1 = $(NF-2)
    print $0
    if (load1 > nproc * 2) {
        printf "   %sCRITICAL: 1-min load (%.2f) is more than double the number of cores (%d). System is severely overloaded.%s\n", RED, load1, nproc, NC
    } else if (load1 > nproc) {
        printf "   %sWARNING: 1-min load (%.2f) is higher than the number of cores (%d). System is overloaded.%s\n", YELLOW, load1, nproc, NC
    } else {
        printf "   INFO: Load average is within a normal range.\n"
    }
}'

# --- 2. Memory Usage (vm_stat) ---
echo -e "\n${CYAN}## 2. Memory Usage (vm_stat) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} Available memory relative to total RAM.
   - ${RED}Available < 10% of total:${NC} System is under serious memory pressure.
   - ${YELLOW}Available < 20% of total:${NC} System is under memory pressure; watch for slowness."
vm_stat | awk -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '
/page size of/ { page_size = $8 }
/Pages free/        { gsub(/\./, "", $3); free_p = $3 + 0 }
/Pages active/      { gsub(/\./, "", $3); active = $3 + 0 }
/Pages inactive/    { gsub(/\./, "", $3); inactive = $3 + 0 }
/Pages wired down/  { gsub(/\./, "", $4); wired = $4 + 0 }
/Pages speculative/ { gsub(/\./, "", $3); speculative = $3 + 0 }
END {
    total     = (free_p + active + inactive + wired + speculative) * page_size
    available = (free_p + inactive + speculative) * page_size
    printf "   Total RAM:  %.1f GB\n", total / 1024^3
    printf "   Available:  %.1f GB\n", available / 1024^3
    ratio = available / total
    if (ratio < 0.1) {
        printf "   %sCRITICAL: Available memory is less than 10%% of total.%s\n", RED, NC
    } else if (ratio < 0.2) {
        printf "   %sWARNING: Available memory is less than 20%% of total.%s\n", YELLOW, NC
    } else {
        printf "   INFO: Memory usage is within normal range.\n"
    }
}'

# --- 3. Swap Usage ---
echo -e "\n${CYAN}## 3. Swap Usage ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} Any swap usage means physical RAM was exhausted at some point.
   - ${RED}High swap used:${NC} System is using disk as memory. Performance will be significantly degraded.
   - ${YELLOW}Any swap used:${NC} System has experienced memory pressure."
sysctl vm.swapusage | awk -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '{
    for (i = 1; i <= NF; i++) {
        if ($i == "used") { used_str = $(i+2); gsub(/[^0-9.]/, "", used_str); used = used_str + 0 }
        if ($i == "total") { total_str = $(i+2); gsub(/[^0-9.]/, "", total_str); total = total_str + 0 }
    }
    print $0
    if (used > 512) {
        printf "   %sCRITICAL: Over 512MB of swap in use. Expect significant slowness.%s\n", RED, NC
    } else if (used > 0) {
        printf "   %sWARNING: Swap is in use. System has experienced memory pressure.%s\n", YELLOW, NC
    } else {
        printf "   INFO: No swap in use.\n"
    }
}'


# =====================================================================
#  Part 2: Resource Bottleneck Identification
# =====================================================================
echo -e "\n## Part 2: Resource Bottleneck Identification ##"
echo "-> Identifying *what* kind of resource is under pressure (CPU, Disk I/O, Memory)."

# --- 4. CPU Usage ---
echo -e "\n${CYAN}## 4. CPU Usage ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} Where CPU time is being spent.
   - ${RED}Idle < 10%:${NC} CPUs are saturated. Check Part 3 to find which processes are responsible.
   - ${YELLOW}Idle < 25%:${NC} System is under CPU pressure.
   - ${YELLOW}High sys %:${NC} Many kernel/system calls — often caused by heavy I/O activity."
# Two samples are required for accurate CPU percentages on macOS; use the second
top -l 2 -n 0 | grep "CPU usage" | tail -1 | awk -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '{
    for (i = 1; i <= NF; i++) {
        if ($i ~ /idle/) { gsub(/%/, "", $(i-1)); idle = $(i-1) + 0 }
    }
    print $0
    if (idle < 10) {
        printf "   %sCRITICAL: CPU idle is %.1f%%. System is CPU-saturated.%s\n", RED, idle, NC
    } else if (idle < 25) {
        printf "   %sWARNING: CPU idle is %.1f%%. System is under CPU pressure.%s\n", YELLOW, idle, NC
    } else {
        printf "   INFO: CPU idle (%.1f%%) is within normal range.\n", idle
    }
}'

# --- 5. Disk I/O (iostat) ---
echo -e "\n${CYAN}## 5. Disk I/O (iostat) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} Disk throughput and request rate.
   - ${YELLOW}High tps (transfers per second):${NC} Disk is being hit frequently — could indicate an I/O bottleneck.
   - ${YELLOW}High KB/t (kilobytes per transfer):${NC} Large sequential transfers; check if competing with normal operations."
if command_exists iostat; then
    iostat -c 3 -w 1
else
    echo -e "${YELLOW}Command 'iostat' not found.${NC}"
fi


# =====================================================================
#  Part 3: Culprit Identification
# =====================================================================
echo -e "\n## Part 3: Culprit Identification ##"
echo "-> Identifying *which specific processes* are causing the bottlenecks identified in Part 2."

# --- 6. Top Processes by CPU ---
echo -e "\n${CYAN}## 6. Top Processes by CPU Usage ##${NC}"
echo -e "-> ${YELLOW}Connection:${NC} If load average is high and CPU idle is low, the processes listed here are your suspects."
ps aux | sort -rk 3 | head -n 11

# --- 7. Top Processes by Memory ---
echo -e "\n${CYAN}## 7. Top Processes by Memory Usage ##${NC}"
echo -e "-> ${YELLOW}Connection:${NC} If available memory is low or swap is active, the processes listed here are your suspects."
ps aux | sort -rk 4 | head -n 11

# --- 8. Final Summary (top) ---
echo -e "\n${CYAN}## 8. Final Summary: Top Processes Snapshot ##${NC}"
echo "-> A snapshot of the most resource-intensive processes running right now."
top -l 1 -o cpu -n 15 -stats pid,command,cpu,mem,state

echo "====================================================================="
echo "                      Diagnostic Script Finished"
echo "====================================================================="
