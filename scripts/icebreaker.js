const icebreakers = require('./icebreakers.json');
const completeIcebreakers = require('./complete-icebreakers.json');
const fs = require('fs');
const util = require('util');
const write = util.promisify(fs.writeFile);
const { join } = require('path');
const complete = { ...completeIcebreakers };
const colors = require('./colors');

const getRandomElement = (arr) => {
  const index = Math.floor(Math.random() * arr.length);
  const item = arr[index];
  return [index, item];
};

function colorString(color, string) {
  return `${color}${string}${color.Reset}`;
}

(async function main() {
  let [index, item] = getRandomElement(icebreakers);

  let iterations = 0;
  while (index in complete) {
    if (iterations >= icebreakers.length) {
      console.error(
        colorString(
          colors.FgYellow,
          '🚨 No more unique icebreakers left to choose from'
        )
      );
      break;
    }
    [index, item] = getRandomElement(icebreakers);
    iterations++;
  }

  console.log(`🧊🔨 "${item}"`);

  if (index in complete) {
    complete[index] += 1;
  } else {
    complete[index] = 1;
  }

  const content = JSON.stringify(complete, null, 2);
  await write(join(__dirname, 'complete-icebreakers.json'), content, {
    encoding: 'utf8',
  });
})();
