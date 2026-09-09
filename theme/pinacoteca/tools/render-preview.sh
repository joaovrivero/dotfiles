#!/usr/bin/env bash
# Renders theme/pinacoteca/preview.png (and the homepage images when HOMEPAGE is set)
# from colors.toml: swatch rows with source-painting thumbnails, then a terminal mock
# over six paintings from the slideshow. Needs ImageMagick 7 and the Adwaita Mono font.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="$HERE/.."
S="${SLIDESHOW:-/mnt/c/Users/joaov/Paintings/Slideshow}"
FONT=/usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf
FONTB=/usr/share/fonts/Adwaita/AdwaitaMono-Bold.ttf
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

eval "$(python3 - "$THEME/colors.toml" <<'EOF'
import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
for k, v in d["palette"].items():
    print(f"{k.upper()}='{v}'")
src = {}
for grp in d["provenance"].values():
    for role in grp["roles"]:
        src[role] = grp["painting"]
for k in d["palette"]:
    print(f"SRC_{k.upper()}='{src.get(k, src['bg0']).replace(chr(39), chr(39)+chr(92)+chr(39)+chr(39))}'")
EOF
)"

# terminal mock
BG=$BG0 CM=$COMMENT FGD=$FG_DIM OR=$ORANGE GRN=$GREEN AQ=$AQUA BLU=$BLUE PUR=$PURPLE
magick -size 560x300 xc:"$BG" -fill "$BG2" -draw 'rectangle 0,0 560,26' \
  -fill "$RED" -draw 'circle 14,13 14,7' -fill "$GOLD" -draw 'circle 34,13 34,7' -fill "$GRN" -draw 'circle 54,13 54,7' \
  -font "$FONT" -pointsize 15 \
  -fill "$BLU" -annotate +16+55 '~/dotfiles' -fill "$RED" -annotate +110+55 'main*' -fill "$GOLD" -annotate +170+55 '❯' -fill "$FG" -annotate +190+55 'nvim theme/colors.toml' \
  -fill "$CM" -annotate +16+85 '-- pinacoteca: a gallery-wall theme' \
  -fill "$PUR" -annotate +16+110 'local' -fill "$FG" -annotate +64+110 'palette' -fill "$OR" -annotate +136+110 '=' -fill "$FG" -annotate +152+110 '{' \
  -fill "$BLU" -annotate +40+135 'bg' -fill "$FG" -annotate +64+135 '=' -fill "$GRN" -annotate +80+135 "\"$BG\"" -fill "$FG" -annotate +160+135 ',' \
  -fill "$BLU" -annotate +40+160 'fg' -fill "$FG" -annotate +64+160 '=' -fill "$GRN" -annotate +80+160 "\"$FG\"" -fill "$FG" -annotate +160+160 ',' \
  -fill "$BLU" -annotate +40+185 'accent' -fill "$FG" -annotate +104+185 '=' -fill "$GRN" -annotate +120+185 "\"$GOLD\"" -fill "$CM" -annotate +200+185 '-- gilt frame' \
  -fill "$FG" -annotate +16+210 '}' \
  -fill "$AQ" -annotate +16+245 '✓ 12 passed' -fill "$RED" -annotate +130+245 '✗ 1 failed' -fill "$GOLD" -annotate +240+245 '⚠ 3 warnings' \
  -fill "$BG2" -draw 'rectangle 0,274 560,300' -fill "$GOLD" -draw 'rectangle 0,274 90,300' -fill "$BG" -font "$FONTB" -annotate +14+293 'NORMAL' -fill "$FGD" -font "$FONT" -annotate +104+293 'colors.toml  lua  utf-8  1:1' \
  -bordercolor "$BG3" -border 1 "$W/term.png"

i=0
for f in "Caravaggio - The Supper At Emmaus.jpg" "Claude Monet - The Artist’s Garden in Giverny.jpg" "Katsushika Hokusai - Under the Wave off Kanagawa (The Great Wave).jpg" "Caspar David Friedrich - Two Men Contemplating the Moon.jpg" "Edward Hopper - Chop Suey.jpg" "Utagawa Hiroshige - Gion Shrine in Snow.jpg"; do
  i=$((i+1))
  magick -define jpeg:size=1600x1600 "$S/$f" -resize 800x450^ -gravity center -extent 800x450 "$W/term.png" -gravity center -composite \
    -font "$FONT" -pointsize 13 -fill "$FG" -gravity southwest -undercolor "${BG0}cc" -annotate +8+6 " ${f%.jpg} " "$W/t$i.png"
