# My Shell Aliases

A collection of zsh aliases to speed up common terminal tasks.

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
