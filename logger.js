const winston = require('winston');

const logger = winston.createLogger({
  // Level logging minimum yang akan diproses
  level: 'info',
  // Format log
  format: winston.format.combine(
    winston.format.timestamp({
      format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }), // Menampilkan stack trace untuk error
    winston.format.splat(),
    winston.format.json()
  ),
  // Default metadata yang akan ditambahkan ke setiap log
  defaultMeta: { service: 'github-webhook' },
  // Transports (tujuan output log)
  transports: [
    // Menyimpan log error ke file error.log
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    // Menyimpan semua log ke file combined.log
    new winston.transports.File({ filename: 'combined.log' })
  ]
});

// Jika tidak di lingkungan produksi, tambahkan output ke konsol
// dengan format yang lebih mudah dibaca dan berwarna.
if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

module.exports = logger;
