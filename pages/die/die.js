// The live die: die.bin from demo/live_die.py, drawn on a canvas. Cells are coloured
// faintly by block, and a net that switches lights its wires and the cell driving it, fading
// over a few cycles. Coordinates are in the file's steps (20 nm), y up. Each cell knows the
// src line it came from, which the search box lights.
"use strict";

const $ = (id) => document.getElementById(id);
const NONE = 0xffff;

// ---- the file ----

async function load(url) {
  const response = await fetch(url);
  if (!response.ok) throw new Error(url + ": " + response.status);
  let bytes = new Uint8Array(await response.arrayBuffer());
  // a server may have undone the gzip already
  if (bytes[0] === 0x1f && bytes[1] === 0x8b) {
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("gzip"));
    bytes = new Uint8Array(await new Response(stream).arrayBuffer());
  }
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const headLength = view.getUint32(4, true);
  const head = JSON.parse(new TextDecoder().decode(bytes.subarray(8, 8 + headLength)));
  let at = 8 + headLength;
  at += (4 - (at % 4)) % 4;
  const sections = head.sections.map((size) => {
    const section = bytes.subarray(at, at + size);
    at += size;
    return section;
  });
  return decode(head, sections);
}

function varints(bytes) {
  const out = [];
  let n = 0;
  let shift = 0;
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i];
    n += (b & 0x7f) * 2 ** shift;
    if (b & 0x80) {
      shift += 7;
    } else {
      out.push(n);
      n = 0;
      shift = 0;
    }
  }
  return out;
}

const unzigzag = (z) => (z % 2 ? -(z + 1) / 2 : z / 2);

function decode(head, [geometry, cellInfo, drivers, counts, wires, flips, origins]) {
  const n = head.cells;
  const g = new DataView(geometry.buffer, geometry.byteOffset, geometry.byteLength);
  const x = new Uint16Array(n), y = new Uint16Array(n), w = new Uint16Array(n), h = new Uint16Array(n);
  for (let i = 0; i < n; i++) {
    x[i] = g.getUint16(8 * i, true);
    y[i] = g.getUint16(8 * i + 2, true);
    w[i] = g.getUint16(8 * i + 4, true);
    h[i] = g.getUint16(8 * i + 6, true);
  }
  const block = cellInfo.slice(0, n);
  const c = new DataView(cellInfo.buffer, cellInfo.byteOffset + n, 2 * n);
  const master = new Uint16Array(n);
  for (let i = 0; i < n; i++) master[i] = c.getUint16(2 * i, true);

  const nets = head.nets;
  const driver = new Uint16Array(nets);
  let d = 0;
  varints(drivers).forEach((delta, i) => (driver[i] = d += delta));
  const segmentCounts = varints(counts);
  const segStart = new Uint32Array(nets + 1);
  segmentCounts.forEach((count, i) => (segStart[i + 1] = segStart[i] + count));
  const total = segStart[nets];
  const layer = new Uint8Array(total);
  const seg = new Uint16Array(4 * total);
  const v = varints(wires);
  let k = 0;
  for (let net = 0; net < nets; net++) {
    let px = 0, py = 0;
    for (let s = segStart[net]; s < segStart[net + 1]; s++) {
      layer[s] = v[k];
      const x1 = px + unzigzag(v[k + 1]);
      const y1 = py + unzigzag(v[k + 2]);
      seg[4 * s] = x1;
      seg[4 * s + 1] = y1;
      seg[4 * s + 2] = x1 + unzigzag(v[k + 3]);
      seg[4 * s + 3] = y1 + unzigzag(v[k + 4]);
      px = x1;
      py = y1;
      k += 5;
    }
  }

  const f = varints(flips);
  const cycles = head.cycles;
  const flipStart = new Uint32Array(cycles + 1);
  const flip = new Uint16Array(f.length);
  let m = 0;
  let p = 0;
  for (let cycle = 0; cycle < cycles; cycle++) {
    const count = f[p++];
    flipStart[cycle] = m;
    let net = -1;
    for (let i = 0; i < count; i++) flip[m++] = net += f[p++] + 1;
  }
  flipStart[cycles] = m;
  // an index into head.sources, the top bit set when it is only the nearest named cell's
  const origin = new Uint16Array(n).fill(NONE);
  if (origins) {
    const o = new DataView(origins.buffer, origins.byteOffset, origins.byteLength);
    for (let i = 0; i < n; i++) origin[i] = o.getUint16(2 * i, true);
  }
  return { head, x, y, w, h, block, master, driver, segStart, layer, seg, flipStart, flip, origin };
}

// ---- colours ----

function hex(colour) {
  const v = parseInt(colour.slice(1), 16);
  return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}
