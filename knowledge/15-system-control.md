# System Control — OS-Level Machine Operations

OpenClaw can control the local operating system through the `exec` tool. This document covers file operations, application management, clipboard, window management, networking, process control, and cross-platform commands.

---

## File System Operations

### Creating Files & Directories
```bash
# Create a directory (with parents)
exec mkdir -p ~/.openclaw/assets/images/march-2026

# Create an empty file
exec touch ~/.openclaw/inbox/placeholder.txt

# Write content to a file
exec echo "Hello World" > ~/.openclaw/output/note.txt

# Write multi-line content
exec cat << 'EOF' > ~/.openclaw/output/script.txt
Scene 1: Opening shot
Scene 2: Product reveal
Scene 3: Call to action
EOF
```

### Moving, Copying, Renaming
```bash
# Copy a file
exec cp ~/.openclaw/assets/image.png ~/.openclaw/assets/backup/image.png

# Copy a directory recursively
exec cp -r ~/.openclaw/assets/march/ ~/.openclaw/assets/march-backup/

# Move / rename a file
exec mv ~/.openclaw/inbox/raw.mp4 ~/.openclaw/assets/videos/processed.mp4

# Rename in place
exec mv ~/.openclaw/assets/old_name.png ~/.openclaw/assets/new_name.png
```

### Deleting
```bash
# Delete a file
exec rm ~/.openclaw/tmp/garbage.txt

# Delete a directory and contents
exec rm -rf ~/.openclaw/tmp/session_old/

# Delete files matching a pattern (older than 7 days)
exec find ~/.openclaw/tmp/ -type f -mtime +7 -delete

# Safe delete — move to trash instead
exec mkdir -p ~/.openclaw/.trash && mv ~/.openclaw/tmp/file.txt ~/.openclaw/.trash/
```

### Searching for Files
```bash
# Find files by name
exec find ~/.openclaw/ -name "*.png" -type f

# Find files modified in the last 24 hours
exec find ~/.openclaw/ -type f -mtime -1

# Find files larger than 100MB
exec find ~/.openclaw/ -type f -size +100M

# Find files containing text
exec grep -rl "keyword" ~/.openclaw/assets/

# List files sorted by size (largest first)
exec ls -lhS ~/.openclaw/assets/videos/

# Count files in a directory
exec find ~/.openclaw/assets/ -type f | wc -l
```

### File Information
```bash
# File size and details
exec ls -lh ~/.openclaw/assets/video.mp4

# File type detection
exec file ~/.openclaw/assets/unknown_file

# Disk usage of a directory
exec du -sh ~/.openclaw/assets/

# Directory tree (2 levels deep)
exec find ~/.openclaw/ -maxdepth 2 -type d | head -30
```

---

## Application Launching

### Windows (PowerShell / cmd)
```bash
# Open an application
exec powershell -Command "Start-Process 'notepad.exe'"
exec powershell -Command "Start-Process 'C:/Program Files/Google/Chrome/Application/chrome.exe'"

# Open a file with its default application
exec powershell -Command "Start-Process 'C:/Users/user/Desktop/document.pdf'"

# Open a URL in default browser
exec powershell -Command "Start-Process 'https://example.com'"

# Open File Explorer to a folder
exec powershell -Command "Start-Process explorer 'C:/Users/user/Desktop'"
```

### macOS
```bash
# Open an application
exec open -a "Safari"
exec open -a "Visual Studio Code"

# Open a file with default app
exec open ~/Desktop/document.pdf

# Open a URL
exec open "https://example.com"

# Open Finder to a folder
exec open ~/Desktop/
```

### Linux
```bash
# Open an application
exec nohup firefox &
exec nohup code . &

# Open a file with default app
exec xdg-open ~/Desktop/document.pdf

# Open a URL
exec xdg-open "https://example.com"

# Open file manager
exec xdg-open ~/Desktop/
```

---

## Clipboard Management

