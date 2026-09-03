// Node self-test for JS helpers extracted from js_sniffer_scripts.dart
// Run: node test/js_sniffer_parser.test.js
const assert = require('assert');

// --- copy of parseBestSrcset (spec-compliant, no x*1000 bug) ---
function parseBestSrcset(srcsetStr) {
  if (!srcsetStr || typeof srcsetStr !== 'string') return null;
  const rawParts = srcsetStr.split(',');
  const wCandidates = [];
  const xCandidates = [];
  for (let i = 0; i < rawParts.length; i++) {
    const entry = rawParts[i].trim();
    if (!entry) continue;
    const tokens = entry.split(/\s+/).filter(Boolean);
    const url = tokens[0];
    if (!url) continue;
    if (tokens.length === 1) { xCandidates.push({ url, score: 1 }); continue; }
    const desc = tokens[1].toLowerCase();
    if (desc.endsWith('w')) {
      const w = parseInt(desc.slice(0, -1), 10);
      if (!isNaN(w) && w > 0) wCandidates.push({ url, score: w });
    } else if (desc.endsWith('x')) {
      const x = parseFloat(desc.slice(0, -1));
      if (!isNaN(x) && x > 0) xCandidates.push({ url, score: x });
    } else {
      xCandidates.push({ url, score: 1 });
    }
  }
  if (wCandidates.length > 0) { wCandidates.sort((a,b)=>b.score-a.score); return wCandidates[0].url; }
  if (xCandidates.length > 0) { xCandidates.sort((a,b)=>b.score-a.score); return xCandidates[0].url; }
  return null;
}
function getBestSrcForImg(img){
  if (img.currentSrc && img.currentSrc.trim()) return img.currentSrc;
  if (img.srcset) { const best = parseBestSrcset(img.srcset); if(best) return best; }
  return img.src || null;
}
// --- copy of reportM3u8Variants ---
function reportM3u8VariantsForTest(manifestText, baseUrl){
  const lines = manifestText.split('\n');
  const out=[];
  for(let i=0;i<lines.length;i++){
    const line=lines[i].trim();
    if(!line.startsWith('#EXT-X-STREAM-INF')) continue;
    let w=0,h=0; const m=/RESOLUTION=(\d+)x(\d+)/i.exec(line);
    if(m){w=parseInt(m[1],10); h=parseInt(m[2],10);}
    const urlLine=(lines[i+1]||'').trim();
    if(urlLine && !urlLine.startsWith('#')){ try{ out.push({url:new URL(urlLine,baseUrl).href,w,h}); }catch(_){}}
  }
  return out;
}

let pass=0, fail=0;
function test(name, fn){
  try{ fn(); console.log(`✓ ${name}`); pass++;}
  catch(e){ console.error(`✗ ${name}: ${e.message}`); fail++;}
}

