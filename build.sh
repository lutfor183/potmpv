#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$HERE/VERSION" 2>/dev/null || echo 1.0.0)"
NAME="potmpv-$VERSION-portable"
OUT="$HERE/dist"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/$NAME"
cp -f "$HERE/mpv.conf" "$HERE/input.conf" "$HERE/README.md" "$WORK/$NAME/" 2>/dev/null || true
cp -rf "$HERE/scripts" "$HERE/script-opts" "$HERE/fonts" "$WORK/$NAME/"
cat > "$WORK/$NAME/potmpv" <<'L'
#!/usr/bin/env bash
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec mpv --config-dir="$D" -- "$@"
L
chmod +x "$WORK/$NAME/potmpv"
mkdir -p "$OUT"
tar -C "$WORK" -czf "$OUT/$NAME.tar.gz" "$NAME"
sha256sum "$OUT/$NAME.tar.gz" | sed "s#$OUT/##" > "$OUT/$NAME.tar.gz.sha256"
echo "Built $OUT/$NAME.tar.gz"
