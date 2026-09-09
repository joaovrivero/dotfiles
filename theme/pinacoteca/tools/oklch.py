"""OKLCH helpers used to derive the Pinacoteca ladder.

    python3 oklch.py "#614529" 19 1.2   -> hex at lightness 19, chroma 1.2, same hue
    python3 oklch.py "#d7a447"          -> print L / C / H of a colour
"""

import math
import sys


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def unlin(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex2oklch(hx):
    r, g, b = [lin(int(hx[i : i + 2], 16) / 255) for i in (1, 3, 5)]
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ** (1 / 3), m ** (1 / 3), s ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b_ = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, b_), (math.degrees(math.atan2(b_, a)) + 360) % 360


def oklch2rgb(L, C, H):
    a = C * math.cos(math.radians(H))
    b_ = C * math.sin(math.radians(H))
    l = L + 0.3963377774 * a + 0.2158037573 * b_
    m = L - 0.1055613458 * a - 0.0638541728 * b_
    s = L - 0.0894841775 * a - 1.2914855480 * b_
    l, m, s = l**3, m**3, s**3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return r, g, b


def oklch2hex(L, C, H):
    """Reduce chroma until the colour fits inside sRGB."""
    c = C
    while c >= 0:
        r, g, b = oklch2rgb(L, c, H)
        if all(-1e-4 <= x <= 1 + 1e-4 for x in (r, g, b)):
            return "#%02x%02x%02x" % tuple(
                int(round(unlin(min(max(x, 0), 1)) * 255)) for x in (r, g, b)
            ), c
        c -= 0.002
    return "#000000", 0


def at(hx, L, c=None):
    """Same hue as hx, lightness L (0-100), optional chroma c (0-100)."""
    l, C, H = hex2oklch(hx)
    return oklch2hex(L / 100, C if c is None else c / 100, H)[0]


def contrast(a, b):
    def Y(hx):
        r, g, b_ = [lin(int(hx[i : i + 2], 16) / 255) for i in (1, 3, 5)]
        return 0.2126 * r + 0.7152 * g + 0.0722 * b_

    ya, yb = Y(a), Y(b)
    return (max(ya, yb) + 0.05) / (min(ya, yb) + 0.05)


if __name__ == "__main__":
    if len(sys.argv) == 2:
        L, C, H = hex2oklch(sys.argv[1])
        print("L %.1f  C %.1f  H %.0f" % (L * 100, C * 100, H))
    elif len(sys.argv) >= 3:
        c = float(sys.argv[3]) if len(sys.argv) > 3 else None
        print(at(sys.argv[1], float(sys.argv[2]), c))
    else:
        print(__doc__)
