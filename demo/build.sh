#!/usr/bin/env bash
# Builds the UI-only demo into build/demo (see demo/main.dart).
# fake_cloud_firestore's FieldValue factory is a test mock, which release
# builds refuse (asserts are off), so the build uses a copy where it
# extends the real platform class instead. The override is removed after.
set -euo pipefail
cd "$(dirname "$0")/.."
src=$(sed -n 's|.*"rootUri": "file://\(.*fake_cloud_firestore-[^"]*\)".*|\1|p' .dart_tool/package_config.json)
pkg=build/demo_pkgs/fake_cloud_firestore
rm -rf "$pkg" && mkdir -p build/demo_pkgs && cp -r "$src" "$pkg"
python3 - "$pkg/lib/src/mock_field_value_factory_platform.dart" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s2 = re.sub(r'class MockFieldValueFactoryPlatform\s+with[^{]*?implements\s+FieldValueFactoryPlatform',
            'class MockFieldValueFactoryPlatform extends FieldValueFactoryPlatform', s, flags=re.S)
assert s2 != s, 'patch did not apply'
open(p, 'w').write(s2)
PY
printf 'dependency_overrides:\n  fake_cloud_firestore:\n    path: %s\n' "$pkg" > pubspec_overrides.yaml
trap 'rm -f pubspec_overrides.yaml; flutter pub get >/dev/null' EXIT
flutter pub get >/dev/null
flutter build web -t demo/main.dart --release --no-web-resources-cdn \
  --no-wasm-dry-run --output build/demo
cp demo/index.html build/demo/index.html
# No service worker: the demo is served as a plain page.
python3 - build/demo/flutter_bootstrap.js <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
open(p, 'w').write(s[:s.index('_flutter.loader.load({')] + '_flutter.loader.load({});\n')
PY
