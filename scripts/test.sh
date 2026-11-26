#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

echo '[TEST] Checking the training release package'
sha256sum -c dist/SHA256SUMS
contents="$(tar -tzf dist/clientflowcrm.tar.gz)"
printf '%s\n' "$contents" | grep -qx 'project.env'
printf '%s\n' "$contents" | grep -qx 'spec/modules.tsv'
printf '%s\n' "$contents" | grep -qx 'spec/acceptance.md'
tar -xOzf dist/clientflowcrm.tar.gz project.env | grep -qx 'PROJECT_NAME=ClientFlowCRM'
for module in clients contacts deals tasks reports; do
  tar -xOzf dist/clientflowcrm.tar.gz spec/modules.tsv | awk -F '\t' -v name="$module" '
    $1 == name {found = 1}
    END {exit !found}
  '
  printf '[PASS] Module specification included: %s\n' "$module"
done
echo '[TEST] Archive integrity, project identity and all five module specifications passed'
