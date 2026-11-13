import os
import re
import math
from collections import defaultdict

SRC_DIR = r"d:\PROJECT\Other\tepi\src"

def luminance(r, g, b):
    def ch(v):
        s = v / 255.0
        return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)

def contrast(c1, c2):
    l1 = luminance(c1[0], c1[1], c1[2])
    l2 = luminance(c2[0], c2[1], c2[2])
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

def composite(fg, bg):
    # fg: (a, r, g, b), bg: (r, g, b)
    a = fg[0] / 255.0
    r = int(round(fg[1] * a + bg[0] * (1 - a)))
    g = int(round(fg[2] * a + bg[1] * (1 - a)))
    b = int(round(fg[3] * a + bg[2] * (1 - a)))
    return (r, g, b)

print("--- AUDITING TOKENS & CONTRAST ---")

# Dark Tone
dark_bg = (0, 0, 0)
dark_text = (245, 245, 247)
dark_sub = composite((158, 245, 245, 247), dark_bg)
dark_faint = composite((148, 245, 245, 247), dark_bg)

print(f"Dark Text Contrast: {contrast(dark_text, dark_bg):.2f}:1")
print(f"Dark Sub Contrast: {contrast(dark_sub, dark_bg):.2f}:1")
print(f"Dark Faint Contrast: {contrast(dark_faint, dark_bg):.2f}:1")

# Paper / Light Tone
paper_bg = (245, 245, 245)
paper_text = (12, 12, 14)
paper_sub = composite((158, 12, 12, 14), paper_bg)
paper_faint = composite((148, 12, 12, 14), paper_bg)

print(f"Paper Text Contrast: {contrast(paper_text, paper_bg):.2f}:1")
print(f"Paper Sub Contrast: {contrast(paper_sub, paper_bg):.2f}:1")
print(f"Paper Faint Contrast: {contrast(paper_faint, paper_bg):.2f}:1")

# OnGlass test (Sub alpha >= 189)
dark_sub_glass = composite((189, 245, 245, 247), dark_bg)
paper_sub_glass = composite((189, 12, 12, 14), paper_bg)
print(f"Dark Sub OnGlass: {contrast(dark_sub_glass, dark_bg):.2f}:1")
print(f"Paper Sub OnGlass: {contrast(paper_sub_glass, paper_bg):.2f}:1")

# Check accents in Prefs.cs
prefs_path = os.path.join(SRC_DIR, "Prefs.cs")
accents = []
with open(prefs_path, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        m = re.findall(r'"(#[0-9A-Fa-f]{6})"', line)
        if m and ("accent" in line.lower() or "warna" in line.lower() or "presets" in line.lower()):
            for hex_val in m:
                accents.append(hex_val)

print("Accent candidates found in Prefs.cs:", set(accents))

# Let's inspect all Color.FromArgb in codebase
print("\n--- AUDITING HARDCODED COLORS (EXCLUDING INK.CS & COLORS.CS) ---")
color_from_argb_by_file = defaultdict(list)
hex_by_file = defaultdict(list)
new_font_by_file = defaultdict(list)
font_size_calls = defaultdict(list)
sp_calls = defaultdict(list)
fill_round_radii = defaultdict(list)

for root, _, files in os.walk(SRC_DIR):
    for file in files:
        if not file.endswith(".cs"): continue
        path = os.path.join(root, file)
        rel = os.path.relpath(path, SRC_DIR)
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for i, line in enumerate(f, 1):
                # Color.FromArgb
                for m in re.finditer(r'Color\.FromArgb\([^)]+\)', line):
                    if rel not in ["Ink.cs", "Colors.cs"]:
                        color_from_argb_by_file[rel].append((i, m.group(0), line.strip()))
                # Hex color literals like "#123456"
                for m in re.finditer(r'"(#[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{8})"', line):
                    if rel not in ["Ink.cs", "Colors.cs"]:
                        hex_by_file[rel].append((i, m.group(0), line.strip()))
                # new Font(
                for m in re.finditer(r'new\s+Font\([^)]+\)', line):
                    if rel != "Ink.cs":
                        new_font_by_file[rel].append((i, m.group(0), line.strip()))
                # Ink font calls: Ink.Text(12f), Ink.Headline, etc.
                for m in re.finditer(r'Ink\.(Display|Text|Semi|Small|SmallSemi|Mono|Icons)\s*\(\s*([0-9.]+)f?\s*\)', line):
                    font_size_calls[m.group(1)].append((rel, i, m.group(2)))
                # Spacing scale calls: Ink.Sp*
                for m in re.finditer(r'Ink\.(Sp\d+|Radius\w+|Module\w+)', line):
                    sp_calls[m.group(1)].append((rel, i))
                # FillRound / StrokeRound radii
                for m in re.finditer(r'(?:FillRound|StrokeRound|AddRound|Round)\s*\([^,]+,\s*([^,]+),', line):
                    fill_round_radii[rel].append((i, m.group(1).strip()))

print(f"Total files with Color.FromArgb outside Ink/Colors: {len(color_from_argb_by_file)}")
total_argb = sum(len(v) for v in color_from_argb_by_file.values())
print(f"Total Color.FromArgb outside Ink/Colors: {total_argb}")
for f, items in sorted(color_from_argb_by_file.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"  {f}: {len(items)} instances")

print(f"\nTotal files with literal Hex colors: {len(hex_by_file)}")
total_hex = sum(len(v) for v in hex_by_file.values())
print(f"Total literal Hex outside Ink/Colors: {total_hex}")
for f, items in sorted(hex_by_file.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"  {f}: {len(items)} instances")

print(f"\nTotal new Font(...) outside Ink.cs: {sum(len(v) for v in new_font_by_file.values())}")
for f, items in new_font_by_file.items():
    print(f"  {f}: {len(items)} instances -> {items}")

print(f"\nInk font size calls by method:")
distinct_sizes = set()
for method, calls in font_size_calls.items():
    sizes = set(c[2] for c in calls)
    distinct_sizes.update(sizes)
    print(f"  {method}: {len(calls)} calls, sizes: {sorted(sizes, key=lambda x: float(x))}")

print(f"Total distinct px sizes passed to Ink.*(px): {len(distinct_sizes)}")
print(f"Distinct sizes: {sorted([float(x) for x in distinct_sizes])}")

print(f"\nUsage of Ink.Sp* / Radius* / Module* tokens:")
for token, calls in sp_calls.items():
    print(f"  {token}: {len(calls)} usages across {len(set(c[0] for c in calls))} files")

print(f"\nDistinct radii passed to FillRound/StrokeRound: {len(set(r[1] for items in fill_round_radii.values() for r in items))}")
radii_counts = defaultdict(int)
for items in fill_round_radii.values():
    for _, r in items:
        radii_counts[r] += 1
for r, c in sorted(radii_counts.items(), key=lambda x: x[1], reverse=True)[:25]:
    print(f"  Radius {r}: {c} times")
