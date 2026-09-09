#!/bin/bash
set -e

# Convert an am/pm time to 24-hour time.
# Usage: ampm.sh <time>
# Examples:
#   ampm.sh "9:30pm"   -> 21:30
#   ampm.sh "9pm"      -> 21:00
#   ampm.sh "12:15am"  -> 00:15

if [[ -z "$1" ]]; then
    echo "Usage: $(basename "$0") <time, e.g. '9:30pm'>"
    exit 1
fi

INPUT="$*"

date -d "$INPUT" "+%H:%M"
