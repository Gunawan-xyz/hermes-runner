#!/usr/bin/env bash
# Pasang Hermes Agent + OpenCode di runner Ubuntu.
# CATATAN UJI PERTAMA: jalur pasang persisnya diverifikasi pada run uji
# pertama; kalau salah satu jalur di bawah berubah dari dokumentasi resmi,
# perbaiki di berkas ini saja (satu tempat).
set -euo pipefail

echo "== Pasang OpenCode =="
curl -fsSL https://opencode.ai/install | bash
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version || true

echo "== Pasang Hermes Agent =="
# Jalur utama: installer resmi Nous (mengambil rilis terbaru dari GitHub).
# Pelajaran run uji kedua (13 Nov): jalur pip PyPI memasang v0.15.2 yang
# terlalu tua; plugin ACP butuh Hermes >= 0.22.2. pip hanya cadangan.
if curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash; then
  echo "Installer resmi selesai."
else
  echo "Installer resmi gagal, jatuh ke pip."
  python3 -m pip install --user --upgrade hermes-agent
fi
export PATH="$HOME/.local/bin:$PATH"
hermes --version || true

echo "== Pasang plugin OpenCode Free ACP =="
# Menjalankan OpenCode CLI asli lewat ACP supaya free tier bawaan OpenCode
# bisa dipakai Hermes tanpa API key (prinsip yang sama dengan Paperclip).
# Idempotent: state hasil restore bisa sudah memuat plugin-nya (run uji
# kedua menabrak "already exists"), jadi kegagalan install dicoba update.
hermes plugins install cryptobredda/hermes-opencode-free-acp --enable \
  || hermes plugins update opencode-free-acp \
  || echo "PERINGATAN: pasang plugin gagal, smoke test akan menentukan."

echo "Pemasangan selesai."