### Windows
```bash
# Copy text to clipboard
exec powershell -Command "Set-Clipboard 'Hello World'"

# Read clipboard contents
exec powershell -Command "Get-Clipboard"

# Copy file contents to clipboard
exec powershell -Command "Get-Content 'C:/Users/user/file.txt' | Set-Clipboard"

# Copy command output to clipboard
exec powershell -Command "Get-Process | Out-String | Set-Clipboard"
```

### macOS
```bash
# Copy text to clipboard
exec echo "Hello World" | pbcopy

# Read clipboard contents
exec pbpaste

# Copy file contents to clipboard
exec cat ~/file.txt | pbcopy
```

### Linux
```bash
# Copy text to clipboard (requires xclip or xsel)
exec echo "Hello World" | xclip -selection clipboard

# Read clipboard contents
exec xclip -selection clipboard -o
```

---

## Window Management

### Windows (PowerShell)
```bash
# List all open windows
exec powershell -Command "Get-Process | Where-Object {$_.MainWindowTitle -ne ''} | Select-Object ProcessName, MainWindowTitle"

# Minimize all windows
exec powershell -Command "& { $shell = New-Object -ComObject Shell.Application; $shell.MinimizeAll() }"

# Bring a specific app to front (using nircmd or PowerShell)
exec powershell -Command "
Add-Type @'
using System; using System.Runtime.InteropServices;
public class Win { [DllImport(\"user32.dll\")] public static extern bool SetForegroundWindow(IntPtr hWnd); }
'@
\$proc = Get-Process | Where-Object { \$_.MainWindowTitle -like '*Notepad*' } | Select-Object -First 1
[Win]::SetForegroundWindow(\$proc.MainWindowHandle)
"
```

### macOS
```bash
# List windows
exec osascript -e 'tell application "System Events" to get name of every process whose visible is true'

# Activate an app
exec osascript -e 'tell application "Safari" to activate'

# Minimize a window
exec osascript -e 'tell application "System Events" to set miniaturized of first window of process "Safari" to true'
```

---

## System Information

### Disk Space
```bash
# Disk usage summary
exec df -h

# Specific directory size
exec du -sh ~/.openclaw/

# Top 10 largest files
exec find ~/.openclaw/ -type f -exec ls -lh {} + | sort -k5 -rh | head -10
```

### Memory & CPU
```bash
# Windows
exec powershell -Command "Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory"
exec powershell -Command "Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage"

# macOS / Linux
exec free -h          # Memory (Linux)
exec vm_stat          # Memory (macOS)
exec top -bn1 | head -5   # CPU/memory overview (Linux)
exec uptime           # Load average
```

### System Info
```bash
# OS version
exec uname -a                    # Linux/macOS
exec powershell -Command "[System.Environment]::OSVersion"  # Windows

# Hostname
exec hostname

# Current user
exec whoami

# Environment
exec env | sort
```

### Running Processes
```bash
# List all processes
exec ps aux                      # Linux/macOS
exec powershell -Command "Get-Process | Select-Object -First 20 Name, Id, CPU, WorkingSet64"  # Windows

# Find a specific process
exec ps aux | grep -i "chrome"
exec powershell -Command "Get-Process -Name 'chrome' -ErrorAction SilentlyContinue"

# Process tree
exec pstree                      # Linux
```

---

## Network Operations

### Connectivity Check
```bash
# Ping test
exec ping -c 3 google.com         # Linux/macOS
exec ping -n 3 google.com         # Windows

# Check if a specific host/port is reachable
exec nc -zv example.com 443 2>&1  # Linux/macOS
exec powershell -Command "Test-NetConnection -ComputerName example.com -Port 443"  # Windows

# DNS lookup
exec nslookup example.com
exec dig example.com               # Linux/macOS
```

### Download & Upload
```bash
# Download a file
exec curl -L -o ~/.openclaw/downloads/file.zip "https://example.com/file.zip"
exec wget -O ~/.openclaw/downloads/file.zip "https://example.com/file.zip"

# Download with progress
exec curl -L --progress-bar -o ~/.openclaw/downloads/large.mp4 "https://example.com/large.mp4"

# Upload a file (POST)
exec curl -X POST -F "file=@~/.openclaw/assets/image.png" https://httpbin.org/post

# Check response headers
exec curl -I https://example.com

# Get public IP
exec curl -s https://ifconfig.me
```

