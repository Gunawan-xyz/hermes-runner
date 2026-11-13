#!/usr/bin/env bash
# Smoke test model: Hermes harus menjawab satu prompt lewat provider OpenCode
# sebelum sesi dibuka. Gagal = run berhenti (watchdog mencoba lagi berkala).
# CATATAN UJI PERTAMA: bentuk perintah one-shot Hermes yang persis dikunci
# setelah uji pertama berhasil; kandidat di bawah dicoba berurutan dengan
# timeout dan stdin tertutup supaya mode interaktif tidak menggantung.
set -uo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

PROMPT="Balas hanya dengan kata SMOKE_OK tanpa tambahan apa pun."

try_cmd() {
  local desc="$1"; shift
  echo "Mencoba: $desc"
  local out
  out=$(timeout 120 "$@" "$PROMPT" </dev/null 2>&1 || true)
  echo "$out" | tail -3
  if echo "$out" | grep -q "SMOKE_OK"; then
    echo "Smoke test LULUS lewat: $desc"
    return 0
  fi
  return 1
}

try_cmd "hermes run"        hermes run        && exit 0
try_cmd "hermes chat -q"    hermes chat -q    && exit 0
try_cmd "hermes -p"         hermes -p         && exit 0

echo "Smoke test GAGAL: tidak ada bentuk perintah yang menjawab SMOKE_OK."
echo "Periksa konfigurasi provider/model di ~/.hermes/config.yaml dan kunci OPENCODE_API_KEY."
exit 1
