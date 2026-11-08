#!/usr/bin/env bash
# Prints the messages from an orca-wait.sh output file: the delivery id, then each message's id, type, sender and body.
# Usage: read-mail.sh <orca-wait output file>
set -euo pipefail
python3 - "$1" <<'EOF'
import json, sys
text = open(sys.argv[1]).read()
if "{" not in text:
    sys.exit("no delivery in " + sys.argv[1])
data = json.loads(text[text.index("{"):text.rindex("}") + 1])
if data.get("timeout"):
    print("timeout: no messages")
    sys.exit(0)
print("delivery:", data.get("delivery"))
for m in data.get("messages", []):
    print(f"\n{m['id']} {m['type']} {m['from_handle']}\n{m['body']}")
EOF
