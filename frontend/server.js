const express = require('express');
const path = require('path');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || 'http://app-server:8080';

app.use(express.static(path.join(__dirname, 'public')));

// Pass backend URL to the client safely via a config endpoint
app.get('/config', (req, res) => {
  res.json({
    backendUrl: BACKEND_URL,
    webServer: os.hostname(), // which web server is responding
  });
});

app.listen(PORT, () => {
  console.log(`Frontend running on port ${PORT}`);
});