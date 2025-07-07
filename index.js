const express = require('express');
const crypto = require('crypto');
const { spawn } = require('child_process');
const logger = require('./logger');
const { notFound, errorHandler } = require('./errorHandler'); // Import error handlers

const app = express();
const port = 3002;

const secret = process.env.GITHUB_WEBHOOK_SECRET || 'riskidwipatrio1711';

app.use(express.raw({ type: 'application/json' }));

// Route utama untuk webhook
app.post('/webhook', (req, res) => {
  const signature = req.headers['x-hub-signature-256'];
  if (!signature) {
    logger.warn('Signature not found on request.');
    return res.status(401).send('Signature not found');
  }

  const hmac = crypto.createHmac('sha256', secret);
  const digest = 'sha256=' + hmac.update(req.body).digest('hex');

  if (!crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(signature))) {
    logger.error('Invalid signature.');
    return res.status(401).send('Invalid signature');
  }

  let payload;
  try {
    payload = JSON.parse(req.body.toString());
  } catch (e) {
    logger.error('Error parsing JSON payload:', e);
    return res.status(400).send('Invalid JSON payload');
  }

  const event = req.headers['x-github-event'];
  if (event !== 'push') {
    logger.info(`Ignoring event: ${event}`);
    return res.status(200).send('Event ignored');
  }
  
  logger.info('Push event received. Starting deployment process...');

  const repositoryUrl = payload.repository.clone_url;
  if (!repositoryUrl) {
    logger.error('Repository URL not found in payload.');
    return res.status(400).send('Repository URL not found in payload');
  }

  const deployScript = spawn('./deploy.sh', [repositoryUrl]);

  deployScript.on('error', (err) => {
    logger.error(`Failed to start deployment script: ${err.message}`);
  });

  deployScript.stdout.on('data', (data) => {
    logger.info(`[deploy.sh] stdout: ${data.toString().trim()}`);
  });

  deployScript.stderr.on('data', (data) => {
    logger.error(`[deploy.sh] stderr: ${data.toString().trim()}`);
  });

  deployScript.on('close', (code) => {
    logger.info(`[deploy.sh] child process exited with code ${code}`);
  });

  res.status(202).send('Accepted: Deployment process started.');
});

// Pasang middleware 404 Not Found (setelah semua route)
app.use(notFound);

// Pasang middleware error handler utama (paling akhir)
app.use(errorHandler);

app.listen(port, () => {
  logger.info(`Webhook listener running at http://localhost:${port}`);
});



