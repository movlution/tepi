import math

def srgb_to_lin(c):
    s = c / 255.0
    return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4

def luminance(r, g, b):
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)

def contrast(c1, c2):
    l1 = luminance(*c1)
    l2 = luminance(*c2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(r, g, b):
    return f"#{int(round(r)):02X}{int(round(g)):02X}{int(round(b)):02X}"

presets = [
    ('Biru', '#4C8DFF'),
    ('Hijau', '#3DD68C'),
    ('Kuning', '#FFD24A'),
    ('Oranye', '#FF9F43'),
    ('Merah muda', '#FF6B9A'),
    ('Ungu', '#A78BFA'),
    ('Navy', '#7F8DC6')
]

paper = hex_to_rgb('#F5F5F5')
dark_bg = hex_to_rgb('#000000')
dark_ink = hex_to_rgb('#0A0A0A')
light_ink = hex_to_rgb('#FAFAFA')

print(f"Paper L: {luminance(*paper):.6f}")
print(f"Dark L: {luminance(*dark_bg):.6f}")
print("="*110)
print(f"{'Preset Name':<12} | {'Current HEX':<11} | {'Luminance':<9} | {'vs Paper (#F5F5F5)':<20} | {'Non-Text (>=3.5)':<18} | {'Text (>=4.5)':<14} | {'Best OnAccent'}")
print("-" * 110)

for name, hex_code in presets:
    rgb = hex_to_rgb(hex_code)
    l = luminance(*rgb)
    cr_paper = contrast(rgb, paper)
    cr_dark_ink = contrast(rgb, dark_ink)
    cr_light_ink = contrast(rgb, light_ink)
    non_text_ok = "PASS (>=3.5)" if cr_paper >= 3.5 else f"FAIL ({cr_paper:.2f}:1)"
    text_ok = "PASS (>=4.5)" if cr_paper >= 4.5 else f"FAIL ({cr_paper:.2f}:1)"
    best_on = "#0A0A0A" if cr_dark_ink >= cr_light_ink else "#FAFAFA"
    best_cr = max(cr_dark_ink, cr_light_ink)
    print(f"{name:<12} | {hex_code:<11} | {l:<9.4f} | {cr_paper:<20.2f} | {non_text_ok:<18} | {text_ok:<14} | {best_on} ({best_cr:.2f}:1)")


print("\n" + "="*80)
print(f"{'Preset Name':<12} | {'Current HEX':<11} | {'Luminance':<9} | {'vs Dark (#000000)':<20} | {'Non-Text (>=3.5)':<18}")
print("-" * 80)
for name, hex_code in presets:
    rgb = hex_to_rgb(hex_code)
    l = luminance(*rgb)
    cr_dark = contrast(rgb, dark_bg)
    status = "PASS (>=3.5)" if cr_dark >= 3.5 else "FAIL"
    print(f"{name:<12} | {hex_code:<11} | {l:<9.4f} | {cr_dark:<20.2f} | {status:<18}")
