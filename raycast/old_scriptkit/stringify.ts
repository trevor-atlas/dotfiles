import "@johnlindquist/kit"
// Group: work

const value = await paste();

try {
  const parsed = eval(String.raw`(() => (${value}))()`);
  const stringified = JSON.stringify(parsed, null, 2);
  await copy(stringified);
} catch(e) {
  console.error(e);
}


