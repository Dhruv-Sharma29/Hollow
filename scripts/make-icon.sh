#!/bin/zsh
# Rebuilds the art inside branding/Hollow.icon from the two logo renders.
# The crops are full-bleed squares inside each logo's rounded square, inset ~4% so none of
# the render's background shows; macOS applies its own rounded mask. Adjust if the logos change.
set -euo pipefail
cd "${0:A:h}/../branding"
crop() {  # crop <logo> <side> <offset-y> <offset-x> <out>
  sips -c $2 $2 --cropOffset $3 $4 "$1" --out "$5" >/dev/null
  sips -z 1024 1024 "$5" >/dev/null
}
crop logo-dark.png 848 182 200 Hollow.icon/Assets/dark.png
crop logo-light.png 866 197 191 Hollow.icon/Assets/light.png
echo "updated branding/Hollow.icon"
