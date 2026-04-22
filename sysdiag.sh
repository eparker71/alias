#!/bin/bash

# ##################################################################
# Comprehensive Linux Performance Diagnosis Script (v2)
#
# This script runs a full suite of diagnostic tools to identify
# performance bottlenecks (CPU, Memory, I/O) and then uses
# pidstat to pinpoint the specific processes responsible.
# This version includes enhanced explanations for developers.
#
# Red    = Critical Value (potential cause of freezing/slowness)
# Yellow = Warning Value (potential cause of latency)
# Cyan   = Informational Title
# ##################################################################

# --- OS Check ---
if [[ "$(uname)" != "Linux" ]]; then
    echo "This script is for Linux only. On macOS, use sysdiag_mac.sh instead."
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
echo "      Comprehensive Linux Performance Diagnostic Script"
echo "====================================================================="
echo "Timestamp: $(date)"
echo -e "Interpreting Colors: ${RED}Red (Critical),${YELLOW} Yellow (Warning),${CYAN} Cyan (Info)${NC}\n"


# =====================================================================
#  Part 1: System-Wide Overview
# =====================================================================
echo "## Part 1: System-Wide Overview ##"

# --- 1. Uptime and Load Average ---
echo -e "\n${CYAN}## 1. Uptime and Load Average ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} The 'load average' values (1-min, 5-min, 15-min).
   A load average is the average number of processes in the run queue (running or waiting for CPU).
   - ${RED}High Load (> # of Cores):${NC} If the load is consistently higher than your number of CPU cores, it means processes are waiting for CPU time. This is a clear sign of a CPU bottleneck.
   - ${YELLOW}Trend:${NC} Compare the 1, 5, and 15-min averages. If the 1-min is much higher than the 15-min, the load is increasing. If it's lower, the load is decreasing."
if command_exists uptime; then
    NUM_CORES=$(nproc 2>/dev/null || echo 1)
    echo "   Number of CPU cores on this system: $NUM_CORES"
    uptime | awk -v nproc="$NUM_CORES" -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '{
        load1_str=gensub(/.*load average: /,"",1,$0);
        split(load1_str, loads, ", ");
        load1 = loads[1];
        print $0;
        if (load1 > nproc * 2) {
            printf "   %sCRITICAL: 1-min load (%.2f) is more than double the number of cores (%d). System is severely overloaded.%s\n", RED, load1, nproc, NC;
        } else if (load1 > nproc) {
            printf "   %sWARNING: 1-min load (%.2f) is higher than the number of cores (%d). System is overloaded.%s\n", YELLOW, load1, nproc, NC;
        } else {
            printf "   INFO: Load average is within a normal range.\n";
        }
    }'
else
    echo -e "${YELLOW}Command 'uptime' not found, which is highly unusual.${NC}"
fi

# --- 2. Kernel Ring Buffer (dmesg) ---
echo -e "\n${CYAN}## 2. Kernel Ring Buffer (dmesg) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} Any kernel-level errors. These are often signs of hardware failure, driver bugs, or extreme resource exhaustion.
   - ${RED}'Out of memory: Kill process':${NC} The system is out of memory and has started killing processes to survive. This is a critical state.
   - ${RED}'I/O error', 'task ... blocked for more than 120 seconds':${NC} Suggests severe problems with storage devices or drivers.
   - ${YELLOW}'segfault':${NC} A process has crashed due to illegal memory access. May indicate a software bug."
if command_exists dmesg; then
    dmesg | tail -n 30 | grep -E --color=always 'error|fail|timeout|denied|killed process|Out of memory|I/O error|segfault|blocked for more' || echo "   INFO: No critical error messages found in recent dmesg logs."
else
    echo -e "${YELLOW}Command 'dmesg' not found, which is highly unusual.${NC}"
fi

# --- 3. Memory Usage (free) ---
echo -e "\n${CYAN}## 3. Overall Memory Usage (free) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} The relationship between total memory, available memory, and swap usage.
   - ${RED}Low 'available' memory:${NC} This is the most important metric. It estimates how much memory is available for starting new applications without swapping. If this is low (<10-20% of total), the system is under memory pressure.
   - ${RED}High 'used' swap:${NC} Any significant swap usage means the system has been forced to use the slow disk as memory, which drastically degrades performance. This is a sign of a past or present memory bottleneck."
if command_exists free; then
    free -m | awk -v RED="$RED" -v YELLOW="$YELLOW" -v NC="$NC" '
    NR==1 {print $0 " (values in MB)"; next}
    /Mem:/ {
        total=$2; available=$7;
        printf "%-7s %-7s %-7s %-7s %-7s %-7s ", $1, $2, $3, $4, $5, $6;
        if ((available / total) < 0.1) {
            printf "%s%-7s%s\n", RED, $7, NC;
            print "   " RED "CRITICAL: Available memory is less than 10% of total." NC;
        } else if ((available / total) < 0.2) {
            printf "%s%-7s%s\n", YELLOW, $7, NC;
            print "   " YELLOW "WARNING: Available memory is less than 20% of total." NC;
        } else { printf "%-7s\n", $7; }
    }
    /Swap:/ {
        used=$3;
        printf "%-7s %-7s ", $1, $2;
        if (used > 100) {
            printf "%s%-7s%s %-7s\n", RED, $3, NC, $4;
            print "   " RED "CRITICAL: System is actively using swap space. Expect severe slowness." NC;
        } else if (used > 0) {
            printf "%s%-7s%s %-7s\n", YELLOW, $3, NC, $4;
            print "   " YELLOW "WARNING: Swap has been used. System experienced memory pressure." NC;
        } else { print $3, $4; }
    }'
else
    echo -e "${YELLOW}Command 'free' not found. Install with: sudo yum install procps-ng${NC}"
fi

# =====================================================================
#  Part 2: Resource Bottleneck Identification
# =====================================================================
echo -e "\n## Part 2: Resource Bottleneck Identification ##"
echo "-> Identifying *what* kind of resource is under pressure (CPU, Disk I/O, Memory)."

# --- 4. Virtual Memory & I/O Wait (vmstat) ---
echo -e "\n${CYAN}## 4. Virtual Memory & I/O Wait (vmstat) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} This gives a great overview of system bottlenecks.
   - ${YELLOW}procs 'r' (run queue):${NC} Consistently high numbers ( > # of cores) indicate a CPU bottleneck.
   - ${RED}memory 'si'/'so' (swap-in/swap-out):${NC} Non-zero values here are very bad. It means the system is swapping memory to/from disk.
   - ${RED}cpu 'wa' (wait I/O):${NC} High percentage (>20%) means your CPU is idle, waiting for disk/network I/O to complete. This is a classic sign of an I/O bottleneck."
if command_exists vmstat; then
    vmstat 1 5
else
    echo -e "${YELLOW}Command 'vmstat' not found. Install with: sudo yum install procps-ng${NC}"
fi

# --- 5. CPU and I/O Wait (mpstat) ---
echo -e "\n${CYAN}## 5. CPU and I/O Wait (mpstat) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} A per-CPU breakdown of where time is being spent.
   - ${RED}'%iowait':${NC} Same as 'wa' in vmstat. High values confirm an I/O bottleneck. If you see this, check 'iostat' and 'pidstat -d' next.
   - ${YELLOW}'%usr' vs '%sys':${NC} If idle is low, is the CPU busy in user space (%usr) or system/kernel space (%sys)? High %sys can indicate a process is making many I/O or kernel calls.
   - ${YELLOW}'%idle':${NC} Consistently low idle means your CPUs are busy. If %iowait is also low, you have a CPU-bound workload."
if command_exists mpstat; then
    mpstat -P ALL 1 3
else
    echo -e "${YELLOW}Command 'mpstat' not found. Install with: sudo yum install sysstat${NC}"
fi

# --- 6. Disk I/O Saturation (iostat) ---
echo -e "\n${CYAN}## 6. Disk I/O Saturation (iostat) ##${NC}"
echo -e "-> ${YELLOW}What to look for:${NC} The performance and saturation of your block devices (disks).
   - ${RED}'%util':${NC} If this is approaching 100%, the disk is saturated. It cannot handle any more requests, and processes will be forced to wait, causing major slowness.
   - ${RED}'await':${NC} The average time (in ms) for I/O requests to be served. This is your disk latency. What's 'bad' depends on the disk type (e.g., for SSDs >10ms is a warning, for HDDs >50ms is a warning)."
if command_exists iostat; then
    iostat -xz 1 3
else
    echo -e "${YELLOW}Command 'iostat' not found. Install with: sudo yum install sysstat${NC}"
fi

# =====================================================================
#  Part 3: Culprit Identification (pidstat)
# =====================================================================
echo -e "\n## Part 3: Culprit Identification (pidstat) ##"
echo "-> Identifying *which specific processes* are causing the bottlenecks identified in Part 2."

if ! command_exists pidstat; then
    echo -e "${YELLOW}Command 'pidstat' not found. This is a critical tool. Install with: sudo yum install sysstat${NC}"
else
    # --- 7. Processes causing CPU load ---
    echo -e "\n${CYAN}## 7. Top Processes by CPU Usage (pidstat -u) ##${NC}"
    echo -e "-> ${YELLOW}Connection:${NC} If 'uptime' load is high and 'mpstat' shows low idle, the processes listed here are your suspects."
    pidstat -u 1 3

    # --- 8. Processes causing Memory Faults/Swapping ---
    echo -e "\n${CYAN}## 8. Top Processes by Memory Faults (pidstat -r) ##${NC}"
    echo -e "-> ${YELLOW}Connection:${NC} If 'free' shows swap usage and 'vmstat' shows 'si'/'so' activity, look here.
       ${RED}'majflt/s' (Major Faults):${NC} A non-zero value is a smoking gun. It means the process needed memory that was not in RAM and had to be fetched from the slow swap disk. This directly causes slowness."
    pidstat -r 1 3

    # --- 9. Processes causing Disk I/O ---
    echo -e "\n${CYAN}## 9. Top Processes by Disk I/O (pidstat -d) ##${NC}"
    echo -e "-> ${YELLOW}Connection:${NC} If 'iostat' shows high '%util' or 'mpstat' shows high '%iowait', the top processes here are your culprits.
       This tells you exactly who is responsible for the disk activity."
    pidstat -d 1 3
    
    # --- 10. Processes causing Context Switching ---
    echo -e "\n${CYAN}## 10. Top Processes by Context Switching (pidstat -w) ##${NC}"
    echo -e "-> ${YELLOW}Connection:${NC} A more subtle cause of latency, especially with high CPU load.
       ${RED}'nvcswch/s' (Involuntary Context Switches):${NC} High values mean the process is being forced off the CPU by the scheduler because its time slice expired. This indicates heavy CPU contention where many processes are competing for CPU time."
    pidstat -w 1 3

fi

# --- 11. Final Summary (top) ---
echo -e "\n${CYAN}## 11. Final Summary: Top Processes by CPU & Memory ##${NC}"
echo "-> A snapshot of the most resource-intensive processes running right now."
if command_exists top; then
    top -b -n 1 | head -n 20
else
    echo -e "${YELLOW}Command 'top' not found. Install with: sudo yum install procps-ng${NC}"
fi

echo "====================================================================="
echo "                         Diagnostic Script Finished"
echo "====================================================================="

