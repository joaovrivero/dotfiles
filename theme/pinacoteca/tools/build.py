#!/usr/bin/env python3
"""Render every Pinacoteca port from colors.toml.

    python3 theme/pinacoteca/tools/build.py            # write all ports
    python3 theme/pinacoteca/tools/build.py --check    # fail if any port is stale
    HOMEPAGE=~/projects/homepage-v2 python3 ...        # include the homepage ports

Templates live in theme/pinacoteca/templates and are listed in ports.toml.
Placeholders look like {{role}} with optional modifiers separated by colons:

    {{gold}}            -> #d7a447
    {{gold:upper}}      -> #D7A447
    {{bg3:rgb}}         -> 69;59;50       (for ANSI escapes)
    {{gold:l=82}}       -> same hue and chroma, lightness 82 (OKLCH)
    {{bg0:l=14:c=1.0}}  -> lightness 14, chroma 1.0

Three port modes:
    file   the whole output file is the rendered template
    block  only the text between "pinacoteca:begin" and "pinacoteca:end"
           marker lines in the output file is replaced
    json   the template is a JSON object whose top-level keys are merged into
           the output JSON file
"""

import argparse
import json
import os
import re
import sys
import tomllib
from pathlib import Path

HERE = Path(__file__).resolve().parent
THEME = HERE.parent
REPO = THEME.parent.parent
sys.path.insert(0, str(HERE))
from oklch import at, hex2oklch  # noqa: E402

PLACEHOLDER = re.compile(r"\{\{([a-z_][a-z0-9_]*)((?::[a-z]+(?:=[0-9.]+)?)*)\}\}")


def load_palette():
    data = tomllib.load(open(THEME / "colors.toml", "rb"))
    palette = dict(data["palette"])
    palette["accent"] = data["accent"]
    palette["cursor"] = data["cursor"]
    return palette


def resolve(palette, name, mods):
    if name not in palette:
        raise KeyError(f"unknown palette role {name!r}")
    value = palette[name]
    lightness = chroma = None
    upper = rgb = False
    for mod in filter(None, mods.split(":")):
        key, _, arg = mod.partition("=")
        if key == "l":
            lightness = float(arg)
        elif key == "c":
            chroma = float(arg)
        elif key == "upper":
            upper = True
        elif key == "rgb":
            rgb = True
        else:
            raise ValueError(f"unknown modifier {mod!r} on {name}")
    if lightness is not None or chroma is not None:
        base_l = hex2oklch(value)[0] * 100
        value = at(value, base_l if lightness is None else lightness, chroma)
    if rgb:
        return ";".join(str(int(value[i : i + 2], 16)) for i in (1, 3, 5))
    return value.upper() if upper else value


def render(text, palette):
    return PLACEHOLDER.sub(lambda m: resolve(palette, m.group(1), m.group(2)), text)


MARK_BEGIN = re.compile(r"^.*pinacoteca:begin.*$", re.M)
MARK_END = re.compile(r"^.*pinacoteca:end.*$", re.M)


def apply_block(existing, rendered, output):
    begin = MARK_BEGIN.search(existing)
    end = MARK_END.search(existing)
    if not begin or not end or end.start() < begin.end():
        raise SystemExit(f"{output}: expected pinacoteca:begin and pinacoteca:end marker lines")
    body = rendered.rstrip("\n")
    return existing[: begin.end()] + "\n" + body + "\n" + existing[end.start() :]


def apply_json(existing, rendered):
    current = json.loads(existing)
    current.update(json.loads(rendered))
    return json.dumps(current, indent=2, ensure_ascii=False) + "\n"


def output_path(port):
    raw = port["output"]
    if raw.startswith("$HOMEPAGE/"):
        homepage = os.environ.get("HOMEPAGE")
        if not homepage:
            return None
        return Path(homepage).expanduser() / raw[len("$HOMEPAGE/") :]
    return REPO / raw


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="report stale ports instead of writing them")
    args = parser.parse_args()

    palette = load_palette()
    ports = tomllib.load(open(THEME / "ports.toml", "rb"))["port"]
    stale = []
    for port in ports:
        target = output_path(port)
        if target is None:
            continue
        template = (THEME / "templates" / port["template"]).read_text()
        rendered = render(template, palette)
        if "{{" in rendered:
            leftover = rendered[rendered.index("{{") :].split("}}")[0] + "}}"
            raise SystemExit(f"{port['template']}: unresolved placeholder {leftover}")
        mode = port.get("mode", "file")
        if mode == "file":
            new = rendered
        else:
            existing = target.read_text()
            new = apply_block(existing, rendered, port["output"]) if mode == "block" else apply_json(existing, rendered)
        if target.exists() and target.read_text() == new:
            continue
        stale.append(port["output"])
        if not args.check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(new)
            print(f"wrote {port['output']}")

    if args.check and stale:
        print("stale ports (run build.py):\n  " + "\n  ".join(stale), file=sys.stderr)
        sys.exit(1)
    if not stale:
        print("all ports up to date")


if __name__ == "__main__":
    main()
