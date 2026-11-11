import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
import {deflateSync} from 'node:zlib';

function rgbPNG(width, height, pixels) {
  const crc32 = data => {
    let crc = 0xffffffff;
    for (const byte of data) { crc ^= byte; for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0); }
    return (crc ^ 0xffffffff) >>> 0;
  };
  const chunk = (name, data) => {
    const type = Buffer.from(name); const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
    const checksum = Buffer.alloc(4); checksum.writeUInt32BE(crc32(Buffer.concat([type, data])));
    return Buffer.concat([length, type, data, checksum]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header[8] = 8; header[9] = 2;
  const rows = Buffer.alloc(height * (1 + width * 3));
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) for (let c = 0; c < 3; c++) rows[y * (1 + width * 3) + 1 + x * 3 + c] = pixels[(y * width + x) * 4 + c];
  return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]);
}

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const resources = path.join(root, 'ios/Rajya/Resources');
fs.mkdirSync(resources, {recursive: true});
const catalogPath = path.join(resources, 'catalog.json');
const sourceCatalog = path.join(root, 'android/app/src/main/assets/reference/catalog.json');
if (fs.existsSync(sourceCatalog)) fs.copyFileSync(sourceCatalog, catalogPath);
if (!fs.existsSync(catalogPath)) throw Error('Missing public reference catalogue.');
const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const originals = {
  'establishments-i': 'establishments-code-volume-i-2013(s).pdf',
  'establishments-ii': 'establishments-code-volume-ii-1999(s).pdf',
  'financial-regulations': 'Financial-Regulation-Sinhala.pdf',
  'winaya-karya-piliwela': 'winaya-karya-piliwela.pdf'
};
for (const book of catalog.books) {
  const target = path.join(resources, book.slug + '.pdf');
  const source = path.join(root, originals[book.slug]);
  if (!originals[book.slug]) throw Error('Unknown reference book.');
  if (fs.existsSync(source)) fs.copyFileSync(source, target);
  if (!fs.existsSync(target)) throw Error('Missing reference PDF: ' + book.slug);
  const hash = crypto.createHash('sha256').update(fs.readFileSync(target)).digest('hex');
  if (hash !== book.sha256) throw Error('Source PDF checksum mismatch: ' + book.slug);
  const indexSource=path.join(root,'assets/reference-text',book.slug+'-text.json');
  if(fs.existsSync(indexSource))fs.copyFileSync(indexSource,path.join(resources,book.slug+'-text.json'));
}
for (const family of ['NotoSansSinhala', 'NotoSansTamil']) {
  const source = path.join(root, 'android/app/src/main/assets/fonts', family + '.ttf');
  const target = path.join(resources, family + '.ttf');
  if (fs.existsSync(source)) fs.copyFileSync(source, target);
  if (!fs.existsSync(target)) throw Error('Missing bundled font: ' + family);
}
const licenseDir = path.join(root, 'android/app/src/main/assets/licenses');
for (const name of ['notosanssinhala-OFL.txt', 'notosanstamil-OFL.txt']) {
  const source = path.join(licenseDir, name);
  const target = path.join(resources, name);
  if (fs.existsSync(source)) fs.copyFileSync(source, target);
  if (!fs.existsSync(target)) throw Error('Missing font license: ' + name);
}
const assets = path.join(resources, 'Assets.xcassets');
const icons = path.join(assets, 'AppIcon.appiconset');
fs.mkdirSync(icons, {recursive: true});
const icon = path.join(icons, 'AppIcon.png');
const sourceIcon = path.join(root, 'storage/releases/play-store/graphics/app-icon-512.png');
if (!fs.existsSync(icon)) {
  if (!fs.existsSync(sourceIcon)) throw Error('Missing public app icon.');
  if (process.platform === 'darwin') {
    fs.copyFileSync(sourceIcon, icon);
    execFileSync('sips', ['-z', '1024', '1024', icon], {stdio: 'ignore'});
  } else {
    // Uses the existing local graphics dependency; the standalone CI kit has the prepared icon.
    const {createCanvas, loadImage} = await import('@napi-rs/canvas');
    const canvas = createCanvas(1024, 1024);
    const context = canvas.getContext('2d');
    context.fillStyle = '#350914'; context.fillRect(0, 0, 1024, 1024);
    context.drawImage(await loadImage(sourceIcon), 0, 0, 1024, 1024);
    fs.writeFileSync(icon, rgbPNG(1024, 1024, context.getImageData(0, 0, 1024, 1024).data));
  }
}
const png = fs.readFileSync(icon);
if (png.readUInt32BE(16) !== 1024 || png.readUInt32BE(20) !== 1024) throw Error('iOS icon must be 1024 × 1024.');
if (png[25] === 6 || png[25] === 4) throw Error('App Store icon must have no alpha channel.');
fs.writeFileSync(path.join(assets, 'Contents.json'), JSON.stringify({info: {author: 'xcode', version: 1}}, null, 2));
fs.writeFileSync(path.join(icons, 'Contents.json'), JSON.stringify({images: [{filename: 'AppIcon.png', idiom: 'universal', platform: 'ios', size: '1024x1024'}], info: {author: 'xcode', version: 1}}, null, 2));
const launch = path.join(assets, 'LaunchBackground.colorset');
fs.mkdirSync(launch, {recursive: true});
fs.writeFileSync(path.join(launch, 'Contents.json'), JSON.stringify({colors: [{idiom: 'universal', color: {'color-space': 'srgb', components: {red: '0.208', green: '0.035', blue: '0.078', alpha: '1.000'}}}], info: {author: 'xcode', version: 1}}, null, 2));
console.log(`Prepared native iOS assets: ${catalog.books.length} references / ${catalog.totalPages} pages, licensed fonts, opaque 1024px icon.`);
