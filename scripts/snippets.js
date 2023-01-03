function toTitleCase(str) {
  return str.replace(
    /\w\S*/g,
    (txt) => txt.charAt(0).toUpperCase() + txt.substr(1)
  );
}

const component = (type, name) => {
  const declaration =
    type === 'function'
      ? `function ${name}(props: ${name}Props) {`
      : `const ${name} = (props: ${name}Props) => {`;

  console.log(declaration);
  return `${declaration}
  return (
    <>${name}</>
  );
};`;
};

function ReactComponent(name, type, stateName) {
  name = toTitleCase(name);
  return `interface ${name}Props {
  children: React.ReactNode;
}

${component(type, name)}
`;
}
const print = (str) => console.log(str);

(function main() {
  const [action, ...args] = process.argv.slice(2);
  switch (action) {
    case 'component':
      return print(ReactComponent(...args));
    default:
      return print(ReactComponent(...args));
      return print('No action found');
  }
})();

const toScreamingSnakeCase = (name) => name.toUpperCase().replace(/\s/g, '_');

function ReactUseQuery(queryName) {
  return `const { data, loading, error } = useQuery(${toScreamingSnakeCase(
    queryName
  )});`;
}

function ReactUseMutation(mutationName) {
  return `const [${mutationName}, { data, loading, error }] = useMutation(${toScreamingSnakeCase(
    mutationName
  )});`;
}
