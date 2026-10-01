#!/bin/sh
# Usage (from an empty directory):  sh /path/to/scripts/run_m0.sh
set -e
D="$(cd "$(dirname "$0")" && pwd)"
sh "$D/setup_sources.sh"
python3 "$D/att_parse.py" AllTheThings/.contrib/.db/forever forever_quests.json
python3 "$D/quest_sets.py"
python3 "$D/fp_check.py" | sed -n 1,6p
python3 "$D/questie_cov.py" | sed -n 1,16p
