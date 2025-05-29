// Name: extract pdf text
// Description: extract text from pdf files into a text file for use in LLMs

import "@johnlindquist/kit"

const pdflib = await npm('pdf-parse');

const linesToRemove = new Set([
  '1334818',
  '1334819',
  '25827413',
  '2582741325827413',
  '2582741525827415',
  '1334820',
  '1334821',
  '25827412',
  '2582741325827413',
  '25827414',
  '2582741425827414',
  '2582741425827414',
  '25827415',
  '2582741425827414',
  '25827414',
  '1334820',
  '1334820',
  '1334820',
  '2582741125827411',
  '25827411',
  '1334817',
  '1334817',
  '1334817',
  '2582741625827416',
  '25827416',
  '1334822',
  '1334822',
  '13348222582741725827417',
  '25827417',
  '1334823',
  '1334823',
  '1334823',
  'paizo.com #37514814, Hassan Alsawalhi <hassan.alsawalhi@gmail.com>, Jul 3, 2023',
  '\n\n',
]);

async function getPDFText(source: Buffer): Promise<string> {
  const pdf = await pdflib(source);

  return [...linesToRemove].reduce((acc, text) => {
    return acc.replaceAll(text, '')
  }, pdf.text)
  return pdf.text
  .replaceAll('\n\n', '\n')
}

const validTypes = new Set(['application/pdf']);
const outputPath = path.join(home(), 'Desktop', 'extracted-pdf-text');

await ensureDir(outputPath);

try {
  const files = await drop();
  const pdfPaths = files
    .filter(({type}) => validTypes.has(type))
    .map(fileInfo => fileInfo.path);

  for (const pdfPath of pdfPaths) {
    const fileBuffer = await readFile(pdfPath);
    const pdfText = await getPDFText(fileBuffer);
    const [filename] = path.basename(pdfPath).split('.');
    const finalPath = path.join(outputPath, `${filename}-extracted.txt`);
    await writeFile(finalPath, pdfText);
    console.log(`extracted text from ${finalPath}`);
  }

  await notify('PDF text extracted');

} catch (error) {
  console.error(error);
  await notify('Error extracting PDF text. Check the log for details.');
}

await open(outputPath);
