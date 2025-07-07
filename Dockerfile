# Gunakan base image Node.js yang ringan
FROM node:18-alpine

# Buat direktori kerja di dalam container
WORKDIR /usr/src/app

# Salin package.json dan package-lock.json
# Tanda bintang (*) digunakan agar bisa cocok dengan package-lock.json atau npm-shrinkwrap.json
COPY package*.json ./

# Instal dependensi aplikasi
RUN npm install

# Salin sisa file aplikasi ke direktori kerja
COPY . .

# Ekspos port yang digunakan oleh aplikasi
EXPOSE 3000

# Perintah untuk menjalankan aplikasi saat container dimulai
CMD [ "node", "index.js" ]
