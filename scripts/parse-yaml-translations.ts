import YAML from 'yaml';
import { readdir, stat } from 'node:fs/promises';
import { $ } from 'bun';

const Ok = '\x1b[34m';
const Warn = '\x1b[33m';
const Reset = '\x1b[0m';
const warn = (str: string) => `🔎${Warn}${str}${Reset}`;
const ok = (str: string) => `✅${Ok}${str}${Reset}`;

function flattenObject(
  obj: any,
  parentKey = '',
  result: Record<string, string> = {}
): Record<string, string> {
  for (const key in obj) {
    if (!obj.hasOwnProperty(key)) {
      continue;
    }
    if (is_comment.test(key)) {
      continue;
    }
    let propName = parentKey ? `${parentKey}.${key}` : key;
    if (propName.startsWith('en')) {
      propName = propName.replace('en.', '');
    }
    if (
      typeof obj[key] === 'object' &&
      obj[key] !== null &&
      !Array.isArray(obj[key])
    ) {
      // Recursively call flattenObject if the property is an object
      flattenObject(obj[key], propName, result);
    } else {
      // It's a leaf node, add it to the result
      result[propName] = obj[key];
    }
  }
  return result;
}

const is_comment = /^#/;
const has_file_extension = /\.\w+$/gim;
const [_, __, target_file] = Bun.argv;
const excluded_filenames = new Set<string>([
  'node_modules',
  '.vscode',
  'hubspot.deploy',
  'target',
]);

async function getFiles(target_file?: string): Promise<string[]> {
  if (target_file) {
    return [target_file];
  }

  const files: string[] = await readdir('./').then((f) =>
    f.filter(
      (file) => !has_file_extension.test(file) && !excluded_filenames.has(file)
    )
  );

  return files;
}

async function parseTranslations(
  files: string[]
): Promise<Map<string, Record<string, string>>> {
  const yaml_files = new Map<string, Record<string, string>>();
  for (const filename of files) {
    const st = await stat(filename);
    if (!st.isDirectory()) {
      continue;
    }

    try {
      const file_content = Bun.file(`./${filename}/static/lang/en.lyaml`);
      const txt = await file_content.text();
      const parsed_result = flattenObject(YAML.parse(txt));
      yaml_files.set(filename, parsed_result);
    } catch (e) {
      continue;
    }
  }
  return yaml_files;
}

async function main(target_file?: string) {
  const files = await getFiles(target_file);
  const parsed_result = await parseTranslations(files);

  const output: Record<
    string, // project name within repo
    Record<
      string, // some.translation.key.path
      { confirmedUses: any[]; possibleUses: any[] }
    >
  > = {};

  for (const [project, translationMap] of parsed_result.entries()) {
    const keys = Object.keys(translationMap);
    if (keys.length < 1) {
      continue;
    }

    output[project] = keys.reduce((acc, key) => {
      acc[key] = { confirmedUses: [], possibleUses: [] };
      return acc;
    }, {});

    for (const key of keys) {
      const uses: string = await $`rg ${key} --json -tts -tjs`.text();

      if (!uses || !uses.length) {
        continue;
      }
      const formattedUses = uses
        .split('\n')
        .filter(Boolean)
        .map((str) => JSON.parse(str))
        .filter((result) => result.type === 'match');

      if (!formattedUses || !formattedUses.length) {
        // search for fuzzy keys
        const keyParts = key.split('.');
        for (let i = 0; i < keyParts.length; i++) {
          const search = [...keyParts];
          search[i] = '*';
          const searchStr = search.join('.');
          const fuzzyUses: string =
            await $`rg '${searchStr}' --glob-case-insensitive --json -tts -tjs`.text();
          if (!fuzzyUses || !fuzzyUses.length) {
            continue;
          }
          output[project][key].possibleUses.push(
            ...fuzzyUses
              .split('\n')
              .filter(Boolean)
              .map((str) => JSON.parse(str))
              .filter((result) => result.type === 'match')
              .map((res) => res.data)
              .map((res) => ({
                path: `${res.path.text}:L${res.line_number}`,
                lines: res.lines.text.trim(),
                searchStr,
              }))
          );
        }
      } else {
        output[project][key].confirmedUses.push(
          ...formattedUses
            .map((res) => res.data)
            .map((res) => ({
              path: `${res.path.text}:L${res.line_number}`,
              match: res.lines.text.trim(),
            }))
        );
      }
    }
  }

  const confirmedUses = [];
  const possibleUses = [];
  for (const [project, useRecord] of Object.entries(output)) {
    for (const [key, uses] of Object.entries(useRecord)) {
      if (uses.confirmedUses.length) {
        confirmedUses.push(`  ${key}: ${uses.confirmedUses.length}`);
      }
      if (uses.possibleUses.length) {
        possibleUses.push(
          `\x1b[33m'${key}'\x1b[0m
  possible matches from fuzzy searching:
${uses.possibleUses.map((u) => `    ${u.lines}`).join('\n')}
`
        );
      }
    }
  }

  console.log(`
${ok('Strings with a confirmed use')}
${confirmedUses.join('\n')}

${warn('Strings that should be manually verified')}
${possibleUses.join('\n')}
`);
  return output;
}

main(target_file);
