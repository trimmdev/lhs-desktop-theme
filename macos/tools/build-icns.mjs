// Bake the .iconset PNGs and pack a valid .icns without needing macOS/iconutil,
// then parse the result back to prove the container is well formed.
const { chromium } = require('playwright');
const { pathToFileURL } = require('url');
const path = require('path');
const fs = require('fs');

const SRC = path.join(__dirname, 'icon.html');
const OUTDIR = process.argv[2] || path.join(__dirname, 'out');
const ICONSET = path.join(OUTDIR, 'lhs.iconset');
fs.rmSync(OUTDIR, { recursive: true, force: true });
fs.mkdirSync(ICONSET, { recursive: true });

// Apple's required .iconset filenames -> pixel size
const ICONSET_FILES = [
  ['icon_16x16.png',       16],  ['icon_16x16@2x.png',     32],
  ['icon_32x32.png',       32],  ['icon_32x32@2x.png',     64],
  ['icon_128x128.png',    128],  ['icon_128x128@2x.png',  256],
  ['icon_256x256.png',    256],  ['icon_256x256@2x.png',  512],
  ['icon_512x512.png',    512],  ['icon_512x512@2x.png', 1024],
];

// icns chunk OSType -> pixel size, for PNG-payload entries
const ICNS_TYPES = [
  ['icp4',   16], ['icp5',   32], ['icp6',   64],
  ['ic07',  128], ['ic08',  256], ['ic09',  512], ['ic10', 1024],
  ['ic11',   32], ['ic12',   64], ['ic13',  512], ['ic14', 1024],
];

(async () => {
  const browser = await chromium.launch();
  const png = {};                                  // size -> PNG buffer
  const sizes = [...new Set([...ICONSET_FILES.map(f => f[1]), ...ICNS_TYPES.map(t => t[1])])];
  for (const s of sizes.sort((a, b) => a - b)) {
    const ctx = await browser.newContext({ viewport: { width: s, height: s }, deviceScaleFactor: 1 });
    const page = await ctx.newPage();
    await page.goto(pathToFileURL(SRC).href + `?size=${s}`);
    await page.waitForFunction('window.__ready === true', null, { timeout: 30000 });
    png[s] = await page.screenshot({ omitBackground: true, type: 'png' });
    await ctx.close();
  }
  await browser.close();

  for (const [name, s] of ICONSET_FILES) fs.writeFileSync(path.join(ICONSET, name), png[s]);
  console.log(`iconset: ${ICONSET_FILES.length} PNGs -> ${ICONSET}`);

  // ---- pack .icns -------------------------------------------------------
  // Header: 'icns' + big-endian uint32 total file length.
  // Then each entry: 4-char OSType + big-endian uint32 (8 + payload length).
  const chunks = [];
  for (const [type, s] of ICNS_TYPES) {
    const data = png[s];
    const head = Buffer.alloc(8);
    head.write(type, 0, 4, 'ascii');
    head.writeUInt32BE(data.length + 8, 4);
    chunks.push(head, data);
  }
  const bodyLen = chunks.reduce((n, b) => n + b.length, 0);
  const header = Buffer.alloc(8);
  header.write('icns', 0, 4, 'ascii');
  header.writeUInt32BE(bodyLen + 8, 4);
  const icns = Buffer.concat([header, ...chunks]);
  const icnsPath = path.join(OUTDIR, 'lhs.icns');
  fs.writeFileSync(icnsPath, icns);

  // ---- verify by parsing it back ---------------------------------------
  const b = fs.readFileSync(icnsPath);
  if (b.toString('ascii', 0, 4) !== 'icns') throw new Error('bad magic');
  const declared = b.readUInt32BE(4);
  if (declared !== b.length) throw new Error(`length mismatch: header says ${declared}, file is ${b.length}`);
  let off = 8, n = 0;
  const seen = [];
  while (off < b.length) {
    const type = b.toString('ascii', off, off + 4);
    const len = b.readUInt32BE(off + 4);
    if (len < 8 || off + len > b.length) throw new Error(`bad chunk ${type} len ${len} at ${off}`);
    const payload = b.subarray(off + 8, off + len);
    const isPng = payload[0] === 0x89 && payload.toString('ascii', 1, 4) === 'PNG';
    if (!isPng) throw new Error(`chunk ${type} payload is not PNG`);
    // read the PNG IHDR to confirm the declared pixel size
    const w = payload.readUInt32BE(16), h = payload.readUInt32BE(20);
    const want = ICNS_TYPES.find(t => t[0] === type)[1];
    if (w !== want || h !== want) throw new Error(`chunk ${type}: PNG is ${w}x${h}, expected ${want}`);
    seen.push(`${type}=${w}px`);
    off += len; n++;
  }
  console.log(`icns: ${(b.length/1024).toFixed(0)} KB, ${n} chunks verified -> ${icnsPath}`);
  console.log(`  ${seen.join('  ')}`);
})();
