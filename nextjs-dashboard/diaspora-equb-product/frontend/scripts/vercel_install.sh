#!/usr/bin/env bash
set -euo pipefail

readonly flutter_bin="./.flutter/bin/flutter"
readonly dart_bin="./.flutter/bin/dart"

if [ ! -d .flutter ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable .flutter
fi

"$flutter_bin" config --enable-web
"$flutter_bin" pub get

pushd seo_landing >/dev/null
../.flutter/bin/dart pub get
popd >/dev/null

"$dart_bin" pub global activate jaspr_cli 0.22.3
