#!/usr/bin/bash
set -Eeuo pipefail
PATH=/usr/bin:/bin
export PATH

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$repo_dir/installation/lib/installer.sh"
infinity_installer_main "$@"