### Network Info
```bash
# Show network interfaces
exec ip addr                       # Linux
exec ifconfig                      # macOS
exec powershell -Command "Get-NetIPAddress | Select-Object InterfaceAlias, IPAddress"  # Windows

# Show open ports
exec netstat -tlnp                 # Linux
exec lsof -i -P | head -20        # macOS
exec powershell -Command "Get-NetTCPConnection -State Listen | Select-Object LocalPort, OwningProcess"  # Windows
```

---

## Scheduled Tasks / Cron Management

### Linux/macOS (crontab)
```bash
# View current crontab
exec crontab -l

# Add a cron job (append to existing)
exec (crontab -l 2>/dev/null; echo "0 9 * * * /usr/local/bin/openclaw run morning-routine >> ~/.openclaw/logs/cron.log 2>&1") | crontab -

# Remove all cron jobs
exec crontab -r

# Common cron patterns:
# */15 * * * *    → Every 15 minutes
# 0 */2 * * *     → Every 2 hours
# 0 9 * * *       → Daily at 9 AM
# 0 9 * * 1       → Every Monday at 9 AM
# 0 9,18 * * *    → Daily at 9 AM and 6 PM
```

### Windows (Task Scheduler)
```bash
# Create a scheduled task
exec powershell -Command "
\$action = New-ScheduledTaskAction -Execute 'openclaw' -Argument 'run morning-routine'
\$trigger = New-ScheduledTaskTrigger -Daily -At '09:00'
Register-ScheduledTask -TaskName 'OpenClaw Morning' -Action \$action -Trigger \$trigger
"

# List scheduled tasks
exec powershell -Command "Get-ScheduledTask | Where-Object {$_.TaskName -like '*OpenClaw*'}"

# Delete a scheduled task
exec powershell -Command "Unregister-ScheduledTask -TaskName 'OpenClaw Morning' -Confirm:\$false"

# Run a task immediately
exec powershell -Command "Start-ScheduledTask -TaskName 'OpenClaw Morning'"
```

---

## Environment Variable Management

```bash
# Read an environment variable
exec echo $HOME
exec echo $PATH

# Set for current session (Linux/macOS)
exec export OPENCLAW_MODE=production

# Set permanently (Linux — add to .bashrc)
exec echo 'export OPENCLAW_MODE=production' >> ~/.bashrc

# Windows — set user environment variable
exec powershell -Command "[System.Environment]::SetEnvironmentVariable('OPENCLAW_MODE', 'production', 'User')"

# Windows — read
exec powershell -Command "[System.Environment]::GetEnvironmentVariable('OPENCLAW_MODE', 'User')"

# List all environment variables
exec env | sort                    # Linux/macOS
exec powershell -Command "Get-ChildItem Env: | Sort-Object Name"  # Windows
```

---

## Package & Software Installation

### Windows (winget)
```bash
# Search for a package
exec winget search ffmpeg

# Install a package
exec winget install --id Gyan.FFmpeg -e --accept-source-agreements

# List installed packages
exec winget list

# Upgrade all packages
exec winget upgrade --all

# Common packages for OpenClaw:
exec winget install --id ImageMagick.ImageMagick -e
exec winget install --id Python.Python.3.12 -e
exec winget install --id Git.Git -e
exec winget install --id jqlang.jq -e
```

### macOS (Homebrew)
```bash
exec brew install ffmpeg
exec brew install imagemagick
exec brew install jq
exec brew install python@3.12
exec brew list
exec brew upgrade
```

### Linux (apt — Debian/Ubuntu)
```bash
exec sudo apt update
exec sudo apt install -y ffmpeg imagemagick jq python3
exec apt list --installed
exec sudo apt upgrade -y
```

