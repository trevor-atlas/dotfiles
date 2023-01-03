const EventEmitter = require('events').EventEmitter;
const { spawn, execSync } = require('child_process');
const { setTimeout } = require('node:timers/promises');

const GOT_BYTES = /bender-proxy/gim;
const INTERVAL = 5; // in seconds
const ADDRESS = 'local.hubspotqa.com';

let controller;
let offlineCount = 0;
let ticks = 0;
let paused = false;

const globe = ['🌎', '🌍', '🌏'];
let globeIndex = 0;
const getGlobe = () => {
  if (globeIndex >= globe.length) {
    globeIndex = 0;
  }
  const res = globe.at(globeIndex);
  globeIndex++;
  return res;
};

// this is an attempt to detect system sleep/wake and throttle or stop the event loop during that time.
const SAMPLE_RATE = 3000; // 3 seconds
let lastSample = Date.now();
function sample() {
  if (Date.now() - lastSample >= SAMPLE_RATE * 2) {
    // Code here will only run if the timer is delayed by more than 2X the sample rate
    // (e.g. if the laptop sleeps for more than 3-6 seconds)
    paused = true;
  } else {
    paused = false;
  }
  lastSample = Date.now();
}

const timestamp = () => {
  const now = new Date();
  const date = now.getDate().toString().padStart(2, '0');
  const month = (now.getMonth() + 1).toString().padStart(2, '0');
  const year = now.getFullYear();
  const hours = now.getHours().toString().padStart(2, '0');
  const minutes = now.getMinutes().toString().padStart(2, '0');
  const seconds = now.getSeconds().toString().padStart(2, '0');

  return `[${year}-${month}-${date} at ${hours}:${minutes}:${seconds}]`;
};

const throttledFunc = (fn) => {
  if (ticks % 2 === 0) {
    fn();
  }
};

// listen for `online` and `offline` events and act accordingly
function getController() {
  return new EventEmitter()
    .on('init', () => {
      console.log('🚀 initializing...');
      offlineCount = 0;
      ticks = 0;
    })
    .on('online', () => {
      offlineCount = 0;
      throttledFunc(() => console.log(timestamp(), getGlobe(), 'Online'));
    })
    .on('offline', () => {
      offlineCount++;
      if (offlineCount > 100) {
        console.log(
          timestamp(),
          '🤔 Offline for over 100 ticks, are you on the vpn? Is there a bend process running? Stopping.'
        );
        process.exit(1);
      }
      if (ticks > 0 && offlineCount < 5) {
        return;
      }
      console.log(timestamp(), '🚨 Offline!');
      const restart = spawn('brew', ['services', 'restart', 'bender-proxy']);
      restart.stdout.on('data', (data) => {
        console.log(timestamp(), '✅ Successfully restarted bender-proxy');
      });
      restart.stderr.on('data', (data) => {
        console.log(`💣 Error restarting bender:
${data.toString()}
`);
      });
      offlineCount = 0;
      ticks = -1;
    });
}

async function checkService(controller) {
  try {
    const res = await execSync(`curl ${ADDRESS}`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'ignore'],
    });
    // emit `online` and `offline` events to the controller based on curl output
    if (GOT_BYTES.test(res)) {
      controller.emit('online');
    } else {
      controller.emit('offline');
    }
  } catch (e) {
    controller.emit('offline');
  }
}

(async function main() {
  controller = getController();
  controller.emit('init');

  while (true) {
    sample();
    if (paused) {
      await setTimeout(INTERVAL * 1000);
      continue;
    }
    await checkService(controller);
    if (ticks > 100) {
      ticks = 0;
    } else {
      ticks++;
    }
    await setTimeout(INTERVAL * 1000);
  }
})();

process.on('exit', () => {});
