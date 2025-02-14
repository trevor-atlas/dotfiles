import { parse } from 'yaml';
import { readdir, writeFile, readFile } from 'node:fs/promises';

type Events = Record<string, Event>;

interface Event {
  name: string;
  namespace?: string;
  meta: {
    database: string;
  };
  class: 'interaction' | 'usage';
  properties: Record<string, EventProperty>;
}

interface ObjectEventProperty {
  type: string | string[];
  isOptional?: boolean;
  description?: string;
}

type EventProperty = string | string[] | ObjectEventProperty;

const PREFIX = '[🔎]';
const HAS_FILE_EXT = /.*\.\w+$/i;
const EXCLUDED_FILENAMES = new Set<string>([
  'node_modules',
  'hubspot.deploy',
  'target',
  'schemas',
]);

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
  return `
${description}  ${propertyName}${optional}: ${value};`;
}

function pascalCase(str: string) {
  return `${str.charAt(0).toUpperCase()}${str.slice(1)}`;
}

function parseEventsToTypescriptTypes(events: Events) {
  const types = Object.entries(events).map(
    ([key, values]) => `export interface ${pascalCase(key)} {
${Object.entries(values.properties)
  .map(([name, property]) => getPropertyType(name, property))
  .join('\n')}
}\n\n`
  );

  return types.join('\n');
}

async function main() {
  const files: string[] = await readdir('./');
  const project_directories = files.filter((file) => {
    if (HAS_FILE_EXT.test(file)) {
      return false;
    }
    if (EXCLUDED_FILENAMES.has(file)) {
      return false;
    }
    if (file.startsWith('.')) {
      return false;
    }
    return true;
  });

  for (const file_name of project_directories) {
    try {
      const fileContent = await readFile(
        `${file_name}/static/events.yaml`,
        'utf8'
      );
      const events: Events = parse(fileContent);
      const eventTypesFileContent = parseEventsToTypescriptTypes(events);
      await writeFile(
        `${file_name}/static/js/event-types.ts`,
        eventTypesFileContent
      );
      console.log(`${PREFIX} ✅ Wrote ${file_name}/static/js/event-types.ts`);
    } catch (_) {
      console.warn(`${PREFIX} ⚠️ Skipping ${file_name}, no events.yaml file`);
      continue;
    }
  }
  process.exit(0);
}

main().catch((e) => {
  console.error(PREFIX, 'ERROR:', JSON.stringify(e));
});
