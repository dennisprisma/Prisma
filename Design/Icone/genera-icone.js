#!/usr/bin/env node
/*
 * Prisma — generatore delle icone in vetro (tema Liquid Glass) e dell'icona dell'app.
 *
 * Fonti:
 *   Design/tema-liquid-glass.html      colori delle app (APPS, HOME, ACC) e glifi (GLYPH), letti dal tema stesso
 *   Design/Logo/Prisma_logo_bianco.svg il simbolo di Prisma (piastrella della Scrivania e icona dell'app)
 *
 * Risultato:
 *   Design/Icone/<Nome>.svg                    sorgente vettoriale di ogni icona (512×512)
 *   Sources/Prisma/Risorse/Icone/<Nome>.png    PNG 512×512 con trasparenza, caricate dall'app
 *   Design/Icone/AppIcon.svg / AppIcon.png     icona del Mac 1024×1024 (la CI ne ricava AppIcon.icns)
 *   Design/Icone/Anteprima_icone.png           tavola di controllo su fondo chiaro e scuro
 *
 * Uso (dalla radice del repository, con Playwright e Chromium già presenti):
 *   NODE_PATH=$(npm root -g) node Design/Icone/genera-icone.js
 *   NODE_PATH=$(npm root -g) node Design/Icone/genera-icone.js --uscita /percorso/di/prova
 *     (--uscita scrive tutto in un'altra cartella, senza toccare il repository)
 *
 * Geometria (uguale alle icone precedenti, così l'app non cambia codice):
 *   tela 512×512, piastrella 480×480 in (16, 12), raggio 23,5% come `.ic` del tema.
 *   Le misure in px del tema valgono per l'icona del dock da 50 px: qui sono moltiplicate per 480/50.
 *   I glifi del tema sono in un riquadro 64×64: qui scala 480/64 = 7,5.
 *
 * Agenda: l'app scrive mese e giorno da sé. Agenda_base è la piastrella senza riflesso e senza data,
 * Agenda_vetro è solo il riflesso, da posare sopra la data (come `.ic::after` nel tema).
 * Agenda.svg è un esempio con una data, solo per riferimento.
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { chromium } = require('playwright');

const RADICE = path.resolve(__dirname, '..', '..');
const TEMA = path.join(RADICE, 'Design', 'tema-liquid-glass.html');
const LOGO = path.join(RADICE, 'Design', 'Logo', 'Prisma_logo_bianco.svg');

const arg = process.argv.indexOf('--uscita');
const USCITA = arg > 0 ? path.resolve(process.argv[arg + 1]) : null;
const DIR_SVG = USCITA ? path.join(USCITA, 'svg') : path.join(RADICE, 'Design', 'Icone');
const DIR_PNG = USCITA ? path.join(USCITA, 'png') : path.join(RADICE, 'Sources', 'Prisma', 'Risorse', 'Icone');
const DIR_APP = USCITA ? USCITA : path.join(RADICE, 'Design', 'Icone');

// Nome del file nell'app → id nel tema (mappa di AppPrisma.icona)
const ICONE = [
  ['Clienti', 'clienti'], ['Analisi', 'posizioni'], ['Analisi_360', 'analisi360'], ['Incontri', 'incontri'],
  ['Obiettivi', 'obiettivi'], ['Confronti', 'confronti'], ['Prodotti', 'prodotti'], ['Simulazioni', 'simulazioni'],
  ['Attivita', 'attivita'], ['Note', 'note'], ['Documenti', 'documenti'], ['Presentazioni', 'presentazioni'],
  ['Eve', 'eve'], ['Ricerca', 'ricerca'], ['Impostazioni', 'impostazioni'], ['Prisma', 'home']
];

// Geometria
const LATO = 512, P = 480, X0 = 16, Y0 = 12;
const K = P / 50;          // px del tema (icona da 50) → px della tela
const G = P / 64;          // unità del glifo → px della tela
const R = P * 0.235;       // raggio della piastrella

const FONT = "-apple-system, 'SF Pro Text', 'Helvetica Neue', Inter, sans-serif";
const FONT_D = "-apple-system, 'SF Pro Display', 'Helvetica Neue', 'Inter Display', Inter, sans-serif";
const FONT_R = "ui-rounded, 'SF Pro Rounded', -apple-system, 'Inter Display', Inter, sans-serif";

const n2 = v => +v.toFixed(3);

// Gradiente lineare CSS ad angolo `gradi` su un quadrato → coordinate objectBoundingBox
function lineaCSS(gradi) {
  const a = gradi * Math.PI / 180, dx = Math.sin(a), dy = -Math.cos(a);
  const meta = (Math.abs(dx) + Math.abs(dy)) / 2;
  return `x1="${n2(0.5 - dx * meta)}" y1="${n2(0.5 - dy * meta)}" x2="${n2(0.5 + dx * meta)}" y2="${n2(0.5 + dy * meta)}"`;
}

// Gradienti comuni dei glifi (defs del tema)
const DEFS_GLIFI = `
    <linearGradient id="lgGlass" x1="0" y1="0" x2=".45" y2="1"><stop offset="0" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity=".8"/></linearGradient>
    <linearGradient id="lgBeam" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff"/></linearGradient>
    <radialGradient id="lgEveOrb" cx="35%" cy="25%" r="80%"><stop offset="0" stop-color="#F3D7FF"/><stop offset=".35" stop-color="#B28DF4"/><stop offset=".72" stop-color="#6964D8"/><stop offset="1" stop-color="#3C3D92"/></radialGradient>`;

// Classi dei glifi (`.ic .g1` … del tema, stile «colori»)
function stileGlifi(acc, chiara) {
  return `
    .g1 { fill: url(#lgGlass); }
    .g2 { fill: #fff; fill-opacity: .5; }
    .gs { stroke: ${chiara ? 'rgba(0,0,0,.24)' : '#fff'}; }
    .g3 { fill: ${acc || '#FF3B30'}; }
    .gk { fill: #1C1C1E; }
    .gl { stroke: rgba(0,0,0,.2); fill: none; }
    .gt { fill: #fff; font: 800 13px/1 ${FONT_R}; letter-spacing: -.4px; }
    .gtk { fill: #1C1C1E; font: 600 7.5px/1 ${FONT_R}; }
    .gt-mon { font: 700 10.5px/1 ${FONT}; letter-spacing: .08em; }
    .gt-day { font: 300 30px/1 ${FONT_D}; letter-spacing: -1px; }
    .gw { fill: #fff; }
    .gws { stroke: #fff; }`;
}

/*
 * Una icona: piastrella `.ic` del tema tradotta in SVG.
 *   ombra esterna   0 (sz·.05) (sz·.14) (−sz·.03) rgba(0,0,0,.32), sfumata ai bordi della tela
 *   fondo           linear-gradient(165deg, c1, c2)
 *   ombre interne   inset 0 1 0 bianco .55 · inset 0 0 0 .5 bianco .22 · inset 0 −1 1 nero .14
 *   glifo           drop-shadow(0 sz·.015 sz·.02 rgba(0,0,0,.22))
 *   riflesso        ::after linear-gradient(170deg, bianco .36 0%, .07 42%, 0 62%), sopra il glifo
 * parti: 'tutto' | 'base' (senza riflesso né glifo) | 'vetro' (solo riflesso)
 */
