#!/bin/bash
# Show the end of one expdb session: the point where LK stopped logging.
# A UEFI payload that ran and then hung or reset leaves LK's handoff records
# followed by silence; one that never started leaves LK's own error path.
#
# Usage: expdb-session-end.sh <start> <end> [txt] [tail-lines]
set -uo pipefail

START="$1"
END="$2"
TXT="${3:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-full-20261025-005209.txt}"
N="${4:-70}"

from=$((END - N))
[ "$from" -lt "$START" ] && from="$START"

echo "session lines $START..$END, showing $from..$END"
echo "---------------------------------------------------"
sed -n "${from},${END}p" "$TXT"
