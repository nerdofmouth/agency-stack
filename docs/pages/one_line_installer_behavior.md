# AgencyStack One-Line Installer: Behavior & Recovery Guide

This document outlines the behavior of the AgencyStack one-line installer, designed for reliability and recovery in all scenarios.

## Official One-Line Installer Command

```bash
curl -fsSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

## Safe to Run On

- ✅ A fresh Debian/Ubuntu system
- ✅ A system where a previous install was partially or fully completed
- ✅ A system where a prior install failed, was interrupted, or is outdated

## Behavior Matrix

| Condition | Result |
|-----------|--------|
| `/opt/agency_stack` does not exist | ✅ Clean clone and install |
| `/opt/agency_stack` exists AND non-interactive mode | 📦 Auto-backs up to `/opt/agency_stack_<timestamp>` and reinstalls |
| `/opt/agency_stack` exists AND interactive mode | 🧑 Prompt user to choose: Backup, Wipe, or Exit |
| Git clone fails | ❌ Fails gracefully with error |
| Script re-run multiple times | ✅ Will back up each time and retry clean |

## Dependencies and State Handling

- All required tools (`git`, `curl`, `make`, etc.) are installed if missing
- System package installs are run with:
  ```bash
  export DEBIAN_FRONTEND=noninteractive
  ```
- Git operations are non-interactive:
  ```bash
  export GIT_TERMINAL_PROMPT=0
  ```
- All prompts from `apt`, `apt-listchanges`, and `apt-listbugs` are suppressed
- Install logs are written to `/var/log/agency_stack/install-<timestamp>.log`

## Recovery from a Broken or Interrupted Install

Simply run the one-line installer again:

```bash
curl -fsSL https://stack.nerdofmouth.com/install.sh | sudo bash
```

The script will:
1. Detect the broken `/opt/agency_stack`
2. Back it up automatically
3. Pull a fresh copy of the repository
4. Resume installation

No cleanup needed. No risk of corruption. No prompt required in non-interactive mode.

## Backup Naming Convention

Backups of the old stack directory are created automatically with a timestamp:

```bash
/opt/agency_stack_backup_YYYYMMDDHHMMSS
```

This makes rollback easy if something breaks post-upgrade by providing a clear timeline of installation attempts.

## Logging

- All installation actions are logged to `/var/log/agency_stack/install-<timestamp>.log`
- Each run creates a new timestamped log file
- Logs capture all installation steps, errors, and recovery actions

## Technical Implementation Details

The installer achieves its reliability through:

1. **Mode Detection**:
   ```bash
   if [ ! -t 0 ]; then
     # If standard input is not a terminal, we're being piped to
     ONE_LINE_MODE=true
   fi
   ```

2. **Environment Setup**:
   ```bash
   export DEBIAN_FRONTEND=noninteractive
   export GIT_TERMINAL_PROMPT=0
   export APT_LISTCHANGES_FRONTEND=none
   export APT_LISTBUGS_FRONTEND=none
   ```

3. **Automated Backup**:
   ```bash
   BACKUP_TS=$(date +"%Y%m%d%H%M%S")
   BACKUP_DIR="/opt/agency_stack_backup_${BACKUP_TS}"
   mkdir -p "$BACKUP_DIR"
   cp -r /opt/agency_stack/* "$BACKUP_DIR/" 2>/dev/null || true
   ```

These mechanisms ensure a consistent, reliable installation experience even in challenging scenarios.
