function toTitleCase(str) {
  return str.replace(
    /\w\S*/g,
    (txt) => txt.charAt(0).toUpperCase() + txt.substr(1)
  );
}

function state(name) {
  if (!name) {
    return '';
  }
  return `const [${name}, set${
    name.charAt(0).toUpperCase() + name.slice(1)
  }] = useState();`;
}

const props = (name) => `props: ${name}Props`;
const jsx = (name) => `
  return (
    <>${name}</>
  );`;

const propType = (name) => `interface ${name}Props {
  children: React.ReactNode;
}`;

const imports = (stateName) =>
  `import React${stateName ? ', { useState } ' : ' '}from 'react';`;

const component = (type, name, body) => {
  const declaration =
    type === 'function'
      ? `function ${name}(${props(name)}) {`
      : `const ${name} = (${props(name)}) => {`;

  return `${declaration}
  ${body}
};`;
};

function ReactComponent(name, type, stateName) {
  name = toTitleCase(name);

  const body = `${state(stateName)}
  ${jsx(name)}`;

  return `
${imports(stateName)}

${propType(name)}

${component(type, name, body)}
`;
}

function InlineReactComponent(name) {
  name = toTitleCase(name);

  return component('arrow', name, jsx(name));
}

function ReactMemo(name) {
  return `const ${name} = useMemo(() => {
    return
  }, []);`;
}

function ReactUseEffect(name) {
  return `useEffect(() => {
    return
  }, []);`;
}

function ReactUseRef(name) {
  return `const ${name} = useRef();`;
}

function ReactUseContext(name) {
  return `const ${name} = useContext();`;
}

function ReactUseEffect() {
  return `useEffect(() => {
    return
  }, []);`;
}

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
