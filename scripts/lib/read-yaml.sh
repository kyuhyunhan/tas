#!/bin/bash
# Shared YAML reader. Sourced by every resolve/gate script so there is
# exactly one YAML parse implementation in the forge.
#
# Usage:
#   source .claude/scripts/lib/read-yaml.sh
#   value=$(read_yaml path/to/file.yaml "some.nested.key")
#   list=$(read_yaml_list path/to/file.yaml "some.list")
#
# Requires: python3 with the `yaml` module (PyYAML). Falls back gracefully
# if absent — emits a clear error.

read_yaml() {
    local file="$1"
    local key_path="$2"
    python3 - "$file" "$key_path" <<'PY'
import sys, yaml
file_path, key_path = sys.argv[1], sys.argv[2]
try:
    with open(file_path) as f:
        cfg = yaml.safe_load(f)
except FileNotFoundError:
    print(f"ERROR: file not found: {file_path}", file=sys.stderr); sys.exit(2)
except yaml.YAMLError as e:
    print(f"ERROR: invalid YAML in {file_path}: {e}", file=sys.stderr); sys.exit(2)

val = cfg
for k in key_path.split('.'):
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        sys.exit(0)   # silent miss; caller checks for empty
if isinstance(val, (str, int, float, bool)):
    print(val)
elif val is None:
    pass
else:
    import json
    print(json.dumps(val))
PY
}

read_yaml_list() {
    local file="$1"
    local key_path="$2"
    python3 - "$file" "$key_path" <<'PY'
import sys, yaml
file_path, key_path = sys.argv[1], sys.argv[2]
with open(file_path) as f:
    cfg = yaml.safe_load(f)
val = cfg
for k in key_path.split('.'):
    val = val.get(k) if isinstance(val, dict) else None
    if val is None:
        sys.exit(0)
if isinstance(val, list):
    for item in val:
        if isinstance(item, (str, int, float, bool)):
            print(item)
        else:
            import json
            print(json.dumps(item))
PY
}

read_yaml_keys() {
    # Print top-level keys at a given path
    local file="$1"
    local key_path="$2"
    python3 - "$file" "$key_path" <<'PY'
import sys, yaml
file_path, key_path = sys.argv[1], sys.argv[2]
with open(file_path) as f:
    cfg = yaml.safe_load(f)
val = cfg
for k in key_path.split('.'):
    val = val.get(k) if isinstance(val, dict) else None
    if val is None:
        sys.exit(0)
if isinstance(val, dict):
    for k in val:
        print(k)
PY
}
