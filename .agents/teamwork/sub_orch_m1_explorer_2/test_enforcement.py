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

# Contrast Floor Enforcement Helper
def enforce_contrast(c, bg, min_cr, prefer_light=None):
    """
    Enforces that color c has at least min_cr contrast against bg.
    If contrast is below min_cr, c is nudged towards white or black
    depending on bg luminance.
    """
    if contrast(c, bg) >= min_cr:
        return c
        
    bg_lum = luminance(*bg)
    white = (255, 255, 255)
    black = (10, 10, 10)
    
    # Determine direction
    if prefer_light is not None:
        target = white if prefer_light else black
    else:
        # If bg is dark (lum < 0.18), nudge towards white.
        # If bg is light (lum >= 0.18), nudge towards black.
        cr_white = contrast(white, bg)
        cr_black = contrast(black, bg)
        target = white if cr_white >= cr_black else black
        
    res = c
    # Iterative step (or binary search) to achieve min_cr while preserving original hue
    for i in range(20):
        if contrast(res, bg) >= min_cr:
            break
        res = mix_round(res, target, 0.15)
        
    return res

def robust_derive_palette(bg_hex, text_hex, accent_hex):
    bg = hex_to_rgb(bg_hex)
    text = hex_to_rgb(text_hex)
    accent = hex_to_rgb(accent_hex)
    white = (255, 255, 255)
    dark_ink = (10, 10, 10)
    
    # 1. Enforce Primary Text Contrast Floor (min 7.0:1 against bg, or at least 4.5:1)
    text = enforce_contrast(text, bg, 7.0)
    
    # 2. Derive Sub and Faint from Text, then enforce their individual floors
    sub = mix_round(text, bg, 0.24)
    sub = enforce_contrast(sub, bg, 4.5)
    
    faint = mix_round(text, bg, 0.44)
    faint = enforce_contrast(faint, bg, 3.0)
    
    # 3. Enforce Accent Contrast Floor against bg (min 3.5:1 for UI components)
    accent = enforce_contrast(accent, bg, 3.5)
    
    # 4. Enforce OnAccent: Choose between dark ink and white, or adjust
    cr_dark_on_acc = contrast(dark_ink, accent)
    cr_white_on_acc = contrast(white, accent)
    best_on_accent = dark_ink if cr_dark_on_acc >= cr_white_on_acc else white
    if max(cr_dark_on_acc, cr_white_on_acc) < 4.5:
        best_on_accent = enforce_contrast(best_on_accent, accent, 4.5)
        
    # 5. Card derivation
    # Card bg: Use text (or light flip)
    cbg = text
    # Ensure card.text (bg) has contrast against card.bg (cbg)
    card_text = enforce_contrast(bg, cbg, 7.0)
    card_sub = mix_round(card_text, cbg, 0.24)
    card_sub = enforce_contrast(card_sub, cbg, 4.5)
    card_faint = mix_round(card_text, cbg, 0.44)
    card_faint = enforce_contrast(card_faint, cbg, 3.0)
    
    card_accent = enforce_contrast(accent, cbg, 3.5)
    cr_dark_on_ca = contrast(dark_ink, card_accent)
    cr_white_on_ca = contrast(white, card_accent)
    card_on_accent = dark_ink if cr_dark_on_ca >= cr_white_on_ca else white
    if max(cr_dark_on_ca, cr_white_on_ca) < 4.5:
        card_on_accent = enforce_contrast(card_on_accent, card_accent, 4.5)
        
    return {
        'bg': bg,
        'text': text,
        'sub': sub,
        'faint': faint,
        'accent': accent,
        'on_accent': best_on_accent,
        'card_bg': cbg,
        'card_text': card_text,
        'card_sub': card_sub,
        'card_faint': card_faint,
        'card_accent': card_accent,
        'card_on_accent': card_on_accent
    }

test_cases = [
    ("Default Dark", "#000000", "#F5F5F7", "#4C8DFF"),
    ("Default Paper", "#F5F5F5", "#0C0C0E", "#4C8DFF"),
    ("Low Contrast Dark (VIS-06)", "#222222", "#333333", "#444444"),
    ("White on White", "#FFFFFF", "#F5EFE6", "#FFD24A"),
    ("Low Contrast Gray", "#808080", "#909090", "#A0A0A0"),
    ("Yellow on Paper", "#F5F5F5", "#0C0C0E", "#FFD24A"),
]

print("ENFORCED DERIVE_PALETTE CONTRAST EVALUATION:")
print("=" * 115)

for name, bg_hex, text_hex, accent_hex in test_cases:
    p = robust_derive_palette(bg_hex, text_hex, accent_hex)
    cr_text = contrast(p['text'], p['bg'])
    cr_sub = contrast(p['sub'], p['bg'])
    cr_faint = contrast(p['faint'], p['bg'])
    cr_accent = contrast(p['accent'], p['bg'])
    cr_on_accent = contrast(p['on_accent'], p['accent'])
    
    cr_card_text = contrast(p['card_text'], p['card_bg'])
    cr_card_sub = contrast(p['card_sub'], p['card_bg'])
    cr_card_faint = contrast(p['card_faint'], p['card_bg'])
    cr_card_accent = contrast(p['card_accent'], p['card_bg'])
    cr_card_on_accent = contrast(p['card_on_accent'], p['card_accent'])
    
    print(f"Case: {name} (Orig: bg={bg_hex}, text={text_hex}, accent={accent_hex})")
    print(f"  Result HEX: text={rgb_to_hex(*p['text'])}, sub={rgb_to_hex(*p['sub'])}, faint={rgb_to_hex(*p['faint'])}, accent={rgb_to_hex(*p['accent'])}, onAccent={rgb_to_hex(*p['on_accent'])}")
    print(f"  Main Island: Text: {cr_text:.2f}:1 | Sub: {cr_sub:.2f}:1 | Faint: {cr_faint:.2f}:1 | Accent: {cr_accent:.2f}:1 | OnAccent: {cr_on_accent:.2f}:1")
    print(f"  Card View:   Text: {cr_card_text:.2f}:1 | Sub: {cr_card_sub:.2f}:1 | Faint: {cr_card_faint:.2f}:1 | Accent: {cr_card_accent:.2f}:1 | OnAccent: {cr_card_on_accent:.2f}:1")
    print("-" * 115)