function svgIcona({ titolo, c1, c2, acc, chiara, glifo, parti = 'tutto' }) {
  const piastrella = `x="${X0}" y="${Y0}" width="${P}" height="${P}" rx="${n2(R)}"`;
  const spread = 0.03 * 50 * K, dy = 0.05 * 50 * K, sfoc = 0.14 * 50 * K / 2;
  const ombra = `x="${n2(X0 + spread)}" y="${n2(Y0 + spread + dy)}" width="${n2(P - 2 * spread)}" height="${n2(P - 2 * spread)}" rx="${n2(R - spread)}"`;
  const conBase = parti !== 'vetro', conGlifo = parti === 'tutto', conRiflesso = parti !== 'base';
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${LATO}" height="${LATO}" viewBox="0 0 ${LATO} ${LATO}">
  <title>${titolo}</title>
  <defs>${DEFS_GLIFI}
    <linearGradient id="fondo" ${lineaCSS(165)}><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient>
    <linearGradient id="riflesso" ${lineaCSS(170)}><stop offset="0" stop-color="#fff" stop-opacity=".36"/><stop offset=".42" stop-color="#fff" stop-opacity=".07"/><stop offset=".62" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <clipPath id="forma"><rect ${piastrella}/></clipPath>
    <linearGradient id="sfumaX" x1="0" x2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset="${n2(X0 / LATO)}" stop-color="#fff"/><stop offset="${n2(1 - X0 / LATO)}" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <linearGradient id="sfumaY" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset="${n2(Y0 / LATO)}" stop-color="#fff"/><stop offset="${n2((Y0 + P) / LATO)}" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <mask id="bordoX" maskUnits="userSpaceOnUse" x="0" y="0" width="${LATO}" height="${LATO}"><rect width="${LATO}" height="${LATO}" fill="url(#sfumaX)"/></mask>
    <mask id="bordoY" maskUnits="userSpaceOnUse" x="0" y="0" width="${LATO}" height="${LATO}"><rect width="${LATO}" height="${LATO}" fill="url(#sfumaY)"/></mask>
    <filter id="sfocaOmbra" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="${n2(sfoc)}"/></filter>
    <mask id="luce" maskUnits="userSpaceOnUse" x="0" y="0" width="${LATO}" height="${LATO}"><rect ${piastrella} fill="#fff"/><rect ${piastrella} transform="translate(0 ${n2(K)})" fill="#000"/></mask>
    <mask id="buio" maskUnits="userSpaceOnUse" x="-50" y="-50" width="${LATO + 100}" height="${LATO + 100}"><rect x="-50" y="-50" width="${LATO + 100}" height="${LATO + 100}" fill="#fff"/><rect ${piastrella} transform="translate(0 ${n2(-K)})" fill="#000"/></mask>
    <filter id="sfocaBuio" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="${n2(K / 2)}"/></filter>
    <filter id="ombraGlifo" x="-25%" y="-25%" width="150%" height="150%"><feDropShadow dx="0" dy="${n2(0.015 * P)}" stdDeviation="${n2(0.02 * P / 2)}" flood-color="#000" flood-opacity=".22"/></filter>
  </defs>
  <style>${stileGlifi(acc, chiara)}
  </style>`;
  if (conBase) {
    s += `
  <g mask="url(#bordoX)"><g mask="url(#bordoY)"><rect ${ombra} fill="#000" fill-opacity=".32" filter="url(#sfocaOmbra)"/></g></g>
  <rect ${piastrella} fill="url(#fondo)"/>
  <g clip-path="url(#forma)">
    <rect x="0" y="0" width="${LATO}" height="${LATO}" fill="#fff" fill-opacity=".55" mask="url(#luce)"/>
    <rect ${piastrella} fill="none" stroke="#fff" stroke-opacity=".22" stroke-width="${n2(K)}"/>
    <g filter="url(#sfocaBuio)"><rect x="-50" y="-50" width="${LATO + 100}" height="${LATO + 100}" fill="#000" fill-opacity=".14" mask="url(#buio)"/></g>
  </g>`;
  }
  if (conGlifo && glifo) {
    s += `
  <g filter="url(#ombraGlifo)"><g transform="translate(${X0} ${Y0}) scale(${G})">${glifo}</g></g>`;
  }
  if (conRiflesso) {
    s += `
  <rect ${piastrella} fill="url(#riflesso)"/>`;
  }
  return s + '\n</svg>\n';
}

// Dal codice del tema: tabella delle app (APPS, HOME, ACC) e glifi (gearPath, GEAR, GLYPH).
// Nel tema stanno dentro una funzione: i due brani vengono ritagliati dal testo ed eseguiti a parte.
function leggiTema() {
  const html = fs.readFileSync(TEMA, 'utf8');
  const brano = (da, a) => {
    const i = html.indexOf(da), j = html.indexOf(a, i);
    if (i < 0 || j < 0) throw new Error('Tema: non trovo «' + da + '» … «' + a + '»');
    return html.slice(i, j);
  };
  const codice = brano('const POS_SOON', 'const WS') + brano('function gearPath', 'function icon(') +
    'return { APPS, HOME, ACC, GLYPH };';
  const { APPS, HOME, ACC, GLYPH } = new Function(codice)();
  const glifi = {};
  Object.keys(GLYPH).forEach(k => { if (k !== 'agenda') glifi[k] = GLYPH[k](); });
  return { apps: APPS, home: HOME, acc: ACC, glifi };
}

// Simbolo di Prisma dal file del logo: tre tracciati con le loro opacità
function leggiLogo() {
  const svg = fs.readFileSync(LOGO, 'utf8');
  const tracciati = [...svg.matchAll(/<path\s+d="([^"]+)"(?:\s+fill-opacity="([^"]+)")?/g)].map(m => ({ d: m[1], op: m[2] || '1' }));
  if (tracciati.length !== 3) throw new Error('Logo: attesi 3 tracciati, trovati ' + tracciati.length);
  return tracciati;
}
// Riquadro del simbolo nel viewBox 680 (misurato sui tracciati)
const LOGO_X = [43.06, 636.94], LOGO_Y = [73.78, 608];

function logoIn(tracciati, cx, cy, larghezza, colore = '#fff') {
  const sc = larghezza / (LOGO_X[1] - LOGO_X[0]);
  const mx = (LOGO_X[0] + LOGO_X[1]) / 2, my = (LOGO_Y[0] + LOGO_Y[1]) / 2;
  return `<g transform="translate(${n2(cx)} ${n2(cy)}) scale(${sc.toFixed(5)}) translate(${n2(-mx)} ${n2(-my)})" fill="${colore}">` +
    tracciati.map(t => `<path d="${t.d}"${t.op !== '1' ? ` fill-opacity="${t.op}"` : ''}/>`).join('') + '</g>';
}

// Rettangolo ad angoli continui (stile macOS): angoli a superellisse raccordati ai lati dritti
function piastrellaContinua(x, y, w, h, r, esp = 3.26, passi = 48) {
  const s = Math.min(1.528 * r, w / 2, h / 2);
  const angoli = [
    [x + w - s, y + s, 1, -1, 'alto-destra'], [x + w - s, y + h - s, 1, 1, 'basso-destra'],
    [x + s, y + h - s, -1, 1, 'basso-sinistra'], [x + s, y + s, -1, -1, 'alto-sinistra']
  ];
  const punti = [];
  angoli.forEach(([cx, cy, sx, sy], i) => {
    for (let k = 0; k <= passi; k++) {
      // da metà lato orizzontale/verticale percorso in senso orario
      let t = (k / passi) * Math.PI / 2;
      if (i % 2 === 0) t = Math.PI / 2 - t;
      const c = Math.pow(Math.cos(t), 2 / esp), sn = Math.pow(Math.sin(t), 2 / esp);
      punti.push([cx + sx * s * c, cy + sy * s * sn]);
    }
  });
  return 'M' + punti.map(p => p[0].toFixed(2) + ' ' + p[1].toFixed(2)).join('L') + 'Z';
}

// Icona dell'app per il Mac: 1024, piastrella 824 centrata, logo bianco, vetro leggero
function svgAppIcon(tracciati) {
  const L = 1024, M = 100, T = 824, RR = 185.4;
  const forma = piastrellaContinua(M, M, T, T, RR);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${L}" height="${L}" viewBox="0 0 ${L} ${L}">
  <title>Prisma</title>
  <defs>
    <linearGradient id="fondo" ${lineaCSS(165)}><stop offset="0" stop-color="#2F4C63"/><stop offset="1" stop-color="#0E1D29"/></linearGradient>
    <radialGradient id="alone" cx=".3" cy=".08" r=".85"><stop offset="0" stop-color="#9CCBE6" stop-opacity=".34"/><stop offset=".55" stop-color="#9CCBE6" stop-opacity=".06"/><stop offset="1" stop-color="#9CCBE6" stop-opacity="0"/></radialGradient>
    <linearGradient id="riflesso" ${lineaCSS(170)}><stop offset="0" stop-color="#fff" stop-opacity=".26"/><stop offset=".42" stop-color="#fff" stop-opacity=".05"/><stop offset=".62" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <linearGradient id="filo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".35" stop-color="#fff" stop-opacity=".12"/><stop offset=".8" stop-color="#fff" stop-opacity=".06"/><stop offset="1" stop-color="#fff" stop-opacity=".16"/></linearGradient>
    <clipPath id="forma"><path d="${forma}"/></clipPath>
    <mask id="buio" maskUnits="userSpaceOnUse" x="0" y="0" width="${L}" height="${L}"><rect width="${L}" height="${L}" fill="#fff"/><path d="${forma}" transform="translate(0 -10)" fill="#000"/></mask>
    <filter id="sfoca" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="8"/></filter>
    <filter id="ombra" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity=".28"/>
      <feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity=".18"/>
    </filter>
    <filter id="ombraLogo" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="9" stdDeviation="11" flood-color="#000" flood-opacity=".32"/></filter>
  </defs>
  <path d="${forma}" fill="url(#fondo)" filter="url(#ombra)"/>
  <g clip-path="url(#forma)">
    <rect width="${L}" height="${L}" fill="url(#alone)"/>
    <g filter="url(#sfoca)"><rect width="${L}" height="${L}" fill="#000" fill-opacity=".35" mask="url(#buio)"/></g>
    <g filter="url(#ombraLogo)">${logoIn(tracciati, L / 2, L / 2 + 8, 0.6 * T)}</g>
    <rect width="${L}" height="${L}" fill="url(#riflesso)"/>
    <path d="${forma}" fill="none" stroke="url(#filo)" stroke-width="7"/>
  </g>
</svg>
`;
}

