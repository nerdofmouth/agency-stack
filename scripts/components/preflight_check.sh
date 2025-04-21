#!/bin/bash
# DEPRECATED: All preflight and prerequisite logic is now unified in scripts/utils/common.sh (function: preflight_check_agencystack)
# This script is obsolete and will be removed after migration is complete.

source "$(dirname "$0")/../utils/common.sh"
preflight_check_agencystack
exit $?