test('parseBestSrcset: w descriptors — picks largest w', ()=>{
  const s='https://cdn/a-400.jpg 400w, https://cdn/a-800.jpg 800w, https://cdn/a-1200.jpg 1200w';
  assert.strictEqual(parseBestSrcset(s), 'https://cdn/a-1200.jpg');
});
test('parseBestSrcset: x descriptors — picks largest x (no x*1000)', ()=>{
  const s='https://cdn/a.jpg 1x, https://cdn/a-2x.jpg 2x, https://cdn/a-1.5x.jpg 1.5x';
  assert.strictEqual(parseBestSrcset(s), 'https://cdn/a-2x.jpg');
});
test('parseBestSrcset: mixed w+x — prefers w', ()=>{
  const s='https://cdn/a-800.jpg 800w, https://cdn/a-2x.jpg 2x';
  assert.strictEqual(parseBestSrcset(s), 'https://cdn/a-800.jpg');
});
test('parseBestSrcset: no descriptor → 1x fallback', ()=>{
  assert.strictEqual(parseBestSrcset('https://cdn/a.jpg'), 'https://cdn/a.jpg');
});
test('parseBestSrcset: empty/null → null', ()=>{
  assert.strictEqual(parseBestSrcset(''), null);
  assert.strictEqual(parseBestSrcset(null), null);
});
test('getBestSrcForImg: prefers currentSrc over srcset', ()=>{
  const img={currentSrc:'https://cdn/chosen.jpg', srcset:'https://cdn/a-400.jpg 400w, https://cdn/a-800.jpg 800w', src:'https://cdn/fallback.jpg'};
  assert.strictEqual(getBestSrcForImg(img), 'https://cdn/chosen.jpg');
});
test('getBestSrcForImg: falls back to parseBestSrcset when currentSrc empty', ()=>{
  const img={currentSrc:'', srcset:'https://cdn/a-400.jpg 400w, https://cdn/a-800.jpg 800w', src:'https://cdn/fallback.jpg'};
  assert.strictEqual(getBestSrcForImg(img), 'https://cdn/a-800.jpg');
});
test('reportM3u8Variants: extracts RESOLUTION + resolves relative URLs', ()=>{
  const manifest='#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\n360p.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=1400000,RESOLUTION=1280x720\n720p.m3u8\n';
  const base='https://cdn.example.com/hls/master.m3u8';
  const out=reportM3u8VariantsForTest(manifest, base);
  assert.strictEqual(out.length, 2);
  assert.strictEqual(out[0].url, 'https://cdn.example.com/hls/360p.m3u8');
  assert.deepStrictEqual([out[0].w,out[0].h],[640,360]);
  assert.deepStrictEqual([out[1].w,out[1].h],[1280,720]);
});
test('reportM3u8Variants: variant without RESOLUTION → 0x0', ()=>{
  const manifest='#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000\naudio.m3u8\n';
  const out=reportM3u8VariantsForTest(manifest,'https://cdn.example.com/m.m3u8');
  assert.strictEqual(out[0].w,0); assert.strictEqual(out[0].h,0);
});

test('reportM3u8Variants: ignores comment lines between variants', ()=>{
  const manifest='#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360\n# comment\n360p.m3u8\n';
  const out=reportM3u8VariantsForTest(manifest,'https://cdn.example.com/m.m3u8');
  assert.strictEqual(out.length, 0);
});

// P0/P2: isAdUrl + reportedUrls dedup
const AD_DOMAINS=['doubleclick.net','googleads','googlesyndication','google-analytics','facebook.com/tr','taboola.com','outbrain.com','criteo.com','scorecardresearch.com','quantserve.com','adnxs.com','amazon-adsystem.com','rubiconproject.com','pubmatic.com','openx.net','casalemedia.com','tracking','analytics','telemetry','beacon','adservice'];
function isAdUrl(url){ if(!url||typeof url!=='string') return true; const l=url.toLowerCase(); return AD_DOMAINS.some(a=>l.includes(a)); }

test('isAdUrl: blocks doubleclick / scorecardresearch / googlesyndication', ()=>{
  assert.strictEqual(isAdUrl('https://doubleclick.net/ad'), true);
  assert.strictEqual(isAdUrl('https://scorecardresearch.com/beacon.js'), true);
  assert.strictEqual(isAdUrl('https://googlesyndication.com/pagead/js'), true);
});
test('isAdUrl: allows normal cdn', ()=>{
  assert.strictEqual(isAdUrl('https://cdn.example.com/video.mp4'), false);
  assert.strictEqual(isAdUrl('https://images.unsplash.com/photo.jpg'), false);
});
test('isAdUrl: null/empty → true (blocked)', ()=>{
  assert.strictEqual(isAdUrl(null), true);
  assert.strictEqual(isAdUrl(''), true);
});
test('reportedUrls dedup: same canonical not reported twice (simulated Set)', ()=>{
  const seen=new Set();
  function shouldReport(u){ const c=u.toLowerCase(); if(seen.has(c)) return false; seen.add(c); return true; }
  assert.strictEqual(shouldReport('https://cdn.example.com/a.mp4'), true);
  assert.strictEqual(shouldReport('https://cdn.example.com/a.mp4'), false);
  assert.strictEqual(shouldReport('https://CDN.example.com/A.MP4'), false);
});

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail?1:0);
