const logger = require('./logger');

// Middleware untuk menangani route yang tidak ditemukan (404)
const notFound = (req, res, next) => {
  const error = new Error(`Not Found - ${req.originalUrl}`);
  res.status(404);
  next(error); // Teruskan error ke middleware selanjutnya
};

// Middleware utama untuk menangani semua jenis error
// Perhatikan ada 4 argumen (err, req, res, next), ini yang menandakan ke Express bahwa ini adalah error handler
const errorHandler = (err, req, res, next) => {
  // Kadang-kadang status code bisa 200 meskipun ada error, kita ubah jadi 500
  const statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  res.status(statusCode);

  // Catat error menggunakan Winston
  logger.error({
    message: err.message,
    stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack, // Jangan tampilkan stack di produksi
    url: req.originalUrl,
    method: req.method,
    ip: req.ip
  });

  res.json({
    message: err.message,
    // Tampilkan stack trace hanya saat development untuk debugging
    stack: process.env.NODE_ENV === 'production' ? '🥞' : err.stack
  });
};

module.exports = { notFound, errorHandler };
