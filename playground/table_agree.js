// Prints each timing table the page offers, at 48 and 50 MHz, through the page, in the
// format table_reference.exe prints the native build's.
const path = require("path");
const pe = require(path.resolve(process.argv[2])).protocolEmulator;
const out = [];
pe.tableExamples.forEach(([name, , table]) => {
  [48000000, 50000000].forEach((clockHz) => {
    const r = pe.timingTable(table, clockHz);
    out.push(
      `== ${name} at ${clockHz} Hz\n` +
        `verdict: ${r.verdict}\n` +
        `detail:\n${r.detail}\n` +
        `limits:\n${r.limits}\n` +
        `source:\n${r.source}\n` +
        `listing:\n${r.listing}\n` +
        `rows:\n${r.rows}\n` +
        `host:\n${r.host}\n`,
    );
  });
});
process.stdout.write(out.join(""));