async function rasterizza(pagina, svg, lato, file) {
  await pagina.setViewportSize({ width: lato, height: lato });
  await pagina.setContent(`<!doctype html><html><head><style>html,body{margin:0;background:transparent}svg{display:block}</style></head><body>${svg}</body></html>`);
  await pagina.evaluate(() => document.fonts.ready);
  await pagina.screenshot({ path: file, omitBackground: true, clip: { x: 0, y: 0, width: lato, height: lato } });
}

// Tavola di controllo: tutte le icone su fondo chiaro e scuro
function svgTavola(voci) {
  const col = 6, c = 150, ic = 112, righe = Math.ceil(voci.length / col);
  const img = ([n, file], x, y) => `<image href="data:image/png;base64,${fs.readFileSync(file).toString('base64')}" x="${x}" y="${y}" width="${ic}" height="${ic}"/>` +
    `<text x="${x + ic / 2}" y="${y + ic + 20}" text-anchor="middle" font-family="Inter, sans-serif" font-size="13" fill="currentColor">${n}</text>`;
  const W = col * c * 2 + 40, H = righe * (c + 20) + 40;
  let s = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">`;
  s += `<rect width="${W / 2}" height="${H}" fill="#E9EEF3"/><rect x="${W / 2}" width="${W / 2}" height="${H}" fill="#14181D"/>`;
  [['#2A2F36', 0], ['#E6E9ED', W / 2]].forEach(([colore, ox]) => {
    s += `<g style="color:${colore}">`;
    voci.forEach((v, i) => { s += img(v, ox + 20 + (i % col) * c + (c - ic) / 2, 20 + Math.floor(i / col) * (c + 20)); });
    s += '</g>';
  });
  return { svg: s + '</svg>', W, H };
}