const mix = (a, b, t) => a.map((v, i) => Math.round(v + (b[i] - v) * t));
const rgba = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a})`;

function palette(dark, blocks) {
  const white = [255, 255, 255];
  const black = [0, 0, 0];
  const base = blocks.map(([, colour]) => hex(colour));
  return dark
    ? {
        dark,
        die: "#000000",
        rows: "rgba(255,255,255,0.025)",
        cell: base.map((c) => rgba(mix(c, white, 0.15), 0.34)),
        hot: base.map((c) => mix(c, white, 0.35)),
        flash: [255, 255, 255],
        wires: ["rgba(110,120,170,0.10)", "rgba(128,128,192,0.16)", "rgba(80,170,180,0.14)", "rgba(200,150,70,0.30)"],
        macro: "#1b1b1e",
        macroEdge: "#55555c",
        label: "#bdbab3",
        pin: "#77757a",
        pick: "#ffffff",
        find: [255, 96, 72],
        blend: "source-over",
      }
    : {
        dark,
        die: "#e9e7e1",
        rows: "rgba(0,0,0,0.025)",
        cell: base.map((c) => rgba(c, 0.30)),
        hot: base.map((c) => mix(c, black, 0.12)),
        flash: [20, 20, 20],
        wires: ["rgba(60,70,110,0.08)", "rgba(70,70,130,0.10)", "rgba(30,110,120,0.10)", "rgba(150,100,30,0.22)"],
        macro: "#dcdad3",
        macroEdge: "#8b8880",
        label: "#2c2b29",
        pin: "#8b8880",
        pick: "#000000",
        find: [214, 40, 24],
        blend: "source-over",
      };
}

// ---- the page ----

const state = {
  data: null,
  cycle: 0,
  playing: false,
  speed: 40,
  carry: 0,
  view: { cx: 0, cy: 0, s: 1 },
  fit: 1,
  colours: null,
  picked: -1,
  probed: null,
  query: "",
  lit: null,
  showWires: true,
  showCells: true,
  baseDirty: true,
};

const stage = $("stage");
const canvas = $("die");
const ctx = canvas.getContext("2d");
const base = document.createElement("canvas");
const baseCtx = base.getContext("2d");
const scrub = $("scrub");
const scrubCtx = scrub.getContext("2d");
let paths = null;

function isDark() {
  const theme = document.documentElement.dataset.theme;
  if (theme) return theme === "dark";
  return matchMedia("(prefers-color-scheme: dark)").matches;
}

function size(el, c) {
  const r = el.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  c.width = Math.max(1, Math.round(r.width * dpr));
  c.height = Math.max(1, Math.round(r.height * dpr));
  return { width: r.width, height: r.height, dpr };
}

// Path2Ds in die coordinates, built once: the cells of each block, the wires of each
// layer, each net's wires on demand.
function buildPaths(data) {
  const cells = data.head.blocks.map(() => new Path2D());
  for (let i = 0; i < data.head.cells; i++) {
    cells[data.block[i]].rect(data.x[i], data.y[i], data.w[i], data.h[i]);
  }
  const wires = data.head.layers.map(() => new Path2D());
  for (let s = 0; s < data.layer.length; s++) {
    const p = wires[data.layer[s]];
    p.moveTo(data.seg[4 * s], data.seg[4 * s + 1]);
    p.lineTo(data.seg[4 * s + 2], data.seg[4 * s + 3]);
  }
  const rows = new Path2D();
  const [dw, dh] = data.head.die;
  // IHP's 3.78 um rows, every other one shaded
  const row = 3780 / data.head.step_nm;
  for (let y = row; y + row <= dh - row; y += 2 * row) rows.rect(144, y, dw - 288, row);
  return { cells, wires, rows, nets: new Map() };
}

function netPath(net) {
  let p = paths.nets.get(net);
  if (p) return p;
  const d = state.data;
  p = new Path2D();
  for (let s = d.segStart[net]; s < d.segStart[net + 1]; s++) {
    p.moveTo(d.seg[4 * s], d.seg[4 * s + 1]);
    p.lineTo(d.seg[4 * s + 2], d.seg[4 * s + 3]);
  }
  paths.nets.set(net, p);
  return p;
}

function dieTransform(c, dpr) {
  const { cx, cy, s } = state.view;
  const r = canvas.getBoundingClientRect();
  c.setTransform(s * dpr, 0, 0, -s * dpr, (r.width / 2 - cx * s) * dpr, (r.height / 2 + cy * s) * dpr);
}

function toDie(clientX, clientY) {
  const r = canvas.getBoundingClientRect();
  const { cx, cy, s } = state.view;
  return [(clientX - r.left - r.width / 2) / s + cx, cy - (clientY - r.top - r.height / 2) / s];
}

function fitView() {
  const d = state.data;
  const r = canvas.getBoundingClientRect();
  const [dw, dh] = d.head.die;
  const s = Math.min(r.width / dw, r.height / dh) * 0.97;
  state.fit = s;
  state.view = { cx: dw / 2, cy: dh / 2, s };
  state.baseDirty = true;
}

function drawBase() {
  const d = state.data;
  const col = state.colours;
  const { dpr } = size(stage, base);
  const c = baseCtx;
  c.setTransform(1, 0, 0, 1, 0, 0);
  c.clearRect(0, 0, base.width, base.height);
  dieTransform(c, dpr);
  const s = state.view.s;
  const px = 1 / (s * dpr);
  const [dw, dh] = d.head.die;
  c.fillStyle = col.die;
  c.fillRect(0, 0, dw, dh);
  if (s * 189 > 6) {
    c.fillStyle = col.rows;
    c.fill(paths.rows);
  }
  if (state.showCells) {
    paths.cells.forEach((p, b) => {
      c.fillStyle = col.cell[b];
      c.fill(p);
    });
    // cell outlines once a cell is wide enough to see one
    if (s * 189 > 14) {
      c.strokeStyle = col.dark ? "rgba(0,0,0,0.8)" : "rgba(255,255,255,0.8)";
      c.lineWidth = 1.5 * px;
      paths.cells.forEach((p) => c.stroke(p));
    }
  }
  if (state.showWires) {
    c.lineCap = "square";
    // a small view packs many wires to a pixel, so each is fainter
    c.globalAlpha = Math.min(1, Math.max(0.3, s / 0.02));
    paths.wires.forEach((p, l) => {
      c.strokeStyle = col.wires[l] || col.wires[3];
      // a wire is about 0.2 um, never thinner than a pixel
      c.lineWidth = Math.max(px, 10);
      c.stroke(p);
    });
    c.globalAlpha = 1;
  }
  // the SRAM macros
  for (const [cell] of d.head.macros) {
    c.fillStyle = col.macro;
    c.fillRect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
    c.strokeStyle = col.macroEdge;
    c.lineWidth = px * 1.5;
    c.strokeRect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
  }
  // labels in screen space
  c.setTransform(dpr, 0, 0, dpr, 0, 0);
  c.fillStyle = col.label;
  c.textAlign = "center";
  c.textBaseline = "middle";
  const fontSize = Math.max(10, Math.min(15, s * 900));
  c.font = `${fontSize}px system-ui, sans-serif`;
  for (const [cell, name] of d.head.macros) {
    const [sx, sy] = toScreen(d.x[cell] + d.w[cell] / 2, d.y[cell] + d.h[cell] / 2);
    const engine = name.match(/engine_(\d)/);
    const lines = engine ? ["program SRAM", "engine " + engine[1]] : ["data SRAM", "shared"];
    lines.forEach((line, i) => c.fillText(line, sx, sy + (i - 0.5) * fontSize * 1.35));
  }
  // master names once cells are big enough to hold them
  if (s * 189 > 26 && state.showCells) {
    c.font = `${Math.min(12, s * 60)}px ui-monospace, monospace`;
    c.fillStyle = col.dark ? "rgba(255,255,255,0.55)" : "rgba(0,0,0,0.6)";
    const [x0, y1] = toDie(canvas.getBoundingClientRect().left, canvas.getBoundingClientRect().top);
    const [x1, y0] = toDie(canvas.getBoundingClientRect().right, canvas.getBoundingClientRect().bottom);
    for (let i = 0; i < d.head.cells; i++) {
      if (d.x[i] + d.w[i] < x0 || d.x[i] > x1 || d.y[i] + d.h[i] < y0 || d.y[i] > y1) continue;
      if (d.w[i] * s < 34 || d.block[i] === d.head.blocks.length - 1) continue;
      const [sx, sy] = toScreen(d.x[i] + d.w[i] / 2, d.y[i] + d.h[i] / 2);
      c.fillText(d.head.masters[d.master[i]].replace(/_\d+$/, ""), sx, sy);
    }
  }
  drawPins(c, false);
  state.baseDirty = false;
}

function toScreen(x, y) {
  const r = canvas.getBoundingClientRect();
  const { cx, cy, s } = state.view;
  return [(x - cx) * s + r.width / 2, (cy - y) * s + r.height / 2];
}

// The pins sit on the top edge, each drawn as a tab, lit when it switches.
function drawPins(c, live) {
  const d = state.data;
  const col = state.colours;
  const s = state.view.s;
  for (const [, label, x, y, net] of d.head.pins) {
    const [sx, sy] = toScreen(x, y);
    const age = live ? state.ages.get(net) : undefined;
    if (live && age === undefined) continue;
    const a = live ? fade(age) : 1;
    c.fillStyle = live ? rgba(col.flash, a) : col.pin;
    const tab = Math.max(3, s * 50);
    const length = Math.max(5, s * 120);
    c.fillRect(sx - tab / 2, sy - 1, tab, length);
    if (!live && s * 192 > 9) {
      c.save();
      c.translate(sx, sy + length + 4);
      c.rotate(Math.PI / 2);
      c.textAlign = "left";
      c.font = `${Math.min(11, s * 170)}px system-ui, sans-serif`;
      c.fillStyle = col.label;
      c.fillText(label, 0, 0);
      c.restore();
    }
  }
}

// ---- what is lit ----

function fadeCycles() {
  // at speed, a frame moves several cycles, so the trail grows with it
  return Math.max(4, Math.ceil((2 * state.speed) / 60));
}

function fade(age) {
  const t = 1 - age / fadeCycles();
  return t * t;
}

// Each net that switched in the last few cycles, with how many cycles ago.
function litNets() {
  const d = state.data;
  const ages = new Map();
  const span = fadeCycles();
  for (let age = 0; age < span && state.cycle - age >= 0; age++) {
    const cycle = state.cycle - age;
    for (let i = d.flipStart[cycle]; i < d.flipStart[cycle + 1]; i++) {
      if (!ages.has(d.flip[i])) ages.set(d.flip[i], age);
    }
  }
  return ages;
}

function drawLive() {
  const d = state.data;
  const col = state.colours;
  const dpr = window.devicePixelRatio || 1;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(base, 0, 0);
  state.ages = litNets();
  const span = fadeCycles();
  const levels = Math.min(span, 8);
  const blocks = d.head.blocks.length;
  // one path per block and fade level, cells and wires apart
  const wires = [];
  const cells = [];
  for (let i = 0; i < blocks * levels; i++) {
    wires.push(new Path2D());
    cells.push(new Path2D());
  }
  const pinWires = [];
  for (let i = 0; i < levels; i++) pinWires.push(new Path2D());
  const macros = new Map();
  const s = state.view.s;
  for (const [net, age] of state.ages) {
    const level = Math.min(levels - 1, Math.floor((age * levels) / span));
    const cell = d.driver[net];
    if (cell === NONE) {
      pinWires[level].addPath(netPath(net));
      continue;
    }
    const b = d.block[cell];
    if (state.showWires) wires[b * levels + level].addPath(netPath(net));
    if (b === blocks - 1) macros.set(cell, Math.min(age, macros.has(cell) ? macros.get(cell) : age));
    else cells[b * levels + level].rect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
  }
  dieTransform(ctx, dpr);
  ctx.globalCompositeOperation = col.blend;
  const px = 1 / (s * dpr);
  ctx.lineCap = "square";
  ctx.lineWidth = Math.max(1.6 * px, 12);
  for (let b = 0; b < blocks; b++) {
    for (let l = 0; l < levels; l++) {
      const a = fade((l * span) / levels);
      ctx.strokeStyle = rgba(col.hot[b], 0.85 * a);
      ctx.stroke(wires[b * levels + l]);
      // a cell flashes white, then takes its block's colour as it fades
      ctx.fillStyle = rgba(mix(col.hot[b], col.flash, l === 0 ? 0.65 : 0.1), a);
      ctx.fill(cells[b * levels + l]);
    }
  }
  for (let l = 0; l < levels; l++) {
    ctx.strokeStyle = rgba(col.flash, 0.9 * fade((l * span) / levels));
    ctx.stroke(pinWires[l]);
  }
  // a macro whose outputs move was read: a wash, so its label still shows
  for (const [cell, age] of macros) {
    ctx.fillStyle = rgba(col.hot[blocks - 1], 0.22 * fade(age));
    ctx.fillRect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
    ctx.strokeStyle = rgba(col.flash, fade(age));
    ctx.lineWidth = 2 * px;
    ctx.strokeRect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
  }
  ctx.globalCompositeOperation = "source-over";
  // the cells of the line searched for, those it named outright the stronger
  if (state.lit) {
    ctx.fillStyle = rgba(col.find, 0.35);
    ctx.fill(state.lit.near);
    ctx.fillStyle = rgba(col.find, 0.9);
    ctx.fill(state.lit.own);
    ctx.strokeStyle = rgba(col.find, 1);
    ctx.lineWidth = 1.5 * px;
    ctx.stroke(state.lit.own);
  }
  // the probed cell and the nets it drives
  if (state.picked >= 0) {
    const cell = state.picked;
    ctx.strokeStyle = col.pick;
    ctx.lineWidth = Math.max(2 * px, 14);
    for (const net of drivenBy(cell)) ctx.stroke(netPath(net));
    ctx.lineWidth = 2.5 * px;
    ctx.strokeRect(d.x[cell], d.y[cell], d.w[cell], d.h[cell]);
  }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  drawPins(ctx, true);
}

// nets are sorted by driver, so a cell's are one run
function drivenBy(cell) {
  const d = state.data;
  let lo = 0, hi = d.head.nets;
  while (lo < hi) {
    const mid = (lo + hi) >> 1;
    if (d.driver[mid] < cell) lo = mid + 1;
    else hi = mid;
  }
  const nets = [];
  for (let n = lo; n < d.head.nets && d.driver[n] === cell; n++) nets.push(n);
  return nets;
}

// ---- the side panel ----

function frameAt(frames, cycle) {
  for (const f of frames) if (f[0] <= cycle && cycle <= f[1]) return f;
  return null;
}

function hex2(n, width) {
  return n.toString(16).padStart(width, "0");
}

function printable(byte) {
  return byte >= 32 && byte < 127 ? `'${String.fromCharCode(byte)}'` : "";
}

function updatePanel() {
  const d = state.data;
  const h = d.head;
  const cycle = state.cycle;
  $("s-cycle").textContent = `${cycle} / ${h.cycles - 1}`;
  $("s-time").textContent = `${((cycle * 20) / 1000).toFixed(2)} us at 50 MHz`;
  const spi = frameAt(h.spi, cycle);
  $("s-host").textContent = spi ? spi[2].replace(/\b([0-9a-f]{4})\b/g, (w) => {
    const v = parseInt(w, 16);
    return spi[2].startsWith("write tx") && printable(v) ? printable(v) : w;
  }) : cycle < 10 ? "reset" : "idle";
  $("s-host").title = spi ? spi[2] : "";
  const pc = h.pc[cycle];
  $("s-pc").textContent = pc === null ? "x" : `${hex2(pc, 2)}  ${h.program[pc] || ""}`;
  const out0 = h.out0[cycle];
  $("s-out0").textContent = out0 === null ? "x" : String(out0);
  const frame = frameAt(h.uart, cycle);
  if (frame) {
    const bit = Math.floor((cycle - frame[0]) / h.bit);
    const where = bit === 0 ? "start bit" : bit === 9 ? "stop bit" : `bit ${bit - 1}`;
    $("s-uart").textContent = `${printable(frame[2])} 0x${hex2(frame[2], 2)}  ${where}`;
  } else {
    const sent = h.uart.filter((f) => f[1] < cycle).length;
    $("s-uart").textContent = sent ? `idle, ${sent} of ${h.uart.length} sent` : "idle";
  }
  const switched = d.flipStart[cycle + 1] - d.flipStart[cycle];
  $("s-nets").textContent = `${switched} switched`;
  document.querySelectorAll("#program li").forEach((li, i) => li.classList.toggle("at", i === pc));
  $("play").setAttribute("aria-label", state.playing ? "Pause" : "Play");
  $("play-icon").setAttribute("d", state.playing ? "M3 2h4v12H3zm6 0h4v12H9z" : "M4 2l10 6-10 6z");
  updateProbe();
}

function updateProbe() {
  const d = state.data;
  const el = $("probe");
  if (state.probed !== state.picked) probeSource();
  if (state.picked < 0) {
    el.textContent = "";
    return;
  }
  const cell = state.picked;
  const h = d.head;
  const macro = h.macros.find(([c]) => c === cell);
  const lines = [macro ? macro[1] : h.masters[d.master[cell]], h.blocks[d.block[cell]][0]];
  const nets = drivenBy(cell);
  let last = -1;
  for (let c = state.cycle; c >= 0 && last < 0; c--) {
    for (let i = d.flipStart[c]; i < d.flipStart[c + 1]; i++) {
      if (nets.includes(d.flip[i])) {
        last = c;
        break;
      }
    }
  }
  for (const net of nets.slice(0, 4)) lines.push("drives " + (h.names[net] || "net " + net));
  if (nets.length > 4) lines.push(`and ${nets.length - 4} more nets`);
  lines.push(last < 0 ? "not switched yet" : last === state.cycle ? "switched this cycle" : `last switched at cycle ${last}`);
  el.textContent = lines.join("\n");
  el.style.whiteSpace = "pre-wrap";
}

// ---- src lines ----

function sourceOf(cell) {
  const o = state.data.origin[cell];
  return o === NONE ? null : { text: state.data.head.sources[o & 0x7fff], own: !(o & 0x8000) };
}

// the line on GitHub at the commit the run hardened, for "src/engine.ml:123"
function permalink(text) {
  const m = text.match(/^(.+):(\d+)$/);
  const run = state.data.head.run;
  return m ? `${run.repo}/blob/${run.commit}/${m[1]}#L${m[2]}` : null;
}

