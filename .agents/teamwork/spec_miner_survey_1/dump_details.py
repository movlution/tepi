import os
import re
from collections import defaultdict

SRC_DIR = r"d:\PROJECT\Other\tepi\src"

def luminance(hex_str):
    hex_str = hex_str.lstrip('#')
    r = int(hex_str[0:2], 16)
    g = int(hex_str[2:4], 16)
    b = int(hex_str[4:6], 16)
    def ch(v):
        s = v / 255.0
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

def contrast(hex1, hex2):
    l1 = luminance(hex1)
    l2 = luminance(hex2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

accents = [
    ("Biru", "#4C8DFF"),
    ("Hijau", "#3DD68C"),
    ("Kuning", "#FFD24A"),
    ("Oranye", "#FF9F43"),
    ("Merah muda", "#FF6B9A"),
    ("Ungu", "#A78BFA"),
    ("Navy", "#7F8DC6"),
]

dark_ink = "#0A0A0A"
light_ink = "#FAFAFA"
dark_bg = "#000000"
paper_bg = "#F5F5F5"

print("=== ACCENT PRESETS CONTRAST AUDIT ===")
for name, hx in accents:
    c_dark_ink = contrast(hx, dark_ink)
    c_light_ink = contrast(hx, light_ink)
    chosen_ink = "dark (#0A0A0A)" if c_dark_ink >= c_light_ink else "light (#FAFAFA)"
    best_ink_contrast = max(c_dark_ink, c_light_ink)
    worst_ink_contrast = min(c_dark_ink, c_light_ink)
    c_on_dark_bg = contrast(hx, dark_bg)
    c_on_paper_bg = contrast(hx, paper_bg)
    print(f"{name:12} ({hx}):")
    print(f"  vs Dark Ink:  {c_dark_ink:.2f}:1")
    print(f"  vs Light Ink: {c_light_ink:.2f}:1")
    print(f"  Chosen OnAccent Ink: {chosen_ink} -> {best_ink_contrast:.2f}:1 (WCAG AA normal text: {'PASS' if best_ink_contrast >= 4.5 else 'FAIL'})")
    print(f"  As graphic/line on Dark BG ({dark_bg}):  {c_on_dark_bg:.2f}:1 (WCAG UI/icon 3:1: {'PASS' if c_on_dark_bg >= 3.0 else 'FAIL'})")
    print(f"  As graphic/line on Paper BG ({paper_bg}): {c_on_paper_bg:.2f}:1 (WCAG UI/icon 3:1: {'PASS' if c_on_paper_bg >= 3.0 else 'FAIL'})")

print("\n=== HARDCODED Color.FromArgb DETAILS ===")
for root, _, files in os.walk(SRC_DIR):
    for file in sorted(files):
        if not file.endswith(".cs") or file in ["Ink.cs", "Colors.cs"]: continue
        path = os.path.join(root, file)
        rel = os.path.relpath(path, SRC_DIR)
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, 1):
                if "Color.FromArgb" in line:
                    print(f"{rel}:{i} -> {line.strip()}")

print("\n=== LITERAL HEX STRINGS DETAILS ===")
for root, _, files in os.walk(SRC_DIR):
    for file in sorted(files):
        if not file.endswith(".cs") or file in ["Ink.cs", "Colors.cs"]: continue
        path = os.path.join(root, file)
        rel = os.path.relpath(path, SRC_DIR)
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, 1):
                m = re.findall(r'"(#[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{8})"', line)
                if m:
                    print(f"{rel}:{i} -> {m} in: {line.strip()}")
