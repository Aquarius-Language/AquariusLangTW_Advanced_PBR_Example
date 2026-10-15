// Real browser startup, including transfer, Wasm compilation and scene setup.
import {createServer} from 'node:http';
import {readFile, writeFile, mkdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const {chromium} = await import(process.env.AQUARIUS_PLAYWRIGHT_ENTRY ?? 'playwright');
const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.resolve(process.env.AQUARIUS_PBR_WEB ?? path.join(project, 'dist/web'));
const output = path.resolve(process.argv[2] ?? path.join(project, 'notes/startup.json'));
const server = createServer(async (req, res) => {
  try {
    const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (!name.startsWith('/project/')) throw Error('Invalid prefix');
    const file = path.resolve(root, name.slice(9) || 'index.html');
    if (!file.startsWith(root + path.sep)) throw Error('Invalid path');
    res.setHeader('Content-Type', ({'.html':'text/html','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm'})[path.extname(file)] ?? 'application/octet-stream');
    res.end(await readFile(file));
  } catch (e) { res.statusCode = 404; res.end(String(e)); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({channel:'chrome', headless:true, args:['--enable-unsafe-webgpu']});
  const page = await browser.newPage({viewport:{width:1024,height:1024}}), errors = [];
  page.setDefaultTimeout(300000);
  page.on('pageerror', e => {errors.push(e.message); console.error(e.message);});
  page.on('console', message => { if (message.type() === 'error') {errors.push(message.text()); console.error(message.text());} });
  await page.goto(`http://127.0.0.1:${server.address().port}/project/?autorun=0`);
  await page.waitForFunction(() => window.aquarius);
  const readyMs = await page.evaluate(() => performance.now());
  console.log(`Bundle ready: ${readyMs.toFixed(0)} ms`);
  await page.evaluate(async () => {
    const {CapabilityHost} = await import('./capability-host.mjs');
    const original = CapabilityHost.prototype.bind;
    globalThis.startupCalls = {};
    CapabilityHost.prototype.bind = function (module, library, name, fn, raw) {
      return original.call(this, module, library, name, (...args) => {
        const key = `${library}.${name}`, started = performance.now();
        const record = () => {
          const item = startupCalls[key] ??= {count:0,ms:0};
          item.count++; item.ms += performance.now() - started;
        };
        try {
          const value = fn(...args);
          if (value?.then) return value.finally(record);
          record(); return value;
        } catch (e) { record(); throw e; }
      }, raw);
    };
    globalThis.sceneStarted = performance.now();
    globalThis.sceneTask = aquarius.run('main.aqua', 0).catch(e => {
      if (!e.message.includes('cancel')) throw e;
    });
  });
  await page.waitForFunction(() => window.aquarius.host?.processing.frameCount >= 2 || window.aquarius.state === 'error');
  const result = await page.evaluate(() => ({
    firstFramesMs:performance.now(), sceneMs:performance.now()-sceneStarted,
    calls:Object.fromEntries(Object.entries(startupCalls).sort((a,b)=>b[1].ms-a[1].ms).slice(0,30)),
    resources:performance.getEntriesByType('resource').map(r=>({name:new URL(r.name).pathname,bytes:r.decodedBodySize,ms:r.duration})),
    output:document.getElementById('output').textContent,
    memory:performance.memory ? {used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}:null,
  }));
  result.readyMs = readyMs; result.errors = errors;
  await mkdir(path.dirname(output), {recursive:true});
  await writeFile(output, JSON.stringify(result, null, 2));
  console.log(JSON.stringify({readyMs,sceneMs:result.sceneMs,firstFramesMs:result.firstFramesMs,errors,slowest:Object.entries(result.calls).slice(0,8)}, null, 2));
  await page.evaluate(() => window.aquarius.stop());
  if (errors.length) throw Error(errors.join('\n'));
} finally { await browser?.close(); await new Promise(resolve => server.close(resolve)); }
