# SPDX-License-Identifier: Apache-2.0
# The visible text of an HTML page, a block a line, for demo/intake.sh's text kind.
# Usage: python3 demo/html_text.py PAGE.html > PAGE.txt
import html.parser
import re
import sys

BLOCKS = {"p", "br", "div", "tr", "li", "h1", "h2", "h3", "h4", "table", "pre"}


class Text(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.out = []
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        if tag in ("script", "style"):
            self.hidden += 1
        if tag in BLOCKS:
            self.out.append("\n")
        if tag in ("td", "th"):
            self.out.append("\t")

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.hidden -= 1

    def handle_data(self, data):
        if not self.hidden:
            self.out.append(data)


def main():
    parser = Text()
    with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
        parser.feed(f.read())
    lines = [
        re.sub(r"[ \t]+", " ", line).strip()
        for line in "".join(parser.out).splitlines()
    ]
    sys.stdout.write("\n".join(line for line in lines if line) + "\n")


if __name__ == "__main__":
    main()
