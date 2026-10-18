#!/usr/bin/env node
// ShopEazy brand check. Reads only the lines a PR adds, so old code never blocks new work.
// Rules come from shopeazy-brand (BRAND.md, VOICE.md). Used by .github/workflows/brand.yml
// and by the shopeazy-brand Claude plugin's /brand-check.
//
//   node brand-check.mjs [--base <ref>] [--surface marketing|product|api|tooling] [--mode warn|block]
//
// --base   diff against this ref (default origin/main). Without a usable base, only the docs check runs.
// --mode   warn (default): report, exit 0. block: exit 1 when anything is found.
import { execSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const arg = (n, d) => { const i = process.argv.indexOf(`--${n}`); return i > -1 ? process.argv[i + 1] : d; };
const base = arg('base', 'origin/main');
const surface = arg('surface', 'product');
const mode = arg('mode', 'warn');
const inCI = !!process.env.GITHUB_ACTIONS;

const REQUIRED_DOCS = ['PRODUCT.md', 'DESIGN.md', 'AGENTS.md', 'CLAUDE.md'];
const CODE = /\.(tsx|jsx|ts|js|mjs|css|scss)$/;
const COPY = /\.(tsx|jsx|ts|js|mdx?|json)$/;
// Places a raw hex is the right answer: token sources, emails (inline styles), OG/social images,
// generated files, tests, the brand repo itself.
const HEX_OK = /(tokens|globals\.css|tailwind|theme|\/emails?\/|email-|\/og[-/]|opengraph|-image\.|icon\.|manifest|\.svg|\.test\.|\.spec\.|__tests__|\/e2e\/|\/test\/|dist\/|generated|brand-check)/i;
const SKIP = /(package-lock\.json|\.lock$|CHANGELOG|\/dist\/|\.min\.|brand-check\.mjs$)/;

const RULES = [
  { id: 'name', re: /\b(Shopeazy|Shop Eazy|SHOP EAZY)\b/, files: COPY, msg: 'Write the name as "ShopEazy" (one word, capital S and E).' },
  { id: 'submit', re: />\s*Submit\s*<|(['"`])Submit\1/, files: /\.(tsx|jsx)$/, msg: 'Buttons are one verb that says what happens (Save, Pay, Send), never "Submit".' },
  { id: 'click-here', re: /\bclick here\b/i, files: COPY, msg: 'Never "Click here": name the thing the link opens.' },
  { id: 'rands', re: /rands per channel/i, files: COPY, msg: 'Never "rands per channel": say sales, or what it sold.' },
  { id: 'emoji', re: /\p{Extended_Pictographic}/u, files: /\.(tsx|jsx)$/, surfaces: ['product'], msg: 'No emoji in the product.' },
  { id: 'hex', re: /#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3}(?:[0-9a-fA-F]{2})?)?\b/, files: CODE, skip: HEX_OK, msg: 'Raw hex colour: use a design token (@shopeazy/tokens).' },
];

const sh = (c) => execSync(c, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 << 20 });
const findings = [];

for (const f of REQUIRED_DOCS) if (!existsSync(f)) findings.push({ file: f, line: 1, id: 'docs', msg: `${f} is missing. Every ShopEazy repo has PRODUCT.md, DESIGN.md, AGENTS.md and CLAUDE.md (see shopeazy-brand).` });

let diff = '';
try { diff = sh(`git diff -U0 --no-color ${base}...HEAD`); }
catch { try { diff = sh(`git diff -U0 --no-color ${base}`); } catch { console.log(`brand-check: no diff against ${base}; docs check only.`); } }

let file = null, line = 0;
for (const l of diff.split('\n')) {
  if (l.startsWith('+++ ')) { file = l.startsWith('+++ b/') ? l.slice(6) : null; continue; }
  const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
  if (h) { line = +h[1]; continue; }
  if (!file || SKIP.test(file)) continue;
  if (l.startsWith('+') && !l.startsWith('+++')) {
    const text = l.slice(1);
    for (const r of RULES) {
      if (!r.files.test(file) || (r.skip && r.skip.test(file)) || (r.surfaces && !r.surfaces.includes(surface))) continue;
      if (r.id === 'hex' && /url\(|href=|&#|\bcolor-mix\b/.test(text)) continue;
      if (r.re.test(text)) findings.push({ file, line, id: r.id, msg: r.msg, text: text.trim().slice(0, 120) });
    }
    line++;
  }
}

const level = mode === 'block' ? 'error' : 'warning';
for (const f of findings) {
  if (inCI) console.log(`::${level} file=${f.file},line=${f.line},title=Brand (${f.id})::${f.msg}`);
  else console.log(`${f.file}:${f.line}  [${f.id}] ${f.msg}${f.text ? `\n    ${f.text}` : ''}`);
}
const summary = findings.length
  ? `### Brand check: ${findings.length} finding${findings.length === 1 ? '' : 's'} (${mode})\n\n| File | Line | Rule | Fix |\n|---|---|---|---|\n` + findings.map((f) => `| ${f.file} | ${f.line} | ${f.id} | ${f.msg} |`).join('\n')
  : '### Brand check: clean';
if (process.env.GITHUB_STEP_SUMMARY) execSync(`cat >> "$GITHUB_STEP_SUMMARY"`, { input: summary + '\n' });
console.log(findings.length ? `\n${findings.length} brand finding(s), mode ${mode}.` : 'Brand check: clean.');
process.exit(mode === 'block' && findings.length ? 1 : 0);
