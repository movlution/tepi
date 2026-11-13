import colorsys
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

def rgb_to_hex(rgb):
    return f"#{rgb[0]:02X}{rgb[1]:02X}{rgb[2]:02X}"

paper = hex_to_rgb('#F5F5F5')
dark_bg = hex_to_rgb('#000000')
dark_ink = hex_to_rgb('#0A0A0A')
light_ink = hex_to_rgb('#FAFAFA')

# Perceptually tuned candidates for both Non-Text (>=3.5:1) and Text (>=4.5:1)
candidates = {
    'Biru': [
        ('Original', '#4C8DFF'),
        ('Calibrated 3.5+ (Pure HSL)', '#2F7AFF'),
        ('Calibrated 4.5+ (Pure HSL)', '#0861FF'),
        ('Fluent/Tailwind Blue', '#1A68D6'),
        ('Vibrant Royal Blue', '#1668E8'),
        ('Accessible Blue 4.5+', '#1060E5')
    ],
    'Hijau': [
        ('Original', '#3DD68C'),
        ('Calibrated 3.5+ (Pure HSL)', '#1F925B'),
        ('Calibrated 4.5+ (Pure HSL)', '#1B7E4E'),
        ('Accessible Emerald 3.5+', '#158C55'),
        ('Accessible Emerald 4.5+', '#107C41'),
        ('Forest Emerald', '#0E7A3E')
    ],
    'Kuning': [
        ('Original', '#FFD24A'),
        ('Calibrated 3.5+ (Pure HSL)', '#A37A00'),
        ('Calibrated 4.5+ (Pure HSL)', '#8C6A00'),
        ('Warm Gold 3.5+', '#A87A00'),
        ('Deep Amber 4.5+', '#875C00'),
        ('Golden Ochre 3.5+', '#9E7400'),
        ('Golden Ochre 4.5+', '#855E00')
    ],
    'Oranye': [
        ('Original', '#FF9F43'),
        ('Calibrated 3.5+ (Pure HSL)', '#CB6300'),
        ('Calibrated 4.5+ (Pure HSL)', '#B05600'),
        ('Accessible Amber-Orange 3.5+', '#C85A00'),
        ('Accessible Amber-Orange 4.5+', '#A84B00'),
        ('Warm Tangerine 3.5+', '#D05A00')
    ],
    'Merah muda': [
        ('Original', '#FF6B9A'),
        ('Calibrated 3.5+ (Pure HSL)', '#FE0051'),
        ('Calibrated 4.5+ (Pure HSL)', '#DD0046'),
        ('Accessible Rose 3.5+', '#D82A6A'),
        ('Accessible Rose 4.5+', '#C2185B'),
        ('Vibrant Pink 3.5+', '#D92D6C'),
        ('Vibrant Pink 4.5+', '#BC1B58')
    ],
    'Ungu': [
        ('Original', '#A78BFA'),
        ('Calibrated 3.5+ (Pure HSL)', '#8B65F8'),
        ('Calibrated 4.5+ (Pure HSL)', '#784CF7'),
        ('Accessible Purple 3.5+', '#7C4DFF'),
        ('Accessible Violet 4.5+', '#6C3CE0'),
        ('Fluent Purple 4.5+', '#6B38FB')
    ],
    'Navy': [
        ('Original', '#7F8DC6'),
        ('Calibrated 3.5+ (Pure HSL)', '#6E7DBE'),
        ('Calibrated 4.5+ (Pure HSL)', '#586BB5'),
        ('Accessible Slate Navy 3.5+', '#5C6FB2'),
        ('Accessible Deep Navy 4.5+', '#4D5F9E'),
        ('Indigo Navy 4.5+', '#4B5EA8')
    ]
}

print(f"{'Preset & Candidate':<35} | {'HEX':<8} | {'CR vs #F5F5F5':<14} | {'vs #000000':<12} | {'OnAccent':<18} | {'WCAG Non-Text':<14} | {'WCAG Text'}")
print("=" * 125)

for group, cands in candidates.items():
    print(f"--- {group.upper()} ---")
    for label, hex_code in cands:
        rgb = hex_to_rgb(hex_code)
        cr_paper = contrast(rgb, paper)
        cr_dark = contrast(rgb, dark_bg)
        cr_dark_ink = contrast(rgb, dark_ink)
        cr_light_ink = contrast(rgb, light_ink)
        best_ink = "#0A0A0A" if cr_dark_ink >= cr_light_ink else "#FAFAFA"
        best_cr = max(cr_dark_ink, cr_light_ink)
        on_accent_str = f"{best_ink} ({best_cr:.2f}:1)"
        nt_status = "PASS (>=3.5)" if cr_paper >= 3.5 else "FAIL"
        t_status = "PASS (>=4.5)" if cr_paper >= 4.5 else "FAIL"
        print(f"{label:<35} | {hex_code:<8} | {cr_paper:<14.2f} | {cr_dark:<12.2f} | {on_accent_str:<18} | {nt_status:<14} | {t_status}")
    print()
