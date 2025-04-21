#!/usr/bin/env python3
import os
import json
from pathlib import Path

REGISTRY_PATH = Path("config/registry/component_registry.json")
SCRIPT_DIR = Path("scripts/components")

# 1. Find all install scripts
script_files = list(SCRIPT_DIR.glob("install_*.sh"))
script_names = set(f.stem.replace("install_", "") for f in script_files)

# 2. Parse registry
with REGISTRY_PATH.open() as f:
    registry = json.load(f)

components = registry.get("components", {})
# Flatten registry keys to match script names
registry_names = set()
for section in components.values():
    for comp_id in section.keys():
        registry_names.add(comp_id.lower())

# 3. Discrepancy checks
missing_in_registry = script_names - registry_names
missing_script = registry_names - script_names

print("=== Registry vs Install Script Audit ===")
print(f"Found {len(script_names)} install scripts and {len(registry_names)} registry entries.")

if missing_in_registry:
    print("\nInstall scripts NOT in registry:")
    for name in sorted(missing_in_registry):
        print(f"  - {name} (add to registry!)")
else:
    print("\nAll install scripts are tracked in the registry.")

if missing_script:
    print("\nRegistry entries with NO install script:")
    for name in sorted(missing_script):
        print(f"  - {name} (implement install_{name}.sh)")
else:
    print("\nAll registry components have install scripts.")

print("\nAudit complete.")
