#!/usr/bin/env python3
"""Bundle html/style.css, html/app.js and the chat markup into one preview page."""
import re, pathlib, sys

root = pathlib.Path(__file__).resolve().parent.parent
css = (root / 'html' / 'style.css').read_text()
app = (root / 'html' / 'app.js').read_text()
index = (root / 'html' / 'index.html').read_text()

m = re.search(r'(<div id="chat".*?</div>\s*)\n\s*<script src="app\.js">', index, re.S)
if not m:
    sys.exit('could not find the chat markup in index.html')
chat_markup = m.group(1)

shell = (root / 'preview' / 'shell.html').read_text()
out = (shell
       .replace('/*{{CSS}}*/', css)
       .replace('<!--{{CHAT}}-->', chat_markup)
       .replace('/*{{APP}}*/', app))

dest = pathlib.Path('/mnt/user-data/outputs/nx-chat-preview.html')
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(out)
print(f'{dest} — {len(out)/1024:.1f} KB')
