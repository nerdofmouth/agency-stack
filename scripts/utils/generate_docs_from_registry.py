#!/usr/bin/env python3
import json
from collections import defaultdict
from pathlib import Path

REGISTRY_PATH = Path("config/registry/component_registry.json")
DOCS_MD_PATH = Path("docs/index.md")
DOCS_HTML_PATH = Path("docs/index.html")

# Load registry
with REGISTRY_PATH.open() as f:
    registry = json.load(f)

components = registry.get("components", {})

# Flatten all components into a list
flat_components = []
for section in components.values():
    for comp_id, comp in section.items():
        flat_components.append(comp)

# Group by category
categories = defaultdict(list)
for comp in flat_components:
    categories[comp.get("category", "Other")].append(comp)

# Generate Markdown table for index.md
md_lines = [
    "## Component List (Auto-Generated from Registry)\n",
    "| Name | Category | Version | Status | Docs |",
    "|------|----------|---------|--------|------|",
]
for cat, comps in sorted(categories.items()):
    for comp in sorted(comps, key=lambda c: c["name"].lower()):
        status = "Installed" if comp.get("integration_status", {}).get("installed") else "Not Installed"
        doc_path = comp.get("doc", "-")
        doc_link = f"[{comp['name']}]({doc_path})" if doc_path != "-" else comp['name']
        md_lines.append(f"| {doc_link} | {cat} | {comp.get('version', '-') } | {status} | {doc_path if doc_path != '-' else ''} |")

# Insert or update the generated section in docs/index.md
md = DOCS_MD_PATH.read_text()
start = md.find("## Component List (Auto-Generated from Registry)")
end = md.find("## ", start+1)
if start != -1:
    # Replace existing
    pre = md[:start]
    post = md[end:] if end != -1 else ""
    new_md = pre + "\n" + "\n".join(md_lines) + "\n" + post
else:
    # Append at end
    new_md = md + "\n" + "\n".join(md_lines) + "\n"
DOCS_MD_PATH.write_text(new_md)

# Generate HTML list for index.html
html_lines = [
    '<div class="section">',
    '  <h2>Component List (Auto-Generated)</h2>',
    '  <table class="table table-striped">',
    '    <thead><tr><th>Name</th><th>Category</th><th>Version</th><th>Status</th><th>Docs</th></tr></thead>',
    '    <tbody>',
]
for cat, comps in sorted(categories.items()):
    for comp in sorted(comps, key=lambda c: c["name"].lower()):
        status = "<span class='text-success'>Installed</span>" if comp.get("integration_status", {}).get("installed") else "<span class='text-danger'>Not Installed</span>"
        doc_path = comp.get("doc", "-")
        doc_link = f'<a href="{doc_path}">{comp["name"]}</a>' if doc_path != "-" else comp["name"]
        html_lines.append(f'      <tr><td>{doc_link}</td><td>{cat}</td><td>{comp.get("version", "-")}</td><td>{status}</td><td>{doc_path if doc_path != '-' else ''}</td></tr>')
html_lines += [
    '    </tbody>',
    '  </table>',
    '</div>'
]

# Insert or update the generated section in docs/index.html
html = DOCS_HTML_PATH.read_text()
start = html.find("<h2>Component List (Auto-Generated)")
end = html.find("</div>", start+1)
if start != -1:
    # Replace existing
    pre = html[:start]
    post = html[end+6:] if end != -1 else ""
    new_html = pre + "\n" + "\n".join(html_lines) + "\n" + post
else:
    # Insert before footer
    footer = html.find('<div class="footer">')
    if footer != -1:
        new_html = html[:footer] + "\n" + "\n".join(html_lines) + "\n" + html[footer:]
    else:
        new_html = html + "\n" + "\n".join(html_lines) + "\n"
DOCS_HTML_PATH.write_text(new_html)

print("Documentation updated from registry!")
