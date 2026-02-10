#!/usr/bin/env bash

# shellcheck disable=2086

set -euo pipefail

package=$1
flags=${2:-}

$NIX build --out-link $package $flags .#$package

# see ../../../flake.nix for explanation
$NIX profile add .#saveFromGC

# put it on the PATH
echo $GITHUB_WORKSPACE/$package/bin >>$GITHUB_PATH

# graph dependencies
{
  stem=$package-$SYSTEM

  # mermaid
  MMD=$stem.mmd
  echo MMD=$MMD >>$GITHUB_ENV
  # $NIX_DEVELOP_COMMAND scripts/nix2mermaid.py $package >$MMD
  scripts/nix2mermaid.py --min-size 10 $package >$MMD

  # svg
  SVG=$stem.svg
  echo SVG=$SVG >>$GITHUB_ENV
  $NIX_DEVELOP_COMMAND mmdc -i $MMD -o $SVG

  # add to step summary
  cat <<EOF >>$GITHUB_STEP_SUMMARY
### ❄️ $package
* package: $(readlink $package)
* size: $(nix path-info --size --human-readable $package | cut -d" " -f2-)
* closure size: $(nix path-info --closure-size --human-readable $package | cut -d" " -f2-)
\`\`\`mermaid'
$(cat $MMD)
\`\`\`
EOF

} || {
  echo "::warning ::dependency graph failed"
}
