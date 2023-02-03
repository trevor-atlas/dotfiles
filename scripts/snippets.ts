#!/usr/bin/env ts-node

function toTitleCase(str: string) {
  return str.replace(
    /\w\S*/g,
    (txt) => txt.charAt(0).toUpperCase() + txt.substr(1)
  );
}

const component = (type: ReactComponentType, name: string) => {
  const declaration =
    type === 'function'
      ? `function ${name}(props: ${name}Props) {`
      : `const ${name} = (props: ${name}Props) => {`;

  return `${declaration}
  return (
    <>${name}</>
  );
};`;
};

type ReactComponentType = 'function' | 'arrow';

function ReactComponent(name: string, type: ReactComponentType) {
  name = toTitleCase(name);
  return `interface ${name}Props {
  children: React.ReactNode;
}

${component(type, name)}
`;
}
const print = (str: string) => console.log(str);

(function main() {
  const [action, ...args] = process.argv.slice(2);
  switch (action) {
    case 'component':
      return print(ReactComponent(...args));
    default:
      return print(ReactComponent(...args));
  }
})();

const toScreamingSnakeCase = (name: string) =>
  name.toUpperCase().replace(/\s/g, '_');

function ReactUseQuery(queryName: string) {
  return `const { data, loading, error } = useQuery(${toScreamingSnakeCase(
    queryName
  )});`;
}

function ReactUseMutation(mutationName: string) {
  return `const [${mutationName}, { data, loading, error }] = useMutation(${toScreamingSnakeCase(
    mutationName
  )});`;
}