(async () => {
  for (const d of [DIR_SVG, DIR_PNG, DIR_APP]) fs.mkdirSync(d, { recursive: true });
  const browser = await chromium.launch();
  const pagina = await browser.newPage({ viewport: { width: LATO, height: LATO }, deviceScaleFactor: 1 });

  // 1. Colori e glifi letti dal tema
  const tema = leggiTema();
  const dati = id => id === 'home' ? tema.home : tema.apps.find(a => a.id === id);
  const tracciati = leggiLogo();

  // 2. Icone delle app
  const nomi = [];
  for (const [nome, id] of ICONE) {
    const a = dati(id);
    // Scrivania: il simbolo di Prisma al posto del prisma del tema
    const glifo = id === 'home' ? logoIn(tracciati, 32, 32.6, 38) : tema.glifi[id];
    const svg = svgIcona({ titolo: id === 'home' ? 'Prisma' : a.t, c1: a.c1, c2: a.c2, acc: tema.acc[id], chiara: !!a.light, glifo });
    fs.writeFileSync(path.join(DIR_SVG, nome + '.svg'), svg);
    await rasterizza(pagina, svg, LATO, path.join(DIR_PNG, nome + '.png'));
    nomi.push(nome);
  }

  // 3. Agenda: base senza data, vetro sopra la data, esempio con data
  const ag = dati('agenda');
  const temporanea = fs.mkdtempSync(path.join(os.tmpdir(), 'prisma-icone-'));
  const esempioPng = path.join(temporanea, 'Agenda.png');
  const baseAgenda = { c1: ag.c1, c2: ag.c2, acc: tema.acc.agenda, chiara: true };
  const esempio = '<text class="g3 gt-mon" x="32" y="20.5" text-anchor="middle">OTT</text><text class="gk gt-day" x="32" y="49.5" text-anchor="middle">27</text>';
  const varianti = [
    ['Agenda_base', { ...baseAgenda, titolo: 'Agenda (senza data)', parti: 'base' }, true],
    ['Agenda_vetro', { ...baseAgenda, titolo: 'Agenda (riflesso sopra la data)', parti: 'vetro' }, true],
    ['Agenda', { ...baseAgenda, titolo: 'Agenda (esempio con data)', glifo: esempio }, false]
  ];
  for (const [nome, opz, risorsa] of varianti) {
    const svg = svgIcona(opz);
    fs.writeFileSync(path.join(DIR_SVG, nome + '.svg'), svg);
    await rasterizza(pagina, svg, LATO, risorsa ? path.join(DIR_PNG, nome + '.png') : esempioPng);
  }

  // 4. Icona dell'app per il Mac
  const appIcon = svgAppIcon(tracciati);
  fs.writeFileSync(path.join(DIR_SVG, 'AppIcon.svg'), appIcon);
  await rasterizza(pagina, appIcon, 1024, path.join(DIR_APP, 'AppIcon.png'));

  // 5. Tavola di controllo
  const voci = nomi.map(n => [n, path.join(DIR_PNG, n + '.png')]);
  voci.splice(8, 0, ['Agenda', esempioPng]);
  const tavola = svgTavola(voci);
  await pagina.setViewportSize({ width: tavola.W, height: tavola.H });
  await pagina.setContent(`<!doctype html><html><body style="margin:0">${tavola.svg}</body></html>`);
  await pagina.screenshot({ path: path.join(DIR_APP, 'Anteprima_icone.png'), clip: { x: 0, y: 0, width: tavola.W, height: tavola.H } });
  fs.rmSync(temporanea, { recursive: true, force: true });

  await browser.close();
  console.log('Icone generate: ' + (nomi.length + 2) + ' PNG in ' + DIR_PNG + ', AppIcon in ' + DIR_APP);
})().catch(e => { console.error(e); process.exit(1); });
