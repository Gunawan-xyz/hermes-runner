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
# Jalur pip (paket resmi Nous Research: hermes-agent).
python3 -m pip install --user --upgrade hermes-agent
export PATH="$HOME/.local/bin:$PATH"
hermes --version || true

echo "Pemasangan selesai."
