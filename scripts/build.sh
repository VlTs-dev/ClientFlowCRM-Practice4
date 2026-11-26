#!/usr/bin/env bash
set -euo pipefail
export PATH="/usr/bin:/bin:$PATH"

echo '[BUILD] Preparing the ClientFlowCRM training release'
mkdir -p dist
tar -czf dist/clientflowcrm.tar.gz project.env spec
sha256sum dist/clientflowcrm.tar.gz > dist/SHA256SUMS
{
  printf 'project=ClientFlowCRM\n'
  printf 'build=%s\n' "${BUILD_NUMBER:-local}"
  printf 'commit=%s\n' "${GIT_COMMIT:-$(git rev-parse HEAD 2>/dev/null || printf local)}"
  printf 'created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'mode=educational_simulation\n'
} > dist/build-info.txt
if [[ -n "${CRM_DEMO_TOKEN:-}" ]]; then
  echo '[BUILD] Demo credential was supplied by Jenkins Credentials (value hidden)'
fi
echo '[BUILD] Release archive and checksum created'
