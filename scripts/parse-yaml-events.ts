import { parse, stringify } from 'yaml';
import { readdir, stat } from 'node:fs/promises';

type Events = Record<string, Event>;

type Event = {
  name: string;
  namespace?: string;
  meta: {
    database: string;
  };
  class: 'interaction' | 'usage';
  properties: Record<string, EventProperty>;
};

type ObjectEventProperty = {
  type: string | string[];
  isOptional?: boolean;
  description?: string;
};

type EventProperty = string | string[] | ObjectEventProperty;
const suffix = '[🔎]';

const isString = (anything: any): anything is string =>
  typeof anything === 'string';

const isArray = (anything: any): anything is any[] => Array.isArray(anything);

const isObjectProperty = (
  property: EventProperty
): property is ObjectEventProperty =>
  !isString(property) && !isArray(property) && 'type' in property;

const isArrayProperty = (property: EventProperty): property is string[] =>
  !isString(property) && isArray(property);

const toStringUnion = (strings: string[]) =>
  strings.map((str: string) => `'${str}'`).join(' | ');

const isPropertyOptional = (property: EventProperty) =>
  isObjectProperty(property) && 'isOptional' in property && property.isOptional;

const getPropertyDescription = (property: EventProperty) =>
  isObjectProperty(property) && property.description
    ? `  /** ${property.description} */
`
    : '';

function parseProperty(property: EventProperty) {
  if (isString(property)) {
    return property;
  }
  if (isArrayProperty(property)) {
    return toStringUnion(property);
  }
  if (isArray(property.type)) {
    return toStringUnion(property.type);
  }
  if (property.type === 'array') {
    return 'string[]';
  }
  return property.type;
}

function getPropertyType(propertyName: string, property: EventProperty) {
  const description = getPropertyDescription(property);
  const value = parseProperty(property);
  const optional = isPropertyOptional(property) ? '?' : '';
  return `${description}  ${propertyName}${optional}: ${value};`;
}

const parseEventsToTypescriptTypes = (events: Events) =>
  Object.entries(events).map(
    ([key, values]) =>
      `export type ${key.charAt(0).toUpperCase() + key.slice(1)} = {
${Object.entries(values.properties)
  .map(([name, property]) => getPropertyType(name, property))
  .join('\n')}
};

`
  );

const has_file_extension = /\.\w+$/gim;
const [_, __, target_file] = Bun.argv;
const excluded_filenames = new Set<string>([
  'node_modules',
  '.vscode',
  'hubspot.deploy',
  'target',
]);

async function main() {
  const files: string[] = await readdir('./').then((list) =>
    list.filter(
      (file) => !(has_file_extension.test(file) || excluded_filenames.has(file))
    )
  );

  if (!(files.includes('static_conf.json') && files.includes('.blazar.yaml'))) {
    console.error(`${suffix} 🚨 Invalid project directory, exiting...`);
    process.exit(1);
  }

  for (const file_name of files) {
    const st = await stat(file_name);
    if (!st.isDirectory()) {
      continue;
    }
    try {
      const fcontent = Bun.file(`./${file_name}/static/events.yaml`);
      const txt = await fcontent.text();
      const types = parseEventsToTypescriptTypes(parse(txt));
      Bun.write(`./${file_name}/static/js/event-types.ts`, types);
      console.log(`${suffix} ✅ Wrote ${file_name}/static/js/event-types.ts`);
    } catch (_) {
      console.warn(`${suffix} ⚠️  Skipping ${file_name}, no events.yaml file`);
      continue;
    }
  }
  console.log(`${suffix} Done.`);
  process.exit(0);
}

main();
