#!/usr/bin/env python3
"""Backup & restore state Hermes Agent (~/.hermes) ke Supabase Storage.

Versi Linux dari sync_memory.py lama (RDP-Awan), dengan perbaikan:
- Nama backup bertimestamp, bukan satu file ditimpa terus.
- Rotasi: hanya 3 backup terakhir yang disimpan.
- pull mengambil backup terbaru; kalau belum ada backup, keluar wajar (exit 0).

Kredensial dari environment: SUPABASE_URL, SUPABASE_KEY (GitHub Secrets).
Hanya memakai library standar Python.
"""
import json
import os
import shutil
import sys
import urllib.request
from datetime import datetime, timezone

SUPABASE_URL = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY") or ""
BUCKET = "hermes-data"
KEEP = 3
HERMES_DIR = os.path.expanduser("~/.hermes")
TMP_BASE = os.path.expanduser("~/hermes_backup")


def _req(method, url, data=None, extra_headers=None):
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    return urllib.request.urlopen(req, timeout=180)


def list_backups():
    """Kembalikan daftar nama backup, terlama -> terbaru."""
    url = f"{SUPABASE_URL}/storage/v1/object/list/{BUCKET}"
    payload = json.dumps({"prefix": "", "limit": 100}).encode()
    with _req("POST", url, payload, {"Content-Type": "application/json"}) as resp:
        items = json.loads(resp.read().decode())
    names = [it["name"] for it in items if it.get("name", "").startswith("hermes-") and it["name"].endswith(".zip")]
    return sorted(names)


def delete_objects(names):
    if not names:
        return
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}"
    payload = json.dumps({"prefixes": names}).encode()
    with _req("DELETE", url, payload, {"Content-Type": "application/json"}) as resp:
        resp.read()


def pull():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("SUPABASE_URL/SUPABASE_KEY belum di-set, lewati restore.")
        return
    try:
        names = list_backups()
    except Exception as e:
        print(f"Gagal membaca daftar backup ({e}), mulai dari keadaan segar.")
        return
    if not names:
        print("Belum ada backup di Supabase, mulai dari keadaan segar.")
        return
    latest = names[-1]
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{latest}"
    zip_path = f"{TMP_BASE}.zip"
    print(f"Mengunduh backup {latest} ...")
    try:
        with _req("GET", url) as resp, open(zip_path, "wb") as f:
            shutil.copyfileobj(resp, f)
        os.makedirs(HERMES_DIR, exist_ok=True)
        shutil.unpack_archive(zip_path, HERMES_DIR)
        print(f"State Hermes berhasil di-restore dari {latest} ke {HERMES_DIR}")
    except Exception as e:
        print(f"Gagal restore ({e}), mulai dari keadaan segar.")


# Bagian aplikasi BUKAN state: installer resmi Hermes mengkloning aplikasi ke
# ~/.hermes/hermes-agent dan membuat venv; itu dipasang ulang tiap run dan
# tidak boleh ikut backup (run uji ketiga: zip membengkak, upload ditolak
# Supabase HTTP 400). Nama generik menutup variasi tata letak antar versi.
SKIP_DIRS = {"hermes-agent", "venv", ".venv", "node_modules", ".git",
             "__pycache__", ".cache"}


def build_zip(zip_path):
    import zipfile

    sizes = {}
    total = 0
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(HERMES_DIR):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for fn in files:
                full = os.path.join(root, fn)
                try:
                    sz = os.path.getsize(full)
                except OSError:
                    continue
                rel = os.path.relpath(full, HERMES_DIR)
                sizes[rel.split(os.sep)[0]] = sizes.get(rel.split(os.sep)[0], 0) + sz
                total += sz
                z.write(full, rel)
    print("Isi backup per folder teratas (MB):")
    for top, sz in sorted(sizes.items(), key=lambda kv: -kv[1])[:10]:
        print(f"  {top}: {sz / 1e6:.1f}")
    print(f"Total isi sebelum kompresi: {total / 1e6:.1f} MB")
    if total > 45_000_000:
        print("PERINGATAN: isi backup melebihi 45 MB, rawan ditolak batas berkas Supabase.")
    return zip_path


def push():
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("SUPABASE_URL/SUPABASE_KEY belum di-set, lewati backup.")
        return
    if not os.path.isdir(HERMES_DIR):
        print(f"{HERMES_DIR} tidak ditemukan, lewati backup.")
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    name = f"hermes-{stamp}.zip"
    print(f"Membuat backup {name} dari {HERMES_DIR} ...")
    zip_path = build_zip(f"{TMP_BASE}.zip")
    url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET}/{name}"
    with open(zip_path, "rb") as f:
        payload = f.read()
    try:
        with _req("POST", url, payload, {"Content-Type": "application/zip", "x-upsert": "true"}) as resp:
            resp.read()
        print(f"Backup {name} tersimpan di Supabase.")
    except Exception as e:
        print(f"Gagal upload backup: {e}")
        return
    # Rotasi: sisakan KEEP backup terbaru.
    try:
        names = list_backups()
        excess = names[:-KEEP] if len(names) > KEEP else []
        if excess:
            delete_objects(excess)
            print(f"Rotasi: menghapus {len(excess)} backup lama.")
    except Exception as e:
        print(f"Rotasi backup dilewati ({e}).")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "pull":
        pull()
    elif len(sys.argv) > 1 and sys.argv[1] == "push":
        push()
    else:
        print("Pemakaian: sync_memory.py pull|push")
        sys.exit(2)
