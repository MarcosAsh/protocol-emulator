// Each library firmware through the page and generate.exe, each diagram through the page
// and a native build, into native.txt and browser.txt to be diffed. A refusal never
// matches, as the page gives its verdict and detail where the cli gives its stderr.
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const [bundle, generate, corpus] = process.argv.slice(2);
const pe = require(path.resolve(bundle)).protocolEmulator;
const { firmware, diagrams } = JSON.parse(fs.readFileSync(corpus, "utf8"));

// the cli reads a file, and node's stdin for a child is a socket
const sources = fs.mkdtempSync(path.join(os.tmpdir(), "agree-"));
const native = firmware.map((f) => {
  const file = path.join(sources, `${f.name}.asm`);
  fs.writeFileSync(file, f.source);
  const assemble = (flag) =>
    spawnSync(path.resolve(generate), ["assemble", flag, ...f.flags, file], {
      encoding: "utf8",
    });
  const listing = assemble("-listing");
  const rows = assemble("-rows");
  return `== firmware ${f.name}\n${listing.stdout}${rows.stdout}${rows.stderr}exit ${rows.status}\n`;
});
fs.rmSync(sources, { recursive: true });
const browser = firmware.map((f) => {
  const r = pe.checkConfigured(f.source, f.config, f.period, f.periodFloor, f.singleCaptureEdge);
  const out =
    r.verdict === "accepted"
      ? `${r.listing}\n${r.rows}\n${r.detail}\nexit 0\n`
      : `${r.verdict}\n${r.detail}\nexit 1\n`;
  return `== firmware ${f.name}\n${out}`;
});

// as reference.ml writes the native report
diagrams.forEach((d) => {
  const header = `== diagram ${d.name} at ${d.clockHz} Hz\n`;
  const r = pe.runDiagram(d.source, d.frames, d.clockHz);
  native.push(header + d.native);
  browser.push(
    header +
      `verdict: ${r.verdict}\n` +
      `detail:\n${r.detail}\n` +
      `steps:\n${r.steps}\n` +
      `words: ${r.words}\n` +
      `lanes: ${r.lanes.join(" ")}\n` +
      `levels: ${r.levels.join(",")}\n` +
      `cycle ns: ${r.cycleNs.toFixed(6)}\n`,
  );
});

fs.writeFileSync("native.txt", native.join(""));
fs.writeFileSync("browser.txt", browser.join(""));
console.log(`${firmware.length} firmware, ${diagrams.length} diagram clocks`);
