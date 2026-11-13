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

def mix_round(a, b, k):
    def m(x, y):
        return int(round(x + (y - x) * k))
    return (m(a[0], b[0]), m(a[1], b[1]), m(a[2], b[2]))

def current_derive_palette(bg_hex, text_hex, accent_hex):
    bg = hex_to_rgb(bg_hex)
    text = hex_to_rgb(text_hex)
    accent = hex_to_rgb(accent_hex)
    white = (255, 255, 255)
    
    sub = mix_round(text, bg, 0.24)
    faint = mix_round(text, bg, 0.44)
    
    on_accent = bg if contrast(bg, accent) >= contrast(white, accent) else white
    
    cbg = text
    ca = accent
    for _ in range(14):
        if contrast(ca, cbg) >= 4.5:
            break
        ca = mix_round(ca, bg, 0.22)
        
    card_bg = cbg
    card_text = bg
    card_sub = mix_round(bg, cbg, 0.3)
    card_faint = mix_round(bg, cbg, 0.48)
    card_accent = ca
    card_on_accent = white if contrast(white, ca) >= 4.5 else bg
    
    return {
        'bg': bg,
        'text': text,
        'sub': sub,
        'faint': faint,
        'accent': accent,
        'on_accent': on_accent,
        'card_bg': card_bg,
        'card_text': card_text,
        'card_sub': card_sub,
        'card_faint': card_faint,
        'card_accent': card_accent,
        'card_on_accent': card_on_accent
    }

# Test Cases
test_cases = [
    ("Default Dark", "#000000", "#F5F5F7", "#4C8DFF"),
    ("Default Paper", "#F5F5F5", "#0C0C0E", "#4C8DFF"),
    ("Low Contrast Dark (VIS-06)", "#222222", "#333333", "#444444"),
    ("White on White", "#FFFFFF", "#F5EFE6", "#FFD24A"),
    ("Low Contrast Gray", "#808080", "#909090", "#A0A0A0"),
    ("Yellow on Paper", "#F5F5F5", "#0C0C0E", "#FFD24A"),
]

print("CURRENT DERIVE_PALETTE CONTRAST EVALUATION:")
print("=" * 110)

for name, bg_hex, text_hex, accent_hex in test_cases:
    p = current_derive_palette(bg_hex, text_hex, accent_hex)
    cr_text = contrast(p['text'], p['bg'])
    cr_sub = contrast(p['sub'], p['bg'])
    cr_faint = contrast(p['faint'], p['bg'])
    cr_accent = contrast(p['accent'], p['bg'])
    cr_on_accent = contrast(p['on_accent'], p['accent'])
    
    cr_card_text = contrast(p['card_text'], p['card_bg'])
    cr_card_sub = contrast(p['card_sub'], p['card_bg'])
    cr_card_faint = contrast(p['card_faint'], p['card_bg'])
    cr_card_accent = contrast(p['card_accent'], p['card_bg'])
    
    print(f"Case: {name} (bg={bg_hex}, text={text_hex}, accent={accent_hex})")
    print(f"  Main Island: Text: {cr_text:.2f}:1 | Sub: {cr_sub:.2f}:1 | Faint: {cr_faint:.2f}:1 | Accent: {cr_accent:.2f}:1 | OnAccent: {cr_on_accent:.2f}:1")
    print(f"  Card View:   Text: {cr_card_text:.2f}:1 | Sub: {cr_card_sub:.2f}:1 | Faint: {cr_card_faint:.2f}:1 | Accent: {cr_card_accent:.2f}:1")
    print("-" * 110)
