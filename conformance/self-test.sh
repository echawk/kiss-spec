#!/bin/sh
# Verify the harness itself with two deliberately identical mock KISS CLIs.
set -eu
base=$(mktemp -d "${TMPDIR:-/tmp}/kiss-conformance-self.XXXXXX")
trap 'rm -rf "$base"' EXIT HUP INT TERM
for name in reference candidate; do
    cat > "$base/$name" <<'EOF'
#!/bin/sh
case "$1" in
  version) printf '6.2.0\n' ;;
  list) printf 'demo 1-1\n' ;;
  *) exit 2 ;;
esac
EOF
    chmod 755 "$base/$name"
done
output=$("$(dirname "$0")/core.sh" "$base/reference" "$base/candidate" \
    version list-installed)
printf '%s\n' "$output"
case "$output" in
  *"conformance: 2 passed, 0 failed, 0 skipped"*"conformance: PASS") ;;
  *)
      echo "self-test: missing successful conformance summary" >&2
      exit 1
      ;;
esac
