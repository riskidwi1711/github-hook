#!/bin/bash

# Berhenti jika terjadi error
set -e

# --- Konfigurasi Utama (WAJIB DIUBAH SESUAI KEBUTUHAN) ---
# Direktori utama tempat semua repositori akan di-clone
DEPLOY_DIR="/home/riski/deployments" # Ganti dengan path absolut Anda
# ---------------------------------------------------------

# --- Fungsi untuk mencari port acak yang tersedia ---
find_random_available_port() {
  MIN_PORT=49152
  MAX_PORT=65535
  echo "Mencari port acak yang tersedia antara $MIN_PORT dan $MAX_PORT..." >&2
  for i in {1..100}; do
    RANDOM_PORT=$(shuf -i $MIN_PORT-$MAX_PORT -n 1)
    # Cek apakah port sudah digunakan oleh TCP atau UDP
    if ! ss -lntu | grep -q ":$RANDOM_PORT"; then
      echo "$RANDOM_PORT"
      return
    fi
  done
  echo "Error: Tidak dapat menemukan port yang tersedia setelah 100 percobaan." >&2
  exit 1
}

# Cari dan tetapkan port yang tersedia untuk host
HOST_PORT=$(find_random_available_port)
echo "Port host yang akan digunakan: $HOST_PORT"

# 1. Validasi Input
REPO_URL=$1
if [ -z "$REPO_URL" ]; then
  echo "Error: URL Repositori tidak diberikan." >&2
  exit 1
fi

# 2. Buat nama direktori & nama Docker dari URL repo
REPO_NAME=$(basename -s .git "$REPO_URL")
TARGET_DIR="$DEPLOY_DIR/$REPO_NAME"
IMAGE_NAME=$(echo "$REPO_NAME" | tr '[:upper:]' '[:lower:]') # Nama image harus lowercase
CONTAINER_NAME="${IMAGE_NAME}-container"

echo "--- Memulai Deployment untuk: $REPO_NAME ---"

# 3. Buat direktori deployment utama jika belum ada
mkdir -p "$DEPLOY_DIR"

# 4. Sinkronisasi repositori (Clone atau Pull)
if [ -d "$TARGET_DIR" ]; then
  echo "Repositori sudah ada. Menjalankan git pull..."
  cd "$TARGET_DIR"
  git pull
else
  echo "Repositori belum ada. Menjalankan git clone..."
  git clone "$REPO_URL" "$TARGET_DIR"
  cd "$TARGET_DIR"
fi
echo "Sinkronisasi kode selesai. Sekarang berada di direktori: $(pwd)"

# --- Deteksi Port dari Dockerfile ---
echo "Mendeteksi port yang diekspos dari Dockerfile..."
if [ ! -f "Dockerfile" ]; then
    echo "Error: Dockerfile tidak ditemukan di root repositori." >&2
    exit 1
fi
# Cari baris EXPOSE, abaikan komentar, ambil baris terakhir jika ada banyak
EXPOSE_LINE=$(grep -i '^[[:space:]]*EXPOSE' Dockerfile | tail -n 1)

if [ -z "$EXPOSE_LINE" ]; then
  echo "Error: Tidak ada instruksi EXPOSE yang valid ditemukan di Dockerfile." >&2
  exit 1
fi

# Ekstrak nomor port (ambil field kedua dan hapus '/tcp' atau '/udp' jika ada)
CONTAINER_PORT=$(echo "$EXPOSE_LINE" | awk '{print $2}' | sed 's|/.*||')

if ! [[ "$CONTAINER_PORT" =~ ^[0-9]+$ ]]; then
    echo "Error: Port yang diekstrak '$CONTAINER_PORT' bukan angka yang valid." >&2
    exit 1
fi
echo "Port container yang terdeteksi: $CONTAINER_PORT"
# ------------------------------------

# --- Langkah Deployment Docker ---
echo "--- Memulai proses Docker ---"

# 5. Hentikan dan hapus container lama jika ada
if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Menghentikan dan menghapus container lama: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME"
    docker rm "$CONTAINER_NAME"
fi

# 6. Bangun image Docker baru dari Dockerfile di dalam repo
echo "Membangun image Docker baru: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" .

# 7. Jalankan container Docker baru
echo "Menjalankan container Docker baru: $CONTAINER_NAME di port $HOST_PORT"
docker run -d -p "$HOST_PORT":"$CONTAINER_PORT" --name "$CONTAINER_NAME" --restart unless-stopped "$IMAGE_NAME"

echo "--- Deployment untuk $REPO_NAME selesai! ---"
echo "Aplikasi '$REPO_NAME' sekarang berjalan di http://localhost:$HOST_PORT"
exit 0
