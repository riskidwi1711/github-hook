#!/bin/bash

# Berhenti jika terjadi error
set -e

# --- Konfigurasi Utama (WAJIB DIUBAH SESUAI KEBUTUHAN) ---
# Direktori utama tempat semua repositori akan di-clone
DEPLOY_DIR="/home/riski/deployments" # Ganti dengan path absolut Anda
# Port yang diekspos oleh aplikasi di dalam container (sesuai EXPOSE di Dockerfile proyek)
CONTAINER_PORT=3000
# ---------------------------------------------------------

# --- Fungsi untuk mencari port acak yang tersedia ---
find_random_available_port() {
  MIN_PORT=49152
  MAX_PORT=65535
  echo "Mencari port acak yang tersedia antara $MIN_PORT dan $MAX_PORT..."
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
# Opsi --no-cache bisa ditambahkan jika perlu build dari awal: docker build --no-cache -t "$IMAGE_NAME" .
docker build -t "$IMAGE_NAME" .

# 7. Jalankan container Docker baru
echo "Menjalankan container Docker baru: $CONTAINER_NAME di port $HOST_PORT"
docker run -d -p "$HOST_PORT":"$CONTAINER_PORT" --name "$CONTAINER_NAME" --restart unless-stopped "$IMAGE_NAME"

echo "--- Deployment untuk $REPO_NAME selesai! ---"
echo "Aplikasi '$REPO_NAME' sekarang berjalan di http://localhost:$HOST_PORT"
exit 0

