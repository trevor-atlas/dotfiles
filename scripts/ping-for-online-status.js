const EventEmitter = require('events').EventEmitter;
const { spawn } = require('child_process');
const rl = require('readline');

const GOT_BYTES = /bytes from/i;
const INTERVAL = 2; // in seconds
// this needs to become a hubspot vpn address
const IP = '8.8.8';

let proc;
let cpu;
let emitter;
let offlineCount = 0;
let ticks = 0;
let paused = false;

// maybe use something like this to detect system sleep/wake and throttle or stop the ping
const SAMPLE_RATE = 3000; // 3 seconds
let lastSample = Date.now();
function sample() {
  if (Date.now() - lastSample >= SAMPLE_RATE * 2) {
    // Code here will only run if the timer is delayed by more 2X the sample rate
    // (e.g. if the laptop sleeps for more than 3-6 seconds)
    paused = true;
  } else {
    paused = false;
    cpu.emit('init');
  }
  lastSample = Date.now();
  setTimeout(sample, SAMPLE_RATE);
}

sample();

function init() {
  proc = spawn('ping', ['-v', '-n', '-i', INTERVAL, IP]);
  cpu = controller();
  cpu.emit('init');
  emitter = eventEmitter(proc, cpu);
}

init();
proc.on('exit', (code) => {
  // restart the whole process if it exits
  init();
});

process.on('exit', () => {
  proc.kill();
});

// listen for events from the event emitter and act accordingly
function controller() {
  return (
    new EventEmitter()
      .on('init', () => {
        console.log('🚀 initializing...');
        offlineCount = 0;
      })
      // then just listen for the `online` and `offline` events ...
      .on('online', () => {
        offlineCount = 0;
        logEveryTen(`${timestamp()} 🌎 online`, ticks);
      })
      .on('offline', () => {
        offlineCount++;
        if (offlineCount > 5) {
          console.log(timestamp(), 'Offline! restarting bender!');
          const restart = spawn('brew', ['services', 'restart', 'benderthing']);
          restart.stdout.on('data', (data) => {
            console.log(`🧡 Restarted bender`);
          });
          restart.stderr.on('data', (data) => {
            console.log(`💔 Error restarting bender:
${data}
`);
          });
          offlineCount = 0;
        }
        logEveryTen(`${timestamp()} 🚨 Offline!`, ticks);
      })
  );
}

const timestamp = () =>
  `[${new Date().toLocaleString('en-us').split(', ')[1]}]`;

// emit `online` and `offline` events to the controller based on the ping output
function eventEmitter(proc, controller) {
  return rl.createInterface(proc.stdout, proc.stdin).on('line', (str) => {
    if (paused) {
      console.log('PAUSED');
      return;
    }
    // console.log('LINE: ', str);
    if (GOT_BYTES.test(str)) {
      controller.emit('online');
    } else {
      controller.emit('offline');
    }
    if (ticks > 100) {
      ticks = 0;
    } else {
      ticks++;
    }
  });
}

const logEveryTen = (str, ticks) => {
  if (ticks % 10 === 0) {
    console.log(str);
  }
};
