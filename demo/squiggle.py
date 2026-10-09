# SPDX-License-Identifier: Apache-2.0
# What the editor shows for Act 1: test/uart.ml with tx16's [out pins, 1] given a
# delay, sent to ocamllsp as an unsaved buffer, so nothing on disk breaks. Prints each
# diagnostic as the compiler would. Fails on any outside the literal, such as no config.
# Usage: dune build @check, then python3 demo/squiggle.py [--delay 13]
import argparse
import json
import os
import signal
import subprocess
import sys

FILE = "test/uart.ml"


def late_buffer(delay):
    lines = open(FILE).read().split("\n")
    start = lines.index("let tx16 =")
    end = lines.index("|}]", start)
    out = lines.index("    out pins, 1", start)
    lines[out] += " [%d]" % delay
    return "\n".join(lines), start, end


def diagnostics(text):
    lsp = subprocess.Popen(["ocamllsp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def send(message):
        body = json.dumps(dict(message, jsonrpc="2.0")).encode()
        lsp.stdin.write(b"Content-Length: %d\r\n\r\n%s" % (len(body), body))
        lsp.stdin.flush()

    def receive():
        length = None
        while (line := lsp.stdout.readline().strip()):
            name, value = line.split(b":", 1)
            if name.lower() == b"content-length":
                length = int(value)
        return json.loads(lsp.stdout.read(length))

    uri = "file://" + os.path.abspath(FILE)
    capabilities = {"textDocument": {"publishDiagnostics": {"relatedInformation": True}}}
    send({"id": 1, "method": "initialize",
          "params": {"processId": os.getpid(), "rootUri": "file://" + os.getcwd(),
                     "capabilities": capabilities}})
    while receive().get("id") != 1:
        pass
    send({"method": "initialized", "params": {}})
    send({"method": "textDocument/didOpen",
          "params": {"textDocument": {"uri": uri, "languageId": "ocaml", "version": 1,
                                      "text": text}}})
    while True:
        message = receive()
        if (message.get("method") == "textDocument/publishDiagnostics"
                and message["params"]["uri"] == uri):
            lsp.kill()
            return message["params"]["diagnostics"]


def show(lines, at, message):
    line, first, last = at["start"]["line"], at["start"]["character"], at["end"]["character"]
    print('File "%s", line %d, characters %d-%d:' % (FILE, line + 1, first, last))
    print("%3d | %s" % (line + 1, lines[line]))
    print("      " + " " * first + "^" * max(1, last - first))
    print(" ".join(message.split()))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--delay", type=int, default=13, help="12 passes, 13 is one late")
    args = parser.parse_args()
    signal.alarm(120)
    text, start, end = late_buffer(args.delay)
    lines = text.split("\n")
    found = diagnostics(text)
    for d in found:
        show(lines, d["range"], d["message"])
        for related in d.get("relatedInformation") or []:
            show(lines, related["location"]["range"], related["message"])
    if not found:
        print("builds")
    if any(not start <= d["range"]["start"]["line"] <= end for d in found):
        sys.exit("a diagnostic outside tx16: the editor would not show the squiggle")


if __name__ == "__main__":
    main()
