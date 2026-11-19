#!/usr/bin/env bash
# Builds the npm package of this fork: the official tinymce@<base> package from npm
# with the files that bundle DOMPurify replaced by the output of this repository's build.
#
# Usage: compan/pack.sh <version> [--build]
#   <version>  e.g. 7.9.3+compan.2 (base version + build metadata, see compan/README.md)
#   --build    run `yarn install --frozen-lockfile && yarn build` first
# Env: OUT_DIR  output directory (default: <repo>/../tinymce_compan-dist)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_DIR="$REPO_DIR/modules/tinymce"
BUILD_DIR="$MODULE_DIR/js/tinymce"
OUT_DIR="${OUT_DIR:-$REPO_DIR/../tinymce_compan-dist}"

fail() {
  echo "BŁĄD: $*" >&2
  exit 1
}

VERSION="${1:-}"
[ -n "$VERSION" ] || fail "podaj wersję paczki, np. compan/pack.sh 7.9.3+compan.2"
DO_BUILD="no"
if [ "${2:-}" = "--build" ]; then
  DO_BUILD="yes"
fi

BASE_VERSION="$(node -p "require('$MODULE_DIR/package.json').version")"
DOMPURIFY_VERSION="$(node -p "require('$MODULE_DIR/package.json').dependencies.dompurify")"

# A prerelease suffix (7.9.3-compan.1) does not satisfy ^7.0.0 required by @tinymce/tinymce-react -> ERESOLVE.
# Build metadata (7.9.3+compan.1) is ignored by semver ranges.
if ! [[ "$VERSION" =~ ^${BASE_VERSION//./\\.}\+compan\.[0-9]+$ ]]; then
  fail "wersja musi mieć postać ${BASE_VERSION}+compan.N (podano: $VERSION)"
fi
[[ "$DOMPURIFY_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || fail "dompurify w modules/tinymce/package.json musi być przypięty do dokładnej wersji (jest: $DOMPURIFY_VERSION)"

REPO_URL="$(git -C "$REPO_DIR" remote get-url origin)"
REPO_URL="${REPO_URL/git@github.com:/https://github.com/}"
TGZ_NAME="tinymce-${VERSION//+/-}.tgz"

echo "== baza: tinymce@$BASE_VERSION, DOMPurify: $DOMPURIFY_VERSION, wersja paczki: $VERSION"

if [ "$DO_BUILD" = "yes" ]; then
  echo "== build"
  (cd "$REPO_DIR" && yarn install --frozen-lockfile && yarn build)
fi
[ -f "$BUILD_DIR/tinymce.js" ] || fail "brak wyniku builda w $BUILD_DIR (uruchom z --build)"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "== pobieranie oficjalnej paczki tinymce@$BASE_VERSION"
(cd "$WORK_DIR" && npm pack "tinymce@$BASE_VERSION" --silent > /dev/null && tar xzf "tinymce-$BASE_VERSION.tgz")
PKG_DIR="$WORK_DIR/package"
BASE_FILE_COUNT="$(tar tzf "$WORK_DIR/tinymce-$BASE_VERSION.tgz" | wc -l)"

# Lists DOMPurify copies as "<file> <version>". Matches `X.version = "a.b.c"; X.removed = ...`,
# which is present in both plain and minified builds (minified files have no "DOMPurify" header).
find_dompurify() {
  (cd "$1" && node -e "
const fs = require('fs'), path = require('path')
const re = /\.version\s*=\s*['\"](\d+\.\d+\.\d+)['\"]\s*[,;]\s*\w+\.removed\s*=/g
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(path.join(d, e.name)) : e.name.endsWith('.js') ? [path.join(d, e.name)] : [])
for (const f of walk('.').sort()) {
  for (const m of fs.readFileSync(f, 'utf8').matchAll(re)) console.log(f + ' ' + m[1])
}
")
}

echo "== podmiana plików zawierających DOMPurify"
mapfile -t FILES < <(find_dompurify "$PKG_DIR" | cut -d' ' -f1 | sort -u)
FILES+=("notices.txt")
[ "${#FILES[@]}" -gt 1 ] || fail "nie znaleziono plików z DOMPurify w oficjalnej paczce"
for f in "${FILES[@]}"; do
  [ -f "$BUILD_DIR/$f" ] || fail "brak $f w wyniku builda"
  cp "$BUILD_DIR/$f" "$PKG_DIR/$f"
  echo "   $f"
done

echo "== CHANGELOG.md"
grep -q "^## ${VERSION//./\\.} " "$MODULE_DIR/CHANGELOG.md" \
  || fail "brak wpisu '## $VERSION - <data>' w modules/tinymce/CHANGELOG.md"
cp "$MODULE_DIR/CHANGELOG.md" "$PKG_DIR/CHANGELOG.md"

echo "== package.json"
(cd "$PKG_DIR" && node -e "
const fs = require('fs')
const p = JSON.parse(fs.readFileSync('package.json', 'utf8'))
p.version = '$VERSION'
p.repository = { type: 'git', url: '$REPO_URL', directory: 'modules/tinymce' }
fs.writeFileSync('package.json', JSON.stringify(p, null, '\t') + '\n')
")

echo "== weryfikacja"
FOUND="$(find_dompurify "$PKG_DIR")"
echo "$FOUND" | sed 's/^/   /'
if echo "$FOUND" | grep -v " $DOMPURIFY_VERSION\$" | grep -q .; then
  fail "w paczce jest inna wersja DOMPurify niż $DOMPURIFY_VERSION"
fi
grep -q "version: $DOMPURIFY_VERSION" "$PKG_DIR/notices.txt" || fail "notices.txt nie zawiera DOMPurify $DOMPURIFY_VERSION"

echo "== pakowanie"
(cd "$PKG_DIR" && npm pack --silent > /dev/null)
PACKED="$(ls "$PKG_DIR"/tinymce-*.tgz)"
FILE_COUNT="$(tar tzf "$PACKED" | wc -l)"
[ "$FILE_COUNT" = "$BASE_FILE_COUNT" ] || fail "liczba plików $FILE_COUNT różni się od oficjalnej paczki ($BASE_FILE_COUNT)"

mkdir -p "$OUT_DIR"
cp "$PACKED" "$OUT_DIR/$TGZ_NAME"
echo "== gotowe: $(cd "$OUT_DIR" && pwd)/$TGZ_NAME ($FILE_COUNT plików)"
echo "   sha512-$(openssl dgst -sha512 -binary "$OUT_DIR/$TGZ_NAME" | base64 -w0)"
