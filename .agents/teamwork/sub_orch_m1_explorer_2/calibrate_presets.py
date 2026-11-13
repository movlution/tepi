import colorsys
import math

def srgb_to_lin(c):
    s = c / 255.0
    return s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4

def lin_to_srgb(lin):
    s = lin * 12.92 if lin <= 0.0031308 else 1.055 * (lin ** (1.0 / 2.4)) - 0.055
    return min(255, max(0, int(round(s * 255.0))))

def luminance(r, g, b):
    return 0.2126 * srgb_to_lin(r) + 0.7152 * srgb_to_lin(g) + 0.0722 * srgb_to_lin(b)

def contrast(c1, c2):
    l1 = luminance(*c1)
    l2 = luminance(*c2)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return f"#{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"

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

print(f"{'Preset':<12} | {'Original':<8} | {'Orig H':<6} | {'Orig S':<6} | {'Orig L':<6} | {'Orig Lum':<8} | {'Orig vs Paper'}")
print("-" * 80)
for name, hex_code in presets:
    rgb = hex_to_rgb(hex_code)
    h, l, s = colorsys.rgb_to_hls(rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0)
    lum = luminance(*rgb)
    cr = contrast(rgb, paper)
    print(f"{name:<12} | {hex_code:<8} | {h*360:<6.1f} | {s*100:<6.1f}% | {l*100:<6.1f}% | {lum:<8.4f} | {cr:.2f}:1")

def find_calibrated_hls(orig_hex, target_cr, target_hue=None, target_s=None):
    rgb = hex_to_rgb(orig_hex)
    h, orig_l, s = colorsys.rgb_to_hls(rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0)
    if target_hue is not None:
        h = target_hue / 360.0
    if target_s is not None:
        s = target_s
    
    # Binary search lightness between 0.05 and orig_l
    low_l, high_l = 0.01, orig_l
    best_rgb = None
    best_cr = 0
    
    for _ in range(50):
        mid_l = (low_l + high_l) / 2.0
        r, g, b = colorsys.hls_to_rgb(h, mid_l, s)
        rgb_cand = (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
        cr = contrast(rgb_cand, paper)
        if cr >= target_cr:
            best_rgb = rgb_cand
            best_cr = cr
            low_l = mid_l  # can try higher lightness to stay closer to original
        else:
            high_l = mid_l # needs to be darker
            
    return best_rgb, best_cr

print("\n" + "="*95)
print("TIER 1: CALIBRATION FOR NON-TEXT WCAG AA (Target CR >= 3.6:1 against #F5F5F5)")
print("="*95)
print(f"{'Preset':<12} | {'Calibrated HEX':<14} | {'RGB':<16} | {'CR vs #F5F5F5':<14} | {'vs #000000':<12} | {'OnAccent':<10}")
print("-" * 95)

for name, hex_code in presets:
    cand_rgb, cand_cr = find_calibrated_hls(hex_code, 3.6)
    hex_res = rgb_to_hex(cand_rgb)
    cr_dark = contrast(cand_rgb, dark_bg)
    on_accent = "#0A0A0A" if contrast(cand_rgb, dark_ink) >= contrast(cand_rgb, light_ink) else "#FAFAFA"
    print(f"{name:<12} | {hex_res:<14} | {str(cand_rgb):<16} | {cand_cr:<14.2f} | {cr_dark:<12.2f} | {on_accent:<10}")

print("\n" + "="*95)
print("TIER 2: CALIBRATION FOR TEXT WCAG AA (Target CR >= 4.6:1 against #F5F5F5)")
print("="*95)
print(f"{'Preset':<12} | {'Calibrated HEX':<14} | {'RGB':<16} | {'CR vs #F5F5F5':<14} | {'vs #000000':<12} | {'OnAccent':<10}")
print("-" * 95)

for name, hex_code in presets:
    cand_rgb, cand_cr = find_calibrated_hls(hex_code, 4.6)
    hex_res = rgb_to_hex(cand_rgb)
    cr_dark = contrast(cand_rgb, dark_bg)
    on_accent = "#0A0A0A" if contrast(cand_rgb, dark_ink) >= contrast(cand_rgb, light_ink) else "#FAFAFA"
    print(f"{name:<12} | {hex_res:<14} | {str(cand_rgb):<16} | {cand_cr:<14.2f} | {cr_dark:<12.2f} | {on_accent:<10}")