// The picked cell's line, with a link to it and a button that lights its cells; built
// only when the pick changes, so the link stays put while the die plays.
function probeSource() {
  state.probed = state.picked;
  const el = $("probe-src");
  el.textContent = "";
  if (state.picked < 0) return;
  const source = sourceOf(state.picked);
  if (!source) {
    el.textContent = "no src line";
    return;
  }
  const url = permalink(source.text);
  el.append(document.createTextNode(source.own ? "from " : "near "));
  if (url) {
    const a = document.createElement("a");
    a.href = url;
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = source.text;
    el.append(a);
  } else {
    el.append(document.createTextNode(source.text + ", no line on the stack"));
  }
  const light = document.createElement("button");
  light.className = "light";
  light.textContent = "light its cells";
  light.onclick = () => {
    $("find").value = source.text;
    find(source.text);
  };
  el.append(light);
}

// The sources a query names: one line as src/engine.ml:123 or engine.ml:123, else every
// line of a file or module, as engine or host_fifo, else those that contain it.
function sourcesMatching(query) {
  const sources = state.data.head.sources;
  const all = sources.map((_, i) => i);
  const q = query.trim().toLowerCase().replace(/^src\//, "");
  if (!q) return [];
  const line = q.match(/^(.+?)(?:\.ml)?:(\d+)$/);
  if (line) return all.filter((i) => sources[i] === `src/${line[1]}.ml:${line[2]}`);
  const name = q.replace(/\.ml$/, "");
  const named = all.filter((i) => sources[i] === name || sources[i].startsWith(`src/${name}.ml:`));
  return named.length ? named : all.filter((i) => sources[i].includes(q));
}

function find(query) {
  const d = state.data;
  state.query = query.trim();
  const hits = new Set(sourcesMatching(query));
  let owned = 0, near = 0;
  state.lit = hits.size ? { own: new Path2D(), near: new Path2D() } : null;
  for (let i = 0; hits.size && i < d.head.cells; i++) {
    const o = d.origin[i];
    if (o === NONE || !hits.has(o & 0x7fff)) continue;
    if (o & 0x8000) {
      near++;
      state.lit.near.rect(d.x[i], d.y[i], d.w[i], d.h[i]);
    } else {
      owned++;
      state.lit.own.rect(d.x[i], d.y[i], d.w[i], d.h[i]);
    }
  }
  const lines = hits.size === 1 ? "1 line" : `${hits.size} lines`;
  $("found").textContent = !state.query
    ? ""
    : hits.size
      ? `${(owned + near).toLocaleString("en")} cells from ${lines}, ${owned.toLocaleString("en")} by a name of their own`
      : "no cell comes from that";
  render();
}

function buildPanel() {
  const h = state.data.head;
  const program = $("program");
  h.program.forEach((line, i) => {
    const li = document.createElement("li");
    const addr = document.createElement("span");
    addr.textContent = hex2(i, 2);
    li.append(addr, document.createTextNode(line));
    program.append(li);
  });
  const counts = new Array(h.blocks.length).fill(0);
  for (let i = 0; i < h.cells; i++) counts[state.data.block[i]]++;
  const legend = $("legend");
  h.blocks.forEach(([name, colour], b) => {
    const li = document.createElement("li");
    const swatch = document.createElement("i");
    swatch.style.background = colour;
    const count = document.createElement("span");
    count.textContent = counts[b].toLocaleString("en");
    li.append(swatch, document.createTextNode(name), count);
    legend.append(li);
  });
  const list = $("lines");
  for (const source of h.sources || []) {
    const option = document.createElement("option");
    option.value = source;
    list.append(option);
  }
  $("find").disabled = !h.sources;
  const run = h.run.workflow_url;
  $("stamp").innerHTML = "";
  const link = document.createElement("a");
  link.href = run;
  link.textContent = "gds run " + run.split("/").pop();
  $("stamp").append(
    link,
    document.createTextNode(
      `, commit ${h.run.commit.slice(0, 7)}. ${h.cells.toLocaleString("en")} cells, ` +
        `${h.nets.toLocaleString("en")} nets, ${h.cycles.toLocaleString("en")} cycles.`,
    ),
  );
}

// ---- the scrubber ----

function drawScrub() {
  const d = state.data;
  const h = d.head;
  const { width, height, dpr } = size(scrub, scrub);
  const c = scrubCtx;
  const style = getComputedStyle(document.documentElement);
  const text = style.getPropertyValue("--text").trim();
  const muted = style.getPropertyValue("--muted").trim();
  const line = style.getPropertyValue("--line").trim();
  const accent = style.getPropertyValue("--accent").trim();
  c.setTransform(dpr, 0, 0, dpr, 0, 0);
  c.clearRect(0, 0, width, height);
  const x = (cycle) => (cycle / (h.cycles - 1)) * width;
  c.font = "11px system-ui, sans-serif";
  c.textBaseline = "middle";

  // nets switched each cycle, the busiest cycle of each pixel, on a square root scale
  const top = 2, lane = 22;
  c.fillStyle = muted;
  for (let px = 0; px < width; px++) {
    const from = Math.floor((px / width) * h.cycles);
    const to = Math.max(from + 1, Math.floor(((px + 1) / width) * h.cycles));
    let most = 0;
    for (let cycle = from; cycle < to && cycle < h.cycles; cycle++) {
      most = Math.max(most, d.flipStart[cycle + 1] - d.flipStart[cycle]);
    }
    const bar = Math.min(1, Math.sqrt(most / 1500)) * lane;
    c.fillRect(px, top + lane - bar, 1, bar);
  }

  // the host's SPI frames
  const spiY = top + lane + 5;
  for (const [a, b, what] of h.spi) {
    c.fillStyle = what.startsWith("write tx") ? accent : line;
    c.fillRect(x(a), spiY, Math.max(1, x(b) - x(a)), 10);
  }
  c.fillStyle = muted;
  c.textAlign = "left";
  const phases = [];
  for (const [a, , what] of h.spi) {
    const name = what.replace(/^(write|read) /, "").replace(/ [0-9a-f ]+$/, "").replace(/ \d+$/, "");
    if (!phases.length || phases[phases.length - 1][1] !== name) phases.push([a, name]);
  }
  phases.forEach(([a, name], i) => {
    const next = i + 1 < phases.length ? x(phases[i + 1][0]) : width;
    if (next - x(a) > c.measureText(name).width + 8) c.fillText(name, x(a) + 2, spiY + 18);
  });

  // OUT0, with the bytes it carries
  const outY = spiY + 30, high = 12;
  c.strokeStyle = text;
  c.lineWidth = 1;
  c.beginPath();
  let previous = null;
  for (let px = 0; px < width; px++) {
    const cycle = Math.min(h.cycles - 1, Math.floor((px / width) * h.cycles));
    const v = h.out0[cycle];
    const yv = v === 1 ? outY : outY + high;
    if (previous === null) c.moveTo(px, yv);
    else c.lineTo(px, yv);
    previous = v;
  }
  c.stroke();
  c.fillStyle = text;
  c.textAlign = "center";
  for (const [a, b, byte] of h.uart) {
    if (x(b) - x(a) > 10) c.fillText(String.fromCharCode(byte), (x(a) + x(b)) / 2, outY + high + 10);
  }
  c.textAlign = "left";
  c.fillStyle = muted;
  c.fillText("OUT0", 2, outY + high / 2);

  // the cycle shown
  const at = x(state.cycle);
  c.fillStyle = accent;
  c.fillRect(Math.round(at) - 1, 0, 2, height);
}

function scrubTo(clientX) {
  const r = scrub.getBoundingClientRect();
  const t = Math.min(1, Math.max(0, (clientX - r.left) / r.width));
  setCycle(Math.round(t * (state.data.head.cycles - 1)));
}

// ---- running ----

function setCycle(cycle) {
  state.cycle = Math.max(0, Math.min(state.data.head.cycles - 1, cycle));
  state.carry = 0;
  render();
}

let lastFrame = 0;
let pending = false;
function render() {
  if (pending) return;
  pending = true;
  requestAnimationFrame(frame);
}

function frame(now) {
  pending = false;
  if (!state.data) return;
  if (state.playing) {
    const dt = lastFrame ? Math.min(0.1, (now - lastFrame) / 1000) : 0;
    state.carry += dt * state.speed;
    const steps = Math.floor(state.carry);
    state.carry -= steps;
    if (state.cycle + steps >= state.data.head.cycles - 1) {
      state.cycle = state.data.head.cycles - 1;
      state.playing = false;
    } else {
      state.cycle += steps;
    }
    lastFrame = now;
  } else {
    lastFrame = 0;
  }
  if (state.baseDirty) drawBase();
  drawLive();
  drawScrub();
  updatePanel();
  writeHash();
  if (state.playing) render();
}

function play(on) {
  state.playing = on;
  if (on && state.cycle >= state.data.head.cycles - 1) state.cycle = 0;
  lastFrame = 0;
  render();
}

// the cycle and view in the address, so a moment can be linked
function writeHash() {
  if (state.playing) return;
  const { cx, cy, s } = state.view;
  const zoom = s / state.fit;
  let hash = `cycle=${state.cycle}`;
  if (zoom > 1.01) hash += `&zoom=${zoom.toFixed(2)}&x=${Math.round(cx)}&y=${Math.round(cy)}`;
  if (state.picked >= 0) hash += `&pick=${state.picked}`;
  if (state.query) hash += `&find=${encodeURIComponent(state.query)}`;
  if (location.hash.slice(1) !== hash) history.replaceState(null, "", "#" + hash);
}

function readHash() {
  const params = new URLSearchParams(location.hash.slice(1));
  if (params.has("theme")) document.documentElement.dataset.theme = params.get("theme");
  if (params.has("cycle")) state.cycle = Math.max(0, Math.min(state.data.head.cycles - 1, +params.get("cycle")));
  if (params.has("zoom")) {
    state.view.s = state.fit * +params.get("zoom");
    if (params.has("x")) state.view.cx = +params.get("x");
    if (params.has("y")) state.view.cy = +params.get("y");
  }
  if (params.has("pick")) state.picked = +params.get("pick");
  return params;
}

// ---- input ----

function zoomAt(factor, clientX, clientY) {
  const [wx, wy] = toDie(clientX, clientY);
  const s = Math.min(state.fit * 400, Math.max(state.fit * 0.8, state.view.s * factor));
  const r = canvas.getBoundingClientRect();
  state.view = {
    s,
    cx: wx - (clientX - r.left - r.width / 2) / s,
    cy: wy + (clientY - r.top - r.height / 2) / s,
  };
  state.baseDirty = true;
  render();
}

function zoomCentre(factor) {
  const r = canvas.getBoundingClientRect();
  zoomAt(factor, r.left + r.width / 2, r.top + r.height / 2);
}

function cellAt(clientX, clientY) {
  const d = state.data;
  const [wx, wy] = toDie(clientX, clientY);
  // a pixel's slack around thin cells
  const slack = 2 / state.view.s;
  let best = -1, area = Infinity;
  for (let i = 0; i < d.head.cells; i++) {
    if (wx >= d.x[i] - slack && wx <= d.x[i] + d.w[i] + slack && wy >= d.y[i] - slack && wy <= d.y[i] + d.h[i] + slack) {
      const a = d.w[i] * d.h[i];
      if (a < area) {
        best = i;
        area = a;
      }
    }
  }
  return best;
}

function pick(clientX, clientY) {
  state.picked = cellAt(clientX, clientY);
  render();
}

// a mouse over a cell names it and its line, at most once a frame
let hovered = null;
function hover(e) {
  if (!hovered) requestAnimationFrame(showTip);
  hovered = e;
}

function showTip() {
  const e = hovered;
  hovered = null;
  const tip = $("tip");
  const cell = e.pointerType === "mouse" && !e.buttons ? cellAt(e.clientX, e.clientY) : -1;
  if (cell < 0) {
    tip.hidden = true;
    return;
  }
  const h = state.data.head;
  const macro = h.macros.find(([c]) => c === cell);
  const source = sourceOf(cell);
  tip.textContent =
    (macro ? macro[1] : h.masters[state.data.master[cell]]) +
    "\n" +
    (source ? (source.own ? "" : "near ") + source.text : "no src line");
  tip.hidden = false;
  const r = stage.getBoundingClientRect();
  let x = e.clientX - r.left + 14;
  let y = e.clientY - r.top + 14;
  if (x + tip.offsetWidth > r.width - 4) x = e.clientX - r.left - tip.offsetWidth - 10;
  if (y + tip.offsetHeight > r.height - 4) y = e.clientY - r.top - tip.offsetHeight - 10;
  tip.style.transform = `translate(${Math.max(4, x)}px, ${Math.max(4, y)}px)`;
}

function wireInput() {
  const pointers = new Map();
  let dragged = false;
  let pinch = null;
  stage.addEventListener("pointerdown", (e) => {
    if (e.target.closest("button")) return;
    stage.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, [e.clientX, e.clientY]);
    dragged = false;
    if (pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      pinch = Math.hypot(a[0] - b[0], a[1] - b[1]);
    }
    stage.classList.add("dragging");
  });
  stage.addEventListener("pointermove", (e) => {
    const last = pointers.get(e.pointerId);
    if (!last) return;
    const dx = e.clientX - last[0];
    const dy = e.clientY - last[1];
    pointers.set(e.pointerId, [e.clientX, e.clientY]);
    if (pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      const distance = Math.hypot(a[0] - b[0], a[1] - b[1]);
      if (pinch) zoomAt(distance / pinch, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2);
      pinch = distance;
      dragged = true;
      return;
    }
    if (Math.abs(dx) + Math.abs(dy) > 0) {
      if (Math.abs(dx) + Math.abs(dy) > 2) dragged = true;
      state.view.cx -= dx / state.view.s;
      state.view.cy += dy / state.view.s;
      state.baseDirty = true;
      render();
    }
  });
  stage.addEventListener("pointermove", hover);
  stage.addEventListener("pointerleave", () => ($("tip").hidden = true));
  const up = (e) => {
    if (pointers.size === 1 && !dragged) pick(e.clientX, e.clientY);
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinch = null;
    if (!pointers.size) stage.classList.remove("dragging");
  };
  stage.addEventListener("pointerup", up);
  stage.addEventListener("pointercancel", (e) => {
    pointers.delete(e.pointerId);
    stage.classList.remove("dragging");
  });
  stage.addEventListener(
    "wheel",
    (e) => {
      e.preventDefault();
      zoomAt(Math.exp(-e.deltaY * (e.deltaMode ? 0.05 : 0.0015)), e.clientX, e.clientY);
    },
    { passive: false },
  );

  let scrubbing = false;
  scrub.addEventListener("pointerdown", (e) => {
    scrubbing = true;
    scrub.setPointerCapture(e.pointerId);
    state.playing = false;
    scrubTo(e.clientX);
  });
  scrub.addEventListener("pointermove", (e) => scrubbing && scrubTo(e.clientX));
  scrub.addEventListener("pointerup", () => (scrubbing = false));

  $("play").onclick = () => play(!state.playing);
  $("step").onclick = () => {
    state.playing = false;
    setCycle(state.cycle + 1);
  };
  $("back").onclick = () => {
    state.playing = false;
    setCycle(state.cycle - 1);
  };
  $("first").onclick = () => {
    state.playing = false;
    setCycle(0);
  };
  $("speed").onchange = (e) => {
    state.speed = +e.target.value;
    render();
  };
  $("zoom-in").onclick = () => zoomCentre(1.6);
  $("zoom-out").onclick = () => zoomCentre(1 / 1.6);
  $("zoom-fit").onclick = () => {
    fitView();
    render();
  };
  $("show-wires").onchange = (e) => {
    state.showWires = e.target.checked;
    state.baseDirty = true;
    render();
  };
  $("show-cells").onchange = (e) => {
    state.showCells = e.target.checked;
    state.baseDirty = true;
    render();
  };
  $("find").addEventListener("input", (e) => find(e.target.value));
  $("find").addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      e.target.value = "";
      find("");
    }
  });
  $("theme").onclick = () => {
    const next = isDark() ? "light" : "dark";
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem("die-theme", next);
    } catch (_) {}
    retheme();
  };
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", retheme);

  // visual6502's keys: z and x zoom, n steps
  document.addEventListener("keydown", (e) => {
    if (e.target.closest("select, input") || e.metaKey || e.ctrlKey || e.altKey) return;
    const step = e.shiftKey ? 16 : 1;
    const keys = {
      " ": () => play(!state.playing),
      ArrowRight: () => setCycle(state.cycle + step),
      n: () => setCycle(state.cycle + step),
      ArrowLeft: () => setCycle(state.cycle - step),
      Home: () => setCycle(0),
      End: () => setCycle(state.data.head.cycles - 1),
      z: () => zoomCentre(1.25),
      x: () => zoomCentre(0.8),
      "0": () => {
        fitView();
        render();
      },
    };
    const action = keys[e.key];
    if (!action) return;
    e.preventDefault();
    if (e.key !== " " && e.key !== "z" && e.key !== "x" && e.key !== "0") state.playing = false;
    action();
  });

  new ResizeObserver(() => {
    const zoom = state.view.s / state.fit;
    const { cx, cy } = state.view;
    fitView();
    if (zoom > 1.01) state.view = { cx, cy, s: state.fit * zoom };
    size(stage, canvas);
    render();
  }).observe(stage);
}

function retheme() {
  state.colours = palette(isDark(), state.data.head.blocks);
  state.baseDirty = true;
  render();
}

async function main() {
  try {
    const theme = localStorage.getItem("die-theme");
    if (theme) document.documentElement.dataset.theme = theme;
  } catch (_) {}
  let data;
  try {
    data = await load("die.bin");
  } catch (error) {
    $("loading").textContent = "Could not load die.bin: " + error.message;
    return;
  }
  state.data = data;
  paths = buildPaths(data);
  size(stage, canvas);
  fitView();
  const params = readHash();
  state.colours = palette(isDark(), data.head.blocks);
  buildPanel();
  if (params.has("find") && data.head.sources) {
    $("find").value = params.get("find");
    find(params.get("find"));
  }
  wireInput();
  $("loading").remove();
  // a first visit starts as the host starts the engine
  if (!params.has("cycle")) {
    const start = data.head.spi.find((f) => f[2].startsWith("write control"));
    state.cycle = start ? start[0] : 0;
  }
  if (params.has("play") || !params.has("cycle")) play(true);
  else render();
}

main();
