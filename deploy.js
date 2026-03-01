const { spawn } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);

const PORT = process.env.PORT || 18789;
const UUID = process.env.UUID || '9afd1229-b893-40c1-84dd-51e7ce204913';
const WS_PATH = process.env.WSPATH || '/vmess';
const FILE_PATH = process.env.FILEPATH || '.tmp';

if (!fs.existsSync(FILE_PATH)) {
  fs.mkdirSync(FILE_PATH);
}

function getSystemArchitecture() {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    return 'arm64';
  } else {
    return 'amd64';
  }
}

async function downloadXray() {
  const arch = getSystemArchitecture();
  const xrayPath = path.join(FILE_PATH, 'xray');
  
  if (fs.existsSync(xrayPath)) {
    console.log('xray already exists');
    return xrayPath;
  }
  
  const url = `https://github.com/XTLS/Xray-core/releases/download/v26.2.6/Xray-linux-64.zip`;
  const zipPath = path.join(FILE_PATH, 'xray.zip');
  
  console.log(`Downloading xray from ${url}...`);
  
  const https = require('https');
  const http = require('http');
  
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    
    const file = fs.createWriteStream(zipPath);
    
    protocol.get(url, (response) => {
      if (response.statusCode === 302 || response.statusCode === 301) {
        const redirectUrl = response.headers.location;
        console.log('Redirect to:', redirectUrl);
        https.get(redirectUrl, (res) => {
          res.pipe(file);
          file.on('finish', () => {
            file.close();
            extractXray(zipPath, xrayPath).then(resolve).catch(reject);
          });
        }).on('error', reject);
      } else {
        response.pipe(file);
        file.on('finish', () => {
          file.close();
          extractXray(zipPath, xrayPath).then(resolve).catch(reject);
        });
      }
    }).on('error', (err) => {
      fs.unlinkSync(zipPath);
      reject(err);
    });
  });
}

async function extractXray(zipPath, xrayPath) {
  console.log('Extracting...');
  await exec(`unzip -o ${zipPath} -d ${FILE_PATH}`);
  
  const extractedPath = path.join(FILE_PATH, 'xray');
  if (fs.existsSync(extractedPath)) {
    fs.chmodSync(extractedPath, 0o755);
    return extractedPath;
  }
  
  const files = fs.readdirSync(FILE_PATH);
  for (const file of files) {
    if (file.includes('xray') && !file.endsWith('.zip')) {
      const fullPath = path.join(FILE_PATH, file);
      if (fs.statSync(fullPath).isFile()) {
        fs.chmodSync(fullPath, 0o755);
        return fullPath;
      }
    }
  }
  
  throw new Error('xray binary not found');
}

function generateConfig(xrayBinPath) {
  const config = {
    log: { access: '/dev/null', error: '/dev/null', loglevel: 'warning' },
    inbounds: [
      {
        port: PORT,
        listen: '127.0.0.1',
        protocol: 'vmess',
        settings: {
          clients: [{ id: UUID, alterId: 0 }]
        },
        streamSettings: {
          network: 'ws',
          wsSettings: {
            path: WS_PATH
          }
        },
        sniffing: { enabled: true, destOverride: ['http', 'tls'] }
      }
    ],
    outbounds: [
      { protocol: 'freedom', tag: 'direct' },
      { protocol: 'blackhole', tag: 'block' }
    ]
  };
  
  const configPath = path.join(FILE_PATH, 'config.json');
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  return configPath;
}

async function startXray(configPath, xrayBinPath) {
  console.log(`Starting xray on port ${PORT}, ws path: ${WS_PATH}`);
  
  const xray = spawn(xrayBinPath, ['-c', configPath], {
    stdio: 'inherit',
    detached: true
  });
  
  xray.unref();
  
  xray.on('error', (err) => {
    console.error('xray error:', err.message);
  });
  
  return xray;
}

async function main() {
  try {
    console.log('Starting deployment...');
    console.log('PORT:', PORT, 'UUID:', UUID, 'WS_PATH:', WS_PATH);
    
    const xrayPath = await downloadXray();
    const configPath = generateConfig(xrayPath);
    await startXray(configPath, xrayPath);
    
    console.log('Deployment complete!');
    console.log('PORT:', PORT, 'WS_PATH:', WS_PATH);
    
    setInterval(() => {}, 1000);
    
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

main();
