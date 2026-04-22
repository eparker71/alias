# My Shell Utilities

A collection of zsh aliases and shell scripts to speed up common terminal tasks.

## Installation

Add the following line to your `~/.zshrc`:

```zsh
source /path/to/.my_aliases
```

Then reload your shell:

```zsh
source ~/.zshrc
```

## Aliases

### Navigation
| Alias | Command | Description |
|-------|---------|-------------|
| `..` | `cd ..` | Go up one directory |
| `...` | `cd ../..` | Go up two directories |
| `~` | `cd ~` | Go to home directory |
| `down` | `cd ~/Downloads` | Go to Downloads |
| `desk` | `cd ~/Desktop` | Go to Desktop |
| `docs` | `cd ~/Documents` | Go to Documents |

### Listing / Disk
| Alias | Command | Description |
|-------|---------|-------------|
| `ls` | `ls -lahSr` | List all files, human-readable sizes, sorted by size |
| `lsd` | `du -sh */` | Show disk usage of subdirectories |

### File Operations
| Alias | Command | Description |
|-------|---------|-------------|
| `cp` | `cp -iv` | Copy with confirmation and verbose output |
| `mv` | `mv -iv` | Move with confirmation and verbose output |
| `mkdir` | `mkdir -pv` | Create directories recursively with verbose output |
| `rmd` | `rm -Rf` | Force-remove a directory recursively |

### Shell
| Alias | Command | Description |
|-------|---------|-------------|
| `s` | `source ~/.zshrc` | Reload zsh config |
| `reload` | `exec zsh` | Restart shell |
| `a` | `cat ~/.zshrc \| grep alias` | List all aliases |

### Utilities
| Alias | Command | Description |
|-------|---------|-------------|
| `grep` | `grep --color=auto` | Grep with color highlighting |
| `h` | `history \| grep` | Search command history |
| `ip` | `curl ifconfig.me` | Show public IP address |
| `files` | `find . -type f \| wc -l` | Count files in current directory |

### Git
| Alias | Command | Description |
|-------|---------|-------------|
| `gs` | `git status` | Show working tree status |
| `ga` | `git add .` | Stage all changes |
| `gc` | `git commit -m` | Commit with message |
| `gp` | `git pull` | Pull from remote |
| `gpm` | `git push origin main` | Push to main branch |
| `gd` | `git diff` | Show unstaged changes |
| `gl` | `git log --oneline --graph --decorate` | Pretty log graph |
| `gb` | `git branch` | List branches |
| `gco` | `git checkout` | Checkout branch or file |

### macOS
| Alias | Command | Description |
|-------|---------|-------------|
| `show` | `open .` | Open current directory in Finder |
| `showfiles` | — | Show hidden files in Finder |
| `hidefiles` | — | Hide hidden files in Finder |

## Scripts

### `sysdiag.sh` (Linux)

A comprehensive Linux performance diagnostic script. Runs a full suite of tools to identify performance bottlenecks and pinpoint the specific processes responsible. Exits immediately if run on a non-Linux OS.

**What it checks:**
- **Uptime & load average** — flags if load exceeds CPU core count
- **Kernel ring buffer (dmesg)** — highlights OOM kills, I/O errors, segfaults
- **Memory usage (free)** — warns on low available memory or active swap
- **Virtual memory & I/O wait (vmstat)** — identifies swap and I/O bottlenecks
- **Per-CPU stats (mpstat)** — breaks down %iowait, %usr, %sys per core
- **Disk I/O saturation (iostat)** — flags high %util and await latency
- **Process-level CPU, memory, disk, and context switching (pidstat)** — pinpoints which processes are the culprits

Output is color-coded: Red = critical, Yellow = warning, Cyan = section header.

**Usage:**

```bash
./sysdiag.sh
```

Requires `sysstat` (`vmstat`, `mpstat`, `iostat`, `pidstat`) and `procps-ng` (`uptime`, `free`, `top`). Install on RHEL/CentOS with:

```bash
sudo yum install sysstat procps-ng
```

### `sysdiag_mac.sh` (macOS)

A macOS-native equivalent of `sysdiag.sh` using built-in macOS tools. Exits immediately if run on a non-macOS OS.

**What it checks:**
- **Uptime & load average** — flags if load exceeds CPU core count (`sysctl hw.logicalcpu`)
- **Memory usage (vm_stat)** — calculates available RAM from page statistics, warns on low availability
- **Swap usage** — flags any active swap via `sysctl vm.swapusage`
- **CPU usage** — reports idle/user/sys breakdown via `top`, flags saturation
- **Disk I/O (iostat)** — shows transfers per second and throughput
- **Top processes by CPU and memory** — uses `ps aux` sorted by resource usage
- **Final snapshot** — top 15 processes via `top`

Output is color-coded: Red = critical, Yellow = warning, Cyan = section header.

**Usage:**

```bash
./sysdiag_mac.sh
```

All required tools (`vm_stat`, `iostat`, `top`, `ps`, `sysctl`) are included with macOS — no installation needed.

### `fix_file_names.sh`

Fixes file and directory names on macOS so they sync cleanly with OneDrive. OneDrive rejects names containing characters that are illegal on Windows, as well as names with leading/trailing spaces or trailing periods.

**What it fixes:**
- Replaces illegal characters (`< > : " ? * | \`) with `_`
- Trims leading/trailing spaces from names
- Removes trailing periods

Collisions are handled automatically by appending `_1`, `_2`, etc.

**Usage:**

```bash
# Preview changes (dry run, default)
./fix_file_names.sh

# Apply changes — set DRY_RUN=0 at the top of the script first
./fix_file_names.sh
```

Run from the directory you want to fix. It processes files bottom-up so renaming a directory doesn't break traversal of its contents.
