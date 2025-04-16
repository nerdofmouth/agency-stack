# AgencyStack Repository Audit and Cleanup

This document describes the repository audit and cleanup utility for AgencyStack. This system helps maintain code quality, reduce technical debt, and ensure a clean and efficient codebase.

## Overview

The audit and cleanup system consists of several components:

1. **Script Usage Tracking**: Analyzes script usage across the codebase to identify unused, stale, or deprecated scripts
2. **Resource Validation**: Checks for unused resources such as ports, directories, and logs
3. **Documentation Consistency**: Verifies that documentation correctly reflects the existing scripts and components
4. **Cleanup Operations**: Provides tools to safely remove unused resources

## How Usage Tracking Works

The `track_usage.sh` utility implements a comprehensive analysis process:

1. **File Discovery**: Scans all script directories to create an inventory of shell scripts
2. **Reference Analysis**: Searches for references to each script within:
   - Other scripts
   - Makefile targets
   - Docker Compose configurations
   - Documentation files
   - Integration scripts
3. **Documentation Comparison**: Cross-references the inventory with documentation to identify discrepancies
4. **Age-based Analysis**: Flags old, unused scripts as potential cleanup candidates

## How Cleanup is Performed

The `audit_and_cleanup.sh` script orchestrates the cleanup process:

1. **Dry Run Analysis**: By default, the system runs in "dry run" mode to identify cleanup candidates without making changes
2. **Backup Creation**: Before removing any files, backups are created at `/var/log/agency_stack/audit/backups/`
3. **Age-based Filtering**: Only files that have been unused for a certain period (default: 180 days) are removed
4. **Exclusion Support**: Critical components can be excluded from cleanup
5. **Logging**: Detailed logs are maintained for all actions

## Best Practices for Long-term Hygiene

To maintain a clean and efficient repository, follow these best practices:

1. **Run Regular Audits**: Schedule weekly or monthly audits using `make audit`
2. **Review Audit Reports**: Review the generated reports at `/var/log/agency_stack/audit/`
3. **Document All Scripts**: Ensure all scripts are properly documented in markdown files
4. **Remove Unused Resources**: Periodically clean up unused resources with `make cleanup`
5. **Update References**: When deprecating a script, ensure all references are updated
6. **Version Control**: Use Git tags to mark stable versions before major cleanups

## Using the Audit Tools

### Basic Usage

```bash
# Run a dry-run audit (no changes made)
make audit

# View the audit report
make audit-report

# Run cleanup with confirmation (will make changes)
make cleanup
```

### Advanced Usage

For more control, you can use the scripts directly:

```bash
# Track script usage with verbose output
sudo scripts/utils/track_usage.sh --verbose

# Run audit with custom directory
sudo scripts/utils/audit_and_cleanup.sh --scan-dir /path/to/custom/scripts

# Perform actual cleanup with a longer unused days threshold
sudo scripts/utils/audit_and_cleanup.sh --clean --max-unused-days 365

# Skip confirmation prompts (useful for automation)
sudo scripts/utils/audit_and_cleanup.sh --clean --force
```

## Configuration Options

The audit and cleanup tools support numerous configuration options:

### Script Tracking Options

- `--target-dir <dir>`: Directory to analyze
- `--include-dir <dir>`: Additional directory to include
- `--exclude <pattern>`: Exclude files matching pattern
- `--max-depth <number>`: Maximum directory depth to analyze
- `--skip-docs`: Skip documentation analysis
- `--skip-makefiles`: Skip Makefile analysis
- `--verbose`: Show detailed output

### Cleanup Options

- `--clean`: Perform actual cleanup (default is dry-run)
- `--force`: Skip confirmation prompts
- `--skip-tracking`: Skip script usage tracking phase
- `--exclude-component <name>`: Component to exclude from cleanup
- `--max-log-days <days>`: Maximum age of logs to keep (default: 30)
- `--max-unused-days <days>`: Only clean scripts older than this (default: 180)
- `--no-port-scan`: Skip unused port scanning
- `--no-git`: Disable Git-aware features

## Integration with CI/CD

The audit system can be integrated into CI/CD pipelines for automated monitoring:

```yaml
# Example GitHub Actions workflow
name: Repository Audit

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Audit
        run: |
          make audit
          make audit-report
```

## Understanding Audit Reports

The audit system generates several reports:

1. **Full Audit Report**: Comprehensive analysis log at `/var/log/agency_stack/audit/audit_report.log`
2. **Unused Scripts Report**: List of unused scripts at `/var/log/agency_stack/audit/unused_scripts.log`
3. **Documentation Inconsistencies**: Documentation issues at `/var/log/agency_stack/audit/inconsistent_docs.log`
4. **Summary Report**: High-level overview at `/var/log/agency_stack/audit/summary_YYYYMMDD.txt`

## Git-aware Features

When enabled, the Git-aware features provide additional insights:

1. **Modified But Unused**: Identifies scripts that have been recently modified but are not referenced
2. **Stale But Active**: Highlights scripts that haven't been updated in a long time but are still in use
3. **Commit History Analysis**: Examines commit patterns to identify potentially abandoned scripts

This feature requires that the repository is a Git repository and that the audit is run within the repository context.

## Troubleshooting

### False Positives

The audit system may occasionally flag scripts that are actually in use. This can happen if:

1. Scripts are referenced via dynamic paths
2. Scripts are called via system() functions in other languages
3. Scripts are referenced in excluded files

Review the full audit report and use `--exclude` patterns to reduce false positives.

### Permission Issues

Ensure the scripts are run with appropriate permissions. Most operations require root access:

```bash
sudo scripts/utils/audit_and_cleanup.sh
```

### Log Rotation

The audit system generates logs that should be rotated. Use the built-in log rotation:

```bash
make setup-log-rotation
```

## Conclusion

Regular use of the audit and cleanup system helps maintain a clean, efficient codebase by identifying and removing unused resources. By incorporating this into your maintenance routine, you can reduce technical debt and improve overall system performance.
