// Name: tiktok-images
// Description: Resize images to fit TikTok's 9:16 aspect ratio and avoid being covered by the UI
// Author: Trevor Atlas
// Twitter: @trevoratlas
// Threads: trevor.atlas

import "@johnlindquist/kit"

const sharp = await npm('sharp');
const { getAverageColor } = await npm('fast-average-color-node');

const width = 1440;
const height = 2400;
const density = 72;
const scale = .8;
const validTypes = new Set(['image/png', 'image/jpeg', 'image/jpg']);
const outputPath = path.join(home(), 'Desktop', 'resized-images');

async function processImage(imageFilepath: string): Promise<Buffer> {
  try {
    const averageColor = await getAverageColor(imageFilepath);
    const image = await sharp(imageFilepath)
      .withMetadata({ density })
      .resize({ fit: 'inside', width: Math.floor(width * scale), height: Math.floor(height * scale) })
      .png({ quality: 100 })
      .toBuffer();

    const color = averageColor.hex || 'black';

    // Add a matching background
    const background = await sharp({
      create: {
        channels: 4,
        background: color,
        width,
        height,
      },
    })
    .withMetadata({ density })
    .png({ quality: 100})
    .toBuffer();


    const res = await sharp(background)
      .composite([{ input: image, gravity: 'centre' }])
      .png({ quality: 100 })
      .toBuffer();

    return res;
  } catch (error) {
    console.error(error);
    throw error;
  }
};

interface FileInfo {
  lastModified: number;
  lastModifiedDate: string;//"2023-07-12T17:35:13.573Z"
  name: string;
  path: string;//"/Users/uname/Desktop/screenshots/Screenshot 2022-01-12 at 1.35.08 PM.png"
  size: number;
  type: string;//"image/png"
  webkitRelativePath: string;
}


try {
  const fileInfos: FileInfo[] = await drop('Drop images to resize');
  const imagePaths = fileInfos
    .filter(({type}) => validTypes.has(type))
    .map(fileInfo => fileInfo.path);

  if (!imagePaths.length) {
    await notify('No valid images found. Supports .png, .jpg, and .jpeg');
    exit();
  }

  await ensureDir(outputPath);

  for (const imagePath of imagePaths) {
    const image = await processImage(imagePath);
    const [filename] = path.basename(imagePath).split('.');
    const finalPath = path.join(outputPath, `${filename}-processed.png`);
    await writeFile(finalPath, image);
    console.log(`Resized ${finalPath}`);
  }

  await notify('Image(s) resized');
} catch (error) {
  console.error(error);
  await notify('Error resizing images. Check the log for details.');
}

await open(outputPath);
