#!/usr/bin/env bash
# Smoke test model: Hermes harus BENAR-BENAR menjawab lewat provider
# opencode-zen (API key) sebelum sesi dibuka. (BRANCH api-key-saja)
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
# BRANCH api-key-saja (13 Nov malam, permintaan Awan): satu-satunya
# kandidat adalah config saja. Di branch ini config menunjuk provider
# opencode-zen (API key), jadi lulus di sini berarti gateway Telegram
# berjalan murni lewat API key, tanpa ACP dan tanpa fallback.
try_cmd "config saja (opencode-zen, API key)" \
  hermes chat -q "$PROMPT" -Q --max-turns 2 && exit 0

echo "Smoke test GAGAL: jalur API key (opencode-zen) tidak menjawab dengan benar."
echo "Periksa: OPENCODE_ZEN_API_KEY terisi di ~/.hermes/.env? Batas pemakaian model gratis Zen?"
exit 1
