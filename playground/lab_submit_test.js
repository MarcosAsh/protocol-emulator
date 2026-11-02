// lab.html's submit block (between its lab-submit markers): the pre-filled link, the
// result comment and the issue states, with a fake GitHub.
const fs = require("fs");
const assert = require("assert");
const html = fs.readFileSync(process.argv[2], "utf8");
const code = /\/\/ lab-submit begin\n([\s\S]*?)\/\/ lab-submit end/.exec(html)[1];
const { issueUrl, blankFormUrl, resultOf, fetchAnswer } = new Function(
  code + "; return { issueUrl, blankFormUrl, resultOf, fetchAnswer };")();

const job = JSON.stringify({ lab: 1, diagram: '{"signal":[{"name":"a","wave":"01"}]}', frames: "01", decode: "none" });
const url = new URL(issueUrl("uart tx", job));
assert.strictEqual(url.pathname, "/MarcosAsh/protocol-emulator/issues/new");
assert.strictEqual(url.searchParams.get("template"), "lab.yml");
assert.strictEqual(url.searchParams.get("title"), "lab: uart tx");
assert.strictEqual(url.searchParams.get("job"), job);
assert.strictEqual(issueUrl("big", "x".repeat(7000)), null);
assert.ok(blankFormUrl().endsWith("template=lab.yml"));

const sealed = { ref: "issue#7", verdict: "certified", backend: "bench", commit: "abc", match: { verdict: "matches" }, files: {}, public: ["result.json"] };
const comment = (r) => ({ body: "<!-- lab-result v1 -->\r\nCertified.\r\n\r\n```json\r\n" + JSON.stringify(r, null, 1) + "\r\n```\r\n\r\n[evidence](x)" });
assert.deepStrictEqual(resultOf([{ body: "hello" }, comment(sealed)]), sealed);
assert.strictEqual(resultOf([{ body: "hello" }]), null);
assert.strictEqual(resultOf([{ body: "no marker\n```json\n{}\n```" }]), null);
assert.strictEqual(resultOf([{ body: "<!-- lab-result v1 -->\n```json\n{bad\n```" }]), null);
const refused = { ...sealed, verdict: "refused", why: "too long" };
assert.strictEqual(resultOf([comment(refused)]).verdict, "refused");

const reply = (status, body) => ({ status, ok: status < 300, json: async () => body });
const fake = (routes) => async (u) => routes[u.replace("https://api.github.com/repos/MarcosAsh/protocol-emulator/issues/", "")] || reply(404, {});
(async () => {
  const lab = reply(200, { labels: [{ name: "lab" }] });
  const states = async (routes) => (await fetchAnswer(7, fake(routes))).state;
  assert.strictEqual(await states({ 7: lab, "7/comments?per_page=100": reply(200, [{ body: "x" }]) }), "queued");
  const done = await fetchAnswer(7, fake({ 7: lab, "7/comments?per_page=100": reply(200, [comment(sealed)]) }));
  assert.strictEqual(done.state, "answered");
  assert.strictEqual(done.result.verdict, "certified");
  assert.strictEqual(await states({ 7: reply(200, { labels: [{ name: "bug" }] }) }), "not-lab");
  assert.strictEqual(await states({ 7: reply(200, { labels: [{ name: "lab" }], pull_request: {} }) }), "not-lab");
  assert.strictEqual(await states({}), "missing");
  assert.strictEqual(await states({ 7: reply(403, {}) }), "limited");
  assert.strictEqual(await states({ 7: lab, "7/comments?per_page=100": reply(403, {}) }), "limited");
  assert.strictEqual(await states({ 7: reply(500, {}) }), "error");
  console.log("lab_submit ok");
})();