done
magick "$W/t1.png" "$W/t2.png" +append "$W/r1.png"; magick "$W/t3.png" "$W/t4.png" +append "$W/r2.png"; magick "$W/t5.png" "$W/t6.png" +append "$W/r3.png"
magick "$W/r1.png" "$W/r2.png" "$W/r3.png" -append -resize 1400x "$W/mocks.png"

# swatch rows: A = the gruvbox-derived draft kept for comparison, B = the palette
names=(bg0 bg1 bg2 bg3 comment fg_dim fg red orange gold green aqua blue purple)
rolesA=('#1e1a16' '#282320' '#35302a' '#4a4238' '#7a6d5c' '#a8967c' '#d9c7a8' '#d5695a' '#cc7d4a' '#d8a657' '#9fa45f' '#86a68a' '#7f9ea8' '#c08a9a')
rolesB=("$BG0" "$BG1" "$BG2" "$BG3" "$COMMENT" "$FG_DIM" "$FG" "$RED" "$ORANGE" "$GOLD" "$GREEN" "$AQUA" "$BLUE" "$PURPLE")
srcB=("$SRC_BG0" "$SRC_BG1" "$SRC_BG2" "$SRC_BG3" "$SRC_COMMENT" "$SRC_FG_DIM" "$SRC_FG" "$SRC_RED" "$SRC_ORANGE" "$SRC_GOLD" "$SRC_GREEN" "$SRC_AQUA" "$SRC_BLUE" "$SRC_PURPLE")
args=(); x=20
for i in "${!rolesA[@]}"; do args+=(-fill "${rolesA[$i]}" -draw "roundrectangle $x,30 $((x+80)),90 6,6" -font "$FONT" -pointsize 12 -fill '#a8967c' -annotate "+$x+20" "${names[$i]}" -annotate "+$x+108" "${rolesA[$i]}"); x=$((x+96)); done
magick -size 1400x125 xc:'#1e1a16' "${args[@]}" -gravity northeast -font "$FONTB" -pointsize 14 -fill '#d9c7a8' -annotate +10+6 'A  gruvbox-derived draft' "$W/swA.png"
args=(); x=20
for i in "${!rolesB[@]}"; do
  src="$(find "$S" -maxdepth 1 -name "${srcB[$i]}*" | head -1)"
  [ -n "$src" ] || { echo "missing painting: ${srcB[$i]}" >&2; exit 1; }
  magick -define jpeg:size=400x400 "$src" -resize 80x50^ -gravity center -extent 80x50 "$W/th$i.png"
  args+=(-fill "${rolesB[$i]}" -draw "roundrectangle $x,30 $((x+80)),90 6,6" -font "$FONT" -pointsize 12 -fill "$FG_DIM" -annotate "+$x+20" "${names[$i]}" -annotate "+$x+108" "${rolesB[$i]}" "$W/th$i.png" -gravity northwest -geometry "+$x+118" -composite); x=$((x+96)); done
magick -size 1400x180 xc:"$BG0" "${args[@]}" -gravity northeast -font "$FONTB" -pointsize 14 -fill "$FG" -annotate +10+6 'B  Pinacoteca (source painting under each swatch)' "$W/swB.png"
magick "$W/swA.png" "$W/swB.png" "$W/mocks.png" -append "$W/full.png"

magick "$W/full.png" -resize 1000x -depth 8 "$THEME/preview.png"
if [ -n "${HOMEPAGE:-}" ]; then
  out="$HOMEPAGE/public/images/pinacoteca"; mkdir -p "$out"
  magick "$W/full.png" -quality 82 "$out/preview.webp"
  magick "$W/mocks.png" -quality 82 "$out/mocks.webp"
  magick "$W/swA.png" "$W/swB.png" -append -quality 85 "$out/swatches.webp"
fi
echo "rendered $THEME/preview.png"
