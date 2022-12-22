const EventEmitter = require('events').EventEmitter;
const { spawn } = require('child_process');
const rl = require('readline');

const GOT_BYTES = /bytes from/i;
const INTERVAL = 2; // in seconds
// this needs to become a hubspot vpn address
const IP = '8.8.8.8';

let proc;
let cpu;
let emitter;
let offlineCount = 0;

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
        // console.log('🌎 online!');
      })
      .on('offline', () => {
        offlineCount++;
        if (offlineCount > 5) {
          console.log(
            new Date().toLocaleString('en-us'),
            '🚨 Offline! restarting bender!'
          );
          spawn('brew', ['services', 'restart', 'benderthing']).stderr.on(
            'data',
            (data) => {
              console.error(`stderr: ${data}`);
            }
          );
          offlineCount = 0;
        }
        // console.log('🚨 offline!');
      })
  );
}

// emit `online` and `offline` events to the controller based on the ping output
function eventEmitter(proc, controller) {
  return rl.createInterface(proc.stdout, proc.stdin).on('line', (str) => {
    // console.log('LINE: ', str);
    if (GOT_BYTES.test(str)) {
      controller.emit('online');
    } else {
      controller.emit('offline');
    }
  });
}
