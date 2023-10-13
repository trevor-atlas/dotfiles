const set = new Set();
const map = new Map();
const obj = {};
const arr = [];
const values = [];

const getchar = n => String.fromCharCode(n);
const timed = (f) => (...args) => {
    const start = performance.now();
    f(...args);
    return (performance.now() - start);
};
const average = array => array.reduce((a, b) => a + b) / array.length;

const getRandomValue = () => values[Math.floor(Math.random()*values.length)]

const benchmarkSet = timed(size => {
  for (let i = 0; i < size; i++) {
      set.has(getRandomValue());
  }
});

const benchmarkMap = timed(size => {
  for (let i = 0; i < size; i++) map.has(getRandomValue());
});

const benchmarkObj = timed(size => {
  for (let i = 0; i < size; i++) obj.hasOwnProperty(getRandomValue());
});

const benchmarkObjIn = timed(size => {
  for (let i = 0; i < size; i++) getRandomValue() in obj;
});

const benchmarkObjIndex = timed(size => {
  for (let i = 0; i < size; i++) obj[getRandomValue()];
});

const benchmarkArr = timed(size => {
  for (let i = 0; i < size; i++) arr.includes(getRandomValue());
});


function setup(size) {
  for (let i = 0; i < size; i++) {
    // random utf8 symbol
    const symbol = String.fromCharCode(Math.floor(Math.random() * 65535));
    values.push(symbol);
    set.add(symbol);
    map.set(symbol, i);
    obj[symbol] = i;
    arr.push(symbol);
  } 
}

const formatResult = (title, result) => `${title}
avg:   ${average(result).toFixed(3)}ms,
most:  ${Math.max(...result).toFixed(3)}ms,
least: ${Math.min(...result).toFixed(3)}ms
`;

function test(size, iterations) {
  const setResults = [];
  const mapResults = [];
  const objResults = [];
  const objInResults = [];
  const objIndexResults = [];
  const arrResults = [];
  for (let i = 0; i < numRuns; i++) {
    setResults.push(benchmarkSet(size));
    mapResults.push(benchmarkMap(size));
    objResults.push(benchmarkObj(size));
    objInResults.push(benchmarkObjIn(size));
    objIndexResults.push(benchmarkObjIndex(size));
    arrResults.push(benchmarkArr(size));
  }

  const results = [];
  results.push(formatResult('Set.has() took', setResults));
  results.push(formatResult('Map.has() took', mapResults));
  results.push(formatResult('obj.hasOwnProperty() took', objResults));
  results.push(formatResult('"key in obj" took', objInResults));
  results.push(formatResult('obj[key] took', objIndexResults));
  results.push(formatResult('[].includes() took', arrResults));
  return results;
}

const size = 1_000_000;
const numRuns = 1000;

setup(size);

const result = test(size, numRuns);
result.forEach(r => console.log(r));