### Python Packages (pip)
```bash
# Install a Python package
exec pip install pyotp pillow requests yt-dlp

# Install from requirements
exec pip install -r ~/.openclaw/requirements.txt

# Check if a package is installed
exec pip show pyotp
```

---

## Process Management

### Starting Processes
```bash
# Run in background
exec nohup python3 ~/.openclaw/scripts/monitor.py > ~/.openclaw/logs/monitor.log 2>&1 &

# Run and capture PID
exec python3 ~/.openclaw/scripts/server.py &
exec echo $! > ~/.openclaw/pids/server.pid
```

### Stopping Processes
```bash
# Kill by PID
exec kill $(cat ~/.openclaw/pids/server.pid)

# Kill by name
exec pkill -f "monitor.py"

# Force kill
exec kill -9 $(cat ~/.openclaw/pids/server.pid)

# Windows
exec powershell -Command "Stop-Process -Name 'python' -Force"
exec powershell -Command "Stop-Process -Id 12345 -Force"
```

### Monitoring Processes
```bash
# Check if a process is running
exec ps aux | grep -v grep | grep "monitor.py" && echo "RUNNING" || echo "STOPPED"

# Watch resource usage of a process
exec ps -p $(cat ~/.openclaw/pids/server.pid) -o pid,pcpu,pmem,etime,comm

# Windows
exec powershell -Command "Get-Process -Id 12345 | Select-Object Id, CPU, WorkingSet64, StartTime"
```

### PID File Management
```bash
# Save PID on process start
exec echo $! > ~/.openclaw/pids/process_name.pid

# Read PID
exec cat ~/.openclaw/pids/process_name.pid

# Check if PID is still alive
exec kill -0 $(cat ~/.openclaw/pids/process_name.pid) 2>/dev/null && echo "alive" || echo "dead"

# Clean up stale PID files
exec for f in ~/.openclaw/pids/*.pid; do kill -0 $(cat "$f") 2>/dev/null || rm "$f"; done
```

---

## Cross-Platform Command Reference

| Operation | Windows (PowerShell) | macOS | Linux |
|-----------|---------------------|-------|-------|
| List files | `Get-ChildItem` | `ls -la` | `ls -la` |
| Find files | `Get-ChildItem -Recurse -Filter *.png` | `find . -name "*.png"` | `find . -name "*.png"` |
| Copy file | `Copy-Item src dst` | `cp src dst` | `cp src dst` |
| Move file | `Move-Item src dst` | `mv src dst` | `mv src dst` |
| Delete file | `Remove-Item path` | `rm path` | `rm path` |
| Read file | `Get-Content path` | `cat path` | `cat path` |
| Write file | `Set-Content path "text"` | `echo "text" > path` | `echo "text" > path` |
| Current dir | `Get-Location` | `pwd` | `pwd` |
| Disk space | `Get-PSDrive C` | `df -h` | `df -h` |
| Processes | `Get-Process` | `ps aux` | `ps aux` |
| Kill process | `Stop-Process -Id X` | `kill X` | `kill X` |
| Download | `Invoke-WebRequest -Uri url -OutFile path` | `curl -o path url` | `curl -o path url` |
| Zip | `Compress-Archive -Path src -DestinationPath dst.zip` | `zip -r dst.zip src` | `zip -r dst.zip src` |
| Unzip | `Expand-Archive -Path src.zip -DestinationPath dst` | `unzip src.zip -d dst` | `unzip src.zip -d dst` |

---

## Best Practices

1. **Always use absolute paths** in exec commands — the working directory may change between calls
2. **Check before deleting** — use `ls` or `find` to verify targets before `rm -rf`
3. **Use the right OS commands** — check the platform first with `uname` or `$env:OS` and branch accordingly
4. **Capture output** — redirect important command output to log files for debugging
5. **Clean up temp files** regularly — schedule cleanup in the heartbeat (see 13-autonomous-operations.md)
6. **PID files for background processes** — always save PIDs so you can stop processes cleanly later
7. **Test commands on small targets first** — before running bulk operations, test on a single file
