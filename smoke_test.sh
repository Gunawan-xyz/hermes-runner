#!/usr/bin/env bash
# Smoke test model: Hermes harus BENAR-BENAR menjawab lewat provider ACP
# OpenCode sebelum sesi dibuka.
#
# Pelajaran run uji pertama (13 Nov): kriteria lama longgar (grep kata
# SMOKE_OK di output mana pun) menghasilkan LULUS PALSU, karena pesan error
# argparse ("unrecognized arguments: <prompt>") ikut memuat teks prompt-nya.
# Kriteria sekarang ketat dan tidak bisa dipalsukan gema prompt:
# - prompt meminta hitungan yang jawabannya TIDAK ada di teks prompt (37+5=42)
# - lulus hanya bila exit code 0 DAN ada baris output yang persis "42"
# - output yang mengandung "error:" / "usage:" otomatis gugur
set -uo pipefail
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"

PROMPT="Berapa hasil 37 tambah 5? Balas hanya angkanya saja, tanpa kata lain, tanpa tanda baca."
JAWABAN="42"

try_cmd() {
  local desc="$1"; shift
  echo "Mencoba: $desc"
  local out rc
  out=$(timeout 180 "$@" </dev/null 2>&1); rc=$?
  echo "$out" | tail -5
  if [ $rc -ne 0 ]; then
    echo "-> gagal (exit $rc)"
    return 1
  fi
  if echo "$out" | grep -qiE "error:|usage:"; then
    echo "-> gagal (output berisi error/usage)"
    return 1
  fi
  if echo "$out" | sed 's/\r$//' | grep -qx "[[:space:]]*$JAWABAN[[:space:]]*"; then
    echo "Smoke test LULUS lewat: $desc"
    return 0
  fi
  echo "-> gagal (jawaban persis '$JAWABAN' tidak ditemukan)"
  return 1
}

# Bentuk one-shot Hermes: hermes chat -q "<prompt>" (prompt adalah NILAI
# dari -q, bukan argumen posisi bebas; posisi bebas ditolak argparse pada
# run uji pertama). Kandidat mencakup dua plugin ACP dan hanya model yang
# memang terdaftar gratis di katalog OpenCode (big-pickle TIDAK termasuk
# daftar gratis plugin, hasil temuan run uji keempat):
# - jovylle/hermes-opencode-acp, slug "opencode-acp", model contoh penulisnya
#   opencode/deepseek-v4.1-flash-free dan opencode/mimo-v2.5-free
# - cryptobredda/hermes-opencode-free-acp, slug "opencode-free-acp", model
#   yang dinyatakan sudah diuji langsung penulisnya: deepseek-v4.1-flash-free
#   dan glm-5.3-flash-free
# Bentuk flag divariasikan (dengan -Q, dengan --max-turns, polos) supaya satu
# perbedaan parser antar versi Hermes tidak menggugurkan semua kandidat.
try_cmd "opencode-acp deepseek-flash-free (-Q)" \
  hermes chat -q "$PROMPT" -Q --max-turns 2 --provider opencode-acp --model opencode/deepseek-v4.1-flash-free && exit 0
try_cmd "opencode-acp mimo-free" \
  hermes chat -q "$PROMPT" --max-turns 2 --provider opencode-acp --model opencode/mimo-v2.5-free && exit 0
try_cmd "opencode-free-acp deepseek-flash-free" \
  hermes chat -q "$PROMPT" --provider opencode-free-acp --model opencode/deepseek-v4.1-flash-free && exit 0
try_cmd "opencode-free-acp glm-flash-free" \
  hermes chat -q "$PROMPT" --provider opencode-free-acp --model opencode/glm-5.3-flash-free && exit 0

echo "Smoke test GAGAL: tidak ada jalur model yang menjawab dengan benar."
echo "Periksa: plugin opencode-free-acp terpasang? OpenCode CLI bisa jalan? Konfigurasi di ~/.hermes/config.yaml."
exit 1
