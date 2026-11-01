#!/bin/bash
# Show the tail of the most recent LK session: what LK did immediately before
# it stopped logging. If our payload ran and died, the last records would be
# LK's own handoff messages followed by silence.
#
# Usage: expdb-tail.sh [txt] [lines]
set -uo pipefail

TXT="${1:-/mnt/d/漏洞/UNIXNU/适配K70U/work/expdb/expdb-full-20261025-005209.txt}"
N="${2:-120}"

echo "file: $TXT"
echo "total lines: $(wc -l < "$TXT")"
echo "---------------------------------------------------"
tail -n "$N" "$TXT"
