# The site at marcosash.github.io/protocol-emulator, built by pages.yaml.
project = "protocol-emulator"
copyright = "2026, Marcos Ashton Iglesias"
author = "Marcos Ashton Iglesias"

extensions = ["myst_parser", "sphinx_copybutton"]

source_suffix = {".md": "markdown"}
root_doc = "index"
# info.md is Tiny Tapeout's datasheet, rendered through datasheet.md
exclude_patterns = ["_build", "info.md"]
myst_heading_anchors = 3

html_theme = "sphinx_book_theme"
templates_path = ["_templates"]
html_title = "protocol-emulator"
html_theme_options = {
    "show_toc_level": 2,
    "repository_url": "https://github.com/MarcosAsh/protocol-emulator",
    "use_repository_button": True,
    "navigation_with_keys": False,
}
