# Checklist: Manual Verification & Merge Before Script Removal

_Last updated: 2025-05-15 00:25:28-05:00_

## Purpose
Before deleting any "Needs Review" scripts, ensure all unique and valuable logic is merged into the main stack scripts. Use this checklist to guide manual review and merging.

---

## 1. install_peacefestivalusa_wordpress_did.sh → install_peacefestivalusa_wordpress.sh
- [ ] Confirm Docker-in-Docker (DID) mode is fully supported in the main installer.
- [ ] Ensure all config/env flags from DID script are available as options.
- [ ] Merge any unique credential or networking logic if present.

## 2. deploy_peacefestivalusa_full.sh → deploy_peacefestivalusa.sh
- [ ] Integrate test-running logic (add `--run-tests` or similar flag to main deploy script).
- [ ] Ensure environment config saving from full script is present in main script.
- [ ] Remove any redundancy in argument parsing or container setup.

## 3. deploy_peacefestivalusa_remote.sh → deploy_peacefestivalusa.sh
- [ ] Confirm all SSH/remote deployment logic is present in main script.
- [ ] Merge any unique file sync, DB sync, or dry-run logic as options.
- [ ] Ensure remote deploy is well-documented in main script help output.

## 4. peacefestivalusa_http_fix.sh → deploy_peacefestivalusa.sh / test_peacefestivalusa_wordpress.sh
- [ ] Add HTTP-only mode as a flag (e.g., `--http-only`) if not present.
- [ ] Merge any unique Traefik config/test artifact logic.
- [ ] Ensure all test outputs and logs are handled in main scripts.

## 5. peacefestivalusa_test_fix.sh → test_peacefestivalusa_wordpress.sh
- [ ] Merge any unique test artifact creation (e.g., verify-deployment.php logic).
- [ ] Ensure all TDD-oriented test logic is upstreamed.
- [ ] Remove any redundant or obsolete test steps.

---

## Final Steps
- [ ] Document all changes in `/scripts/classification_peacefestivalusa.md` and script comments.
- [ ] After verification and merging, safely remove redundant scripts.
- [ ] Commit changes and update tasks in the project tracker.
