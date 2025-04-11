# 🧪 AgencyStack Status Dashboard – UI Spec

## Purpose
The status dashboard lets developers, clients, and agents visually verify which components are live and working on a given VM.

## Key Features
- ✅ Real-time list of components with ✅ / ❌ / ⚠️ status
- 🔄 Buttons to restart, view logs, or reinstall components
- 🔒 Show SSO status per component (locked/unlocked)
- 🔍 Show current public ports, TLS state, and load
- 📊 Display system metrics (RAM, CPU, Disk, Net)
- 🛠️ Export snapshot report for sharing

## View Modes
- 🧪 Admin/Dev (all info + logs)
- 👨‍💼 Client (summary only, hides internal errors)
- 🤖 Agent (machine-parsable JSON output)

## Data Sources
- `make <component>-status`
- `scripts/utils/registry_parser.sh`
- `/var/log/agency_stack/components/`
- `/opt/agency_stack/healthstamp`

## UI Component Layout (Wireframe)
