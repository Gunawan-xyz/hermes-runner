# Hermes Runner 24/7

Runner Linux (GitHub Actions, Ubuntu) khusus Hermes Agent yang jalan terus
dengan rantai auto-rerun: setiap sesi berjalan sampai mendekati batas 6 jam
job GitHub-hosted, memicu sesi berikutnya dari dalam, lalu selesai. State
Hermes (`~/.hermes`: konfigurasi, memori, skill, sesi) di-backup ke Supabase
Storage dan di-restore di awal sesi berikutnya, jadi Hermes melanjutkan
keadaan terakhir di mesin yang selalu baru.

## Cara kerja

- `hermes.yml` — sesi utama. Urutan: restore state → pasang Hermes + OpenCode
  → seed konfigurasi (run pertama saja) → smoke test model → gateway jalan →
  backup berkala tiap 30 menit → di menit ke-335 picu run berikutnya →
  backup akhir (`if: always()`).
- `hermes-watchdog.yml` — tiap 30 menit memeriksa rantai. Kalau tidak ada
  sesi aktif/antre, watchdog memicu sesi baru (rantai putus, smoke test
  gagal, atau run dibatalkan semuanya tertolong).
- `sync_memory.py` — pull/push backup zip ke bucket privat Supabase
  `hermes-data`, nama bertimestamp, rotasi 3 versi terakhir.

## Menghentikan rantai

1. Set repo **Variable** `CHAIN_ENABLED` = `false` (Settings → Secrets and
   variables → Actions → Variables).
2. Batalkan run yang sedang jalan. Watchdog tidak akan memicu lagi.

## Secrets yang wajib diisi (Settings → Secrets and variables → Actions)

| Nama | Isi |
|---|---|
| `SUPABASE_URL` | URL proyek Supabase tempat bucket `hermes-data` |
| `SUPABASE_KEY` | Kunci akses Supabase (service role) |
| `OPENCODE_API_KEY` | Rencana B saja: kunci OpenCode Zen bila jalur ACP gagal (boleh tetap placeholder) |
| `TELEGRAM_BOT_TOKEN` | Token bot Telegram untuk gateway (opsional, untuk chat dari HP) |
| `TELEGRAM_USER_ID` | ID numerik Telegram pemilik; hanya user ini yang dilayani bot |
| `TAILSCALE_AUTHKEY` | Auth key Tailscale untuk runner (disarankan reusable + ephemeral) |
| `SSH_PUBLIC_KEY` | Public key SSH pemilik untuk login admin ke runner |

## Akses SSH

Setiap sesi yang secret-nya lengkap memasang Tailscale + OpenSSH dan mencetak
hostname (`hermes-<run_id>`) serta IP tailnet di step "Setup Tailscale + SSH"
pada log run. Login dari perangkat mana pun di tailnet yang sama:
`ssh runner@<IP>`. Hostname berganti tiap sesi karena mesinnya selalu baru.
Bila kedua secret masih placeholder, langkah ini dilewati dan Hermes tetap
bisa dipakai lewat Telegram.

Tidak ada nilai kredensial yang boleh ditulis di berkas repo ini.

## Status verifikasi

Kerangka rantai, watchdog, dan sync sudah lengkap. Tiga hal dikunci pada
run uji pertama: perintah pasang Hermes yang persis (`install_hermes.sh`),
bentuk perintah one-shot untuk smoke test (`smoke_test.sh`), dan nama kunci
konfigurasi Hermes (`config.template.yaml`). Smoke test di awal sesi adalah
gerbangnya: sesi hanya dibuka kalau Hermes terbukti menjawab lewat OpenCode.
