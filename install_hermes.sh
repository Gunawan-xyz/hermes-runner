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
# kedua menabrak "already exists"). Hasil restore berupa zip juga membuat
# `plugins update` menolak ("no owned Git checkout", run uji ketiga), jadi
# jalurnya: copot dulu salinan lama (abaikan bila tidak ada), baru pasang
# segar dari repo-nya.
hermes plugins uninstall opencode-free-acp || true
hermes plugins install cryptobredda/hermes-opencode-free-acp --enable \
  || echo "PERINGATAN: pasang plugin gagal, smoke test akan menentukan."

echo "== Pasang plugin OpenCode ACP (jovylle) =="
# Plugin kedua, slug provider "opencode-acp", basis harian penulisnya di
# Hermes 0.21.x + OpenCode 1.18.x. Cara pasang resminya sudah Lyra audit
# 13 Nov: skrip install-plugin.sh hanya menyalin folder plugin/ ke
# ~/.hermes/plugins/model-providers/opencode-acp, jadi penyalinan yang sama
# dilakukan langsung di sini, lalu plugin diaktifkan.
rm -rf /tmp/hermes-opencode-acp
if git clone -q --depth 1 https://github.com/jovylle/hermes-opencode-acp.git /tmp/hermes-opencode-acp; then
  mkdir -p "$HOME/.hermes/plugins/model-providers"
  rm -rf "$HOME/.hermes/plugins/model-providers/opencode-acp"
  cp -R /tmp/hermes-opencode-acp/plugin "$HOME/.hermes/plugins/model-providers/opencode-acp"
  rm -rf "$HOME/.hermes/plugins/model-providers/opencode-acp/__pycache__"
  hermes plugins enable opencode-acp-provider || true
  hermes plugins validate "$HOME/.hermes/plugins/model-providers/opencode-acp" || true
else
  echo "PERINGATAN: clone plugin jovylle gagal, lewati."
fi

echo "Pemasangan selesai."
