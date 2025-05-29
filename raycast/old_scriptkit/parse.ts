import "@johnlindquist/kit"
// Group: work

const JSONvalue = await paste();

try {
  const fixedJsonString = JSONvalue
    .replace(/"([^\s-"]+)":/g, '$1:')
    .replace(/:\s*?"(.*)*"/ig, (_, $1) => {
      const value = $1.includes(`'`) ? $1 : `'${$1}'`;
      return `: ${value}`;
    });


  await copy(fixedJsonString);
} catch(e) {
  console.error(e);
}
