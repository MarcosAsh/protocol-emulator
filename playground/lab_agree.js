// Each of test/lab's jobs through the page's labCheck, file by file against the folder
// generate.exe lab wrote beside it, so the page and the bench's worker check alike.
const fs = require("fs");
const path = require("path");
const [bundle, dir] = process.argv.slice(2);
const pe = require(path.resolve(bundle)).protocolEmulator;
let differ = 0;
for (const job of fs.readdirSync(dir).filter((f) => f.endsWith(".job.json")).sort()) {
  const folder = path.join(dir, job.slice(0, -".job.json".length));
  const files = Array.from(pe.labCheck(fs.readFileSync(path.join(dir, job), "utf8")), (f) => Array.from(f));
  const names = files.map(([name]) => name).sort();
  const want = fs.readdirSync(folder).sort();
  if (names.join() !== want.join()) {
    console.log(`${job}: the page writes ${names.join(" ")}, the folder has ${want.join(" ")}`);
    differ++;
  }
  for (const [name, text] of files) {
    const file = path.join(folder, name);
    if (fs.existsSync(file) && fs.readFileSync(file, "utf8") !== text) {
      console.log(`${job}: ${name} differs`);
      differ++;
    }
  }
}
process.exit(differ ? 1 : 0);
