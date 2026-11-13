# Investigation Report: EmptyState Component Standardization & Tokenization Consolidation
**Milestone**: Milestone 3 — Island, Navigation & Views Polish  
**Investigator**: Explorer 3 (`explorer_m3_3`)  
**Target Files**: `src/Panel.cs`, `src/Parts.cs`, `src/WorkWindow.cs`, `src/Views.cs`, `src/Island.cs`, `src/Schedule.cs`, `src/Shelf.cs`, `src/Clips.cs`, `src/ConvertPage.cs`, `src/Handset.cs`, `src/Music.cs`, `src/Sources.cs`  
**Date**: 2026-11-13  

---

## 1. Executive Summary

This investigation provides a comprehensive forensic analysis and implementation specification for two central objectives of Milestone 3:
1. **Consolidation of Empty State UI Primitives**: Eliminating legacy ad-hoc implementations (`Island.Empty` and `Island.Button` in `src/Panel.cs:13-39`) in favor of the unified component `Parts.EmptyState` (`src/Parts.cs:374-387`), updating all 20 call sites across 8 source files with proper theme tokens, semantic typography, and accessible button pills (`PillKind.Primary` / `Secondary`).
2. **Typography Scale & Corner Radius Scale Standardization**: Auditing all arbitrary font sizes and corner radii across `src/Panel.cs`, `src/Parts.cs`, `src/WorkWindow.cs`, `src/Views.cs`, and `src/Island.cs`, establishing an exact mapping to the 7 Type Scale roles (`Hero`, `Title1`, `Title2`, `Headline`, `Body`, `Callout`, `Caption`) and the 3 Concentric Standard Radii (`Ink.RadiusShell` = 32px, `Ink.RadiusModule` = 20px, `Ink.RadiusControl` = 12px) defined in `src/Ink.cs`.

---

## 2. Empty State Component Standardization

### 2.1 Problem Analysis: Legacy `Panel.Empty` vs `Parts.EmptyState`

#### Legacy Implementation (`src/Panel.cs:13-39`)
```csharp
// Empty state; returns button top
float Empty(float w, char glyph, string title, string detail)
{
    float top = PanelTop + 20;
    p.Icon(glyph, 20f, p.T.Sub, w / 2, top + 12);
    p.TextCenter(title, Ink.Semi(15f), p.T.Text, w / 2, top + 44);
    p.TextBox(detail, Ink.Text(12.5f), p.T.Sub, new RectangleF(48, top + 58, w - 96, 38), StringAlignment.Center);
    return top + 104;
}

void Button(RectangleF r, string id, string label, bool filled, Action act)
{
    bool hover = Hover(id), down = Pressed(id);
    AddHit(r, id, act);
    if (down) r.Inflate(-1.5f, -1.5f);
    if (filled)
    {
        p.FillRound(r, 10, down ? Ink.A(p.T.Text, 0.68f) : hover ? Ink.A(p.T.Text, 0.82f) : p.T.Text);
        p.TextCenter(label, Ink.Semi(13f), p.T.Bg, r.X + r.Width / 2, r.Y + r.Height / 2);
    }
    else
    {
        if (hover) p.FillRound(r, 10, down ? p.T.FillHover : p.T.Fill);
        p.StrokeRound(r, 10, p.T.Sub, 1.2f);
        p.TextCenter(label, Ink.Semi(13f), p.T.Text, r.X + r.Width / 2, r.Y + r.Height / 2);
    }
}
```

**Flaws in Legacy `Panel.Empty`:**
1. **Coupled Two-Pass Pattern**: `Empty` only rendered text/glyph and returned a float `by` (`top + 104`), requiring each caller to write a separate call to `Button(...)` with hardcoded rectangle mathematics (`new RectangleF(w / 2 - 74, by, 148, 34)`).
2. **Fixed Top Alignment instead of Vertical Centering**: Always anchored at `top = PanelTop + 20` (74px), leaving awkward empty voids on larger view heights (240px to 380px) or crowding on short views.
3. **Arbitrary Non-Tokenized Styling**:
   - Hardcoded font `Ink.Semi(15f)` (outside 14.5f `Headline` or 17f `Title2`).
   - Hardcoded radius `10` in `Button` (outside the standard 12px `Ink.RadiusControl` or pill shape).
   - Non-semantic text alpha fills `Ink.A(p.T.Text, 0.68f)` and stroke styling rather than standard theme accent/module fills.
4. **No Visual Container for Icon**: Icon floated bare without visual hierarchy or weight.

---

#### Modern Implementation (`src/Parts.cs:374-387`)
```csharp
// Empty state with one action
void EmptyState(RectangleF area, char icon, string title, string line, string action, string id, Action act)
{
    bool button = action != null && act != null;
    float block = 48 + 16 + 20 + 22 + (button ? 18 + 32 : 0);
    float top = area.Y + Math.Max(8, (area.Height - block) / 2), cx = area.X + area.Width / 2;
    var circle = new RectangleF(cx - 24, top, 48, 48);
    p.Module(circle, 24, p.T.Fill);
    p.Icon(icon, 20f, p.T.Sub, cx, top + 24);
    p.TextCenter(title, Ink.Headline, p.T.Text, cx, top + 48 + 16 + 10);
    p.Text(line, Ink.Callout, p.T.Sub, cx, top + 48 + 16 + 20 + 11, area.Width - 48, StringAlignment.Center);
    if (!button) return;
    float bw = Math.Max(120, p.Measure(action, Ink.Semi(13f)) + 40);
    Pill(new RectangleF(cx - bw / 2, top + block - 32, bw, 32), id, action, PillKind.Secondary, act);
}
```

**Key Advantages of `Parts.EmptyState`:**
1. **Dynamic Centering**: Automatically calculates content block height and centers vertically within the given `area` bounding box (`RectangleF area`).
2. **Semantic Design Tokens**:
   - Title uses `Ink.Headline` (14.5px Semi).
   - Description uses `Ink.Callout` (12.5px Text).
   - Icon is anchored inside a soft 48x48 module squircle (`p.Module(circle, 24, p.T.Fill)`).
3. **Modern Pill Action Buttons**: Directly delegates to `Pill(...)` which has full support for spring click feedback (`Squish`), hover states, pressed states, and semantic theming.

---

### 2.2 Proposed Consolidated Component Design (`src/Parts.cs`)

To support all existing usage patterns across the codebase (no button, primary button, secondary button, and dual buttons in Shelf), `Parts.EmptyState` should be expanded with clean overloads:

```csharp
// --- In src/Parts.cs ---

// 1. Empty state without button
void EmptyState(RectangleF area, char icon, string title, string line)
{
    EmptyState(area, icon, title, line, null, null, null, PillKind.Secondary);
}

// 2. Empty state with single action (Primary or Secondary)
void EmptyState(RectangleF area, char icon, string title, string line, string action, string id, Action act, PillKind kind = PillKind.Secondary)
{
    bool button = !string.IsNullOrEmpty(action) && act != null;
    float block = 48 + 16 + 20 + 24 + (button ? 18 + 32 : 0);
    float top = area.Y + Math.Max(8, (area.Height - block) / 2), cx = area.X + area.Width / 2;
    var circle = new RectangleF(cx - 24, top, 48, 48);
    p.Module(circle, 24, p.T.Fill);
    p.Icon(icon, 20f, p.T.Sub, cx, top + 24);
    p.TextCenter(title, Ink.Headline, p.T.Text, cx, top + 48 + 16 + 10);
    if (!string.IsNullOrEmpty(line))
    {
        var lineBox = new RectangleF(area.X + 24, top + 48 + 16 + 20 + 4, area.Width - 48, 38);
        p.TextBox(line, Ink.Callout, p.T.Sub, lineBox, StringAlignment.Center);
    }
    if (!button) return;
    float bw = Math.Max(120, p.Measure(action, Ink.Callout) + 40);
    Pill(new RectangleF(cx - bw / 2, top + block - 32, bw, 32), id, action, kind, act);
}

// 3. Empty state with dual action buttons (side-by-side)
void EmptyState(RectangleF area, char icon, string title, string line,
    string action1, string id1, Action act1, PillKind kind1,
    string action2, string id2, Action act2, PillKind kind2)
{
    float block = 48 + 16 + 20 + 24 + 18 + 32;
    float top = area.Y + Math.Max(8, (area.Height - block) / 2), cx = area.X + area.Width / 2;
    var circle = new RectangleF(cx - 24, top, 48, 48);
    p.Module(circle, 24, p.T.Fill);
    p.Icon(icon, 20f, p.T.Sub, cx, top + 24);
    p.TextCenter(title, Ink.Headline, p.T.Text, cx, top + 48 + 16 + 10);
    if (!string.IsNullOrEmpty(line))
    {
        var lineBox = new RectangleF(area.X + 24, top + 48 + 16 + 20 + 4, area.Width - 48, 38);
        p.TextBox(line, Ink.Callout, p.T.Sub, lineBox, StringAlignment.Center);
    }
    float bw = 136, gap = 12;
    Pill(new RectangleF(cx - bw - gap / 2, top + block - 32, bw, 32), id1, action1, kind1, act1);
    Pill(new RectangleF(cx + gap / 2, top + block - 32, bw, 32), id2, action2, kind2, act2);
}
```

#### Backward Compatibility Delegation in `src/Panel.cs`
To prevent regression and guarantee 100% binary/source compatibility:
```csharp
// --- In src/Panel.cs (lines 13-39) ---
// Backward compatibility wrapper delegating to unified Parts.EmptyState
float Empty(float w, char glyph, string title, string detail)
{
    var area = new RectangleF(0, PanelTop, w, PanelHeight() - PanelTop - 10);
    EmptyState(area, glyph, title, detail);
    return area.Y + Math.Max(8, (area.Height - 108) / 2) + 108;
}

// Backward compatibility wrapper delegating to unified Parts.Pill
void Button(RectangleF r, string id, string label, bool filled, Action act)
{
    Pill(r, id, label, filled ? PillKind.Primary : PillKind.Secondary, act);
}
```

---

### 2.3 Complete Inventory & Migration Matrix of Call Sites (20 sites across 8 files)

| # | File | Line | Current Code | Target Call | Button Semantics |
|---|------|------|--------------|-------------|------------------|
| 1 | `src/Clips.cs` | 118-119 | `float by = Empty(w, '', ...); Button(..., "clipsOn", Lang.T("Nyalakan"), true, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Riwayat clipboard mati"), Lang.T("Teks yang disalin hanya disimpan di memori dan hilang saat Tepi ditutup"), Lang.T("Nyalakan"), "clipsOn", delegate { SetFlag("clipboard", true); }, PillKind.Primary);` | Primary CTA |
| 2 | `src/Clips.cs` | 124 | `Empty(w, '', Lang.T("Belum ada yang disalin"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Belum ada yang disalin"), Lang.T("Teks yang kamu salin muncul di sini"));` | No button |
| 3 | `src/ConvertPage.cs` | 112-113 | `float by = Empty(w, IcoConvert, ...); Button(..., "convOn", Lang.T("Nyalakan"), true, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), IcoConvert, Lang.T("Ubah format mati"), Lang.T("Berkas yang diseret ke island hanya bisa ditaruh di rak"), Lang.T("Nyalakan"), "convOn", delegate { SetFlag("convert", true); }, PillKind.Primary);` | Primary CTA |
| 4 | `src/Handset.cs` | 272-273 | `float by = Empty(w, IcoPhone, ...); Button(..., "phoneLink", Lang.T("Hubungkan"), false, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), IcoPhone, Lang.T("HP belum tersambung"), Lang.T("Tepi di Android, satu Wi-Fi dengan laptop"), Lang.T("Hubungkan"), "phoneLink", delegate { OpenPrefs("phone"); }, PillKind.Secondary);` | Secondary CTA |
| 5 | `src/Music.cs` | 294 | `Empty(w, '\uE8D6', Lang.T("Tidak ada yang diputar"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '\uE8D6', Lang.T("Tidak ada yang diputar"), Lang.T("Spotify, YouTube Music, Apple Music, browser, VLC, dan pemutar lain"));` | No button |
| 6 | `src/Panel.cs` | 189 | `Empty(w, Ink.IcoTerminal, Lang.T("Server hook mati"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoTerminal, Lang.T("Server hook mati"), hub.Error + Lang.T(" · agent.port di settings.ini"));` | No button |
| 7 | `src/Panel.cs` | 198 | `Empty(w, Ink.IcoTerminal, Lang.T("Belum ada sesi agen"), ...);` (with translate transform) | `EmptyState(new RectangleF(0, PanelTop + qh, w, h - PanelTop - qh), Ink.IcoTerminal, Lang.T("Belum ada sesi agen"), linked.Length > 0 ? Lang.T("Terhubung: ") + linked : Lang.T("Belum terhubung · tray > Hubungkan agen"));` | No button (with quota header offset) |
| 8 | `src/Panel.cs` | 317-318 | `float ry = Empty(w, Ink.IcoCalendar, Lang.T("Tugas gagal dimuat"), ...); Button(..., "retry", Lang.T("Coba lagi"), false, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, Lang.T("Tugas gagal dimuat"), taskNote, Lang.T("Coba lagi"), "retry", delegate { RefreshAll(1); }, PillKind.Secondary);` | Secondary CTA |
| 9 | `src/Panel.cs` | 333 | `Empty(w, Ink.IcoCalendar, Lang.T("Tidak ada tugas aktif"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, Lang.T("Tidak ada tugas aktif"), taskNote ?? (OnlyKuliaTasks ? Lang.T("Diperbarui tiap 10 menit") : Lang.T("Diperbarui tiap 15 menit")));` | No button |
| 10 | `src/Panel.cs` | 414 | `Empty(w, Ink.IcoBell, Lang.T("Notifikasi pesan dimatikan"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoBell, Lang.T("Notifikasi pesan dimatikan"), Lang.T("Saklarnya ada di menu klik kanan"));` | No button |
| 11 | `src/Panel.cs` | 419-424 | `float ny = Empty(w, Ink.IcoLock, ...); Button(..., "notifPerm", Lang.T("Buka pengaturan"), false, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoLock, Lang.T("Akses notifikasi ditolak"), Lang.T("Pengaturan Windows > Privasi > Notifikasi"), Lang.T("Buka pengaturan"), "notifPerm", delegate { try { Process.Start("ms-settings:privacy-notifications"); } catch (Exception ex) { Log.Write("settings: " + ex.Message); } }, PillKind.Secondary);` | Secondary CTA |
| 12 | `src/Panel.cs` | 431-433 | `float fy = Empty(w, Ink.IcoBell, ...); Button(..., "notifRetry", Lang.T("Coba lagi"), false, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoBell, Lang.T("Pesan tidak bisa dibaca"), Lang.T("Notifikasi Windows tidak menjawab. Tepi mencoba lagi otomatis."), Lang.T("Coba lagi"), "notifRetry", delegate { notifWatcher.Refresh(); }, PillKind.Secondary);` | Secondary CTA |
| 13 | `src/Panel.cs` | 435 | `Empty(w, Ink.IcoBell, Lang.T("Belum ada pesan"), ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoBell, Lang.T("Belum ada pesan"), Lang.T("WhatsApp, Telegram, Discord, Teams, email"));` | No button |
| 14 | `src/Schedule.cs` | 93-94 | `float ry = Empty(w, Ink.IcoCalendar, ...); Button(..., "retrySchedule", Lang.T("Coba lagi"), false, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, Lang.T("Jadwal gagal dimuat"), eventNote, Lang.T("Coba lagi"), "retrySchedule", delegate { RefreshAll(2); }, PillKind.Secondary);` | Secondary CTA |
| 15 | `src/Schedule.cs` | 99 | `Empty(w, Ink.IcoCalendar, Lang.T("Memuat jadwal…"), "");` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, Lang.T("Memuat jadwal…"), "");` | No button |
| 16 | `src/Schedule.cs` | 105 | `Empty(w, Ink.IcoCalendar, kuliaOnly ? ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, kuliaOnly ? Lang.T("Tidak ada kelas") : Lang.T("Jadwal kosong"), eventNote ?? (kuliaOnly ? Lang.T("7 hari ke depan kosong") : Lang.T("3 minggu ke depan kosong")));` | No button |
| 17 | `src/Shelf.cs` | 248-250 | `float by = Empty(w, '', ...); Button(..., "shelfOn", Lang.T("Nyalakan"), true, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Rak mati"), Lang.T("Berkas yang diseret ke island tidak ditahan"), Lang.T("Nyalakan"), "shelfOn", delegate { SetFlag("shelf", true); }, PillKind.Primary);` | Primary CTA |
| 18 | `src/Shelf.cs` | 254-261 | `float by = Empty(w, '', ...); if (shelfPaste) { Button(...); Button(...); } else Button(...);` | `if (shelfPaste) EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Rak kosong"), Lang.T("Seret berkas ke island, atau pilih dari folder"), Lang.T("Pilih berkas"), "shelfPick", PickShelfFiles, PillKind.Primary, Lang.T("Tempel"), "shelfPasteBtn", PasteToShelf, PillKind.Secondary); else EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Rak kosong"), Lang.T("Seret berkas ke island, atau pilih dari folder"), Lang.T("Pilih berkas"), "shelfPick", PickShelfFiles, PillKind.Primary);` | Dual CTA / Primary CTA |
| 19 | `src/Sources.cs` | 987-989 | `float by = Empty(w, Ink.IcoCalendar, title, detail); Button(..., id, Lang.T("Buka Integrasi"), true, ...);` | `EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), Ink.IcoCalendar, title, detail, Lang.T("Buka Integrasi"), id, delegate { OpenIntegrations(); }, PillKind.Primary);` | Primary CTA |
| 20 | `src/Panel.cs` | 13-20 | `float Empty(...)` definition | Delegate to `EmptyState(...)` | Wrapper |

---

## 3. Typography Scale Consolidation

### 3.1 Design System Reference: 7 Type Scale Roles (`src/Ink.cs:291-298`)

| Role | Font Family | Size (px) | Weight | Design System Token | Primary Intent |
|------|-------------|-----------|--------|---------------------|----------------|
| **Hero** | Display (`FDisplay`) | 40.0 | Semibold | `Ink.Hero` | Massive focal numbers (clock, counters) |
| **Title 1** | Display (`FDisplay`) | 22.0 | Semibold | `Ink.Title1` | Prompter titles, large view headings |
| **Title 2** | Semi (`FSemi`) | 17.0 | Semibold | `Ink.Title2` | Section headings, day calendar numbers |
| **Headline**| Semi (`FSemi`) | 14.5 | Semibold | `Ink.Headline` | Empty state titles, card headers, list titles |
| **Body** | Text (`FText`) | 13.5 | Regular | `Ink.Body` | Main reading text, lyrics, descriptions |
| **Callout** | Text (`FText`) | 12.5 | Regular | `Ink.Callout` | Secondary lines, trailing text, pills, hints |
| **Caption** | Small (`FSmall`) | 11.0 | Regular | `Ink.Caption` | Meta text, timestamps, tags, badges |

---

### 3.2 Audit & Mapping of Arbitrary Fonts Across Target Codebases

#### A. `src/Panel.cs`
| Line | Current Code | Raw Size | Proposed Token | Rationale |
|------|--------------|----------|----------------|-----------|
| 17 | `p.TextCenter(title, Ink.Semi(15f), ...)` | 15.0px semi | `Ink.Headline` (14.5px) | Standard empty state heading token |
| 18 | `p.TextBox(detail, Ink.Text(12.5f), ...)` | 12.5px text | `Ink.Callout` (12.5px) | Standard secondary body token |
| 31, 37 | `p.TextCenter(label, Ink.Semi(13f), ...)` | 13.0px semi | `Ink.Callout` or `Ink.Headline` | Button action text in Pill |
| 57 | `p.Text(..., Ink.Text(12.5f), ...)` | 12.5px text | `Ink.Callout` | "Mencari lirik…" status text |
| 64 | `p.TextBox(..., Ink.Text(12.5f), ...)` | 12.5px text | `Ink.Callout` | Lyrics search message |
| 105 | `var big = Ink.Display(15.5f);` | 15.5px display | `Ink.Headline` (14.5px) | Active lyric highlight |
| 110 | `p.Text(..., Ink.Text(13.5f), ...)` | 13.5px text | `Ink.Body` (13.5px) | Standard lyrics line text |
| 129 | `p.Text(..., Ink.Small(11f), ...)` | 11.0px small | `Ink.Caption` (11.0px) | Meta footer note |
| 141 | `p.Text(..., Ink.Text(13f), ...)` | 13.0px text | `Ink.Body` (13.5px) | Unsynced lyrics list lines |
| 233 | `var semi = Ink.Semi(13.5f);` | 13.5px semi | `Ink.Headline` or `Ink.Body` | Agent project title |
| 236 | `p.Text(..., Ink.Small(11f), ...)` | 11.0px small | `Ink.Caption` (11.0px) | Agent tag/badge |
| 244 | `p.TextCenter(..., Ink.Semi(10.5f), ...)` | 10.5px semi | `Ink.Caption` (11.0px) | "Chat" pill button text |
| 250, 253| `Ink.Small(11f)` | 11.0px small | `Ink.Caption` (11.0px) | Agent state timestamp/word |
| 258, 260| `p.Text(..., Ink.Text(12f), ...)` | 12.0px text | `Ink.Callout` (12.5px) | Agent plan message |
| 262 | `p.Text(..., Ink.Mono(11.5f), ...)` | 11.5px mono | `Ink.Mono(Ink.Caption.Size)` | Monospaced agent terminal line |
| 271 | `p.TextRight(..., Ink.Semi(11f), ...)` | 11.0px semi | `Ink.Caption` (11.0px) | Plan segment count toggle |
| 326, 328| `p.Text(..., Ink.Text(13f), ...)` | 13.0px text | `Ink.Body` (13.5px) | "Memuat tugas…" loading indicator |
| 338 | `p.Text(..., Ink.Small(11f), ...)` | 11.0px small | `Ink.Caption` (11.0px) | Task note footer |
| 356 | `p.TextCenter(..., Ink.Display(17f), ...)` | 17.0px display | `Ink.Title2` (17.0px) | Calendar day number |
| 357 | `p.TextCenter(..., Ink.Small(10.5f), ...)` | 10.5px small | `Ink.Caption` (11.0px) | Calendar month abbreviation |
| 362 | `var wf = Ink.Semi(11.5f);` | 11.5px semi | `Ink.Callout` or `Ink.Caption` | Relative time label |
| 370 | `p.TextCenter(..., Ink.Semi(12f), ...)` | 12.0px semi | `Ink.Callout` (12.5px) | "Tandai selesai" button label |
| 384 | `p.Text(..., Ink.Small(11f), ...)` | 11.0px small | `Ink.Caption` (11.0px) | Course metadata |
| 385 | `p.Text(..., Ink.Semi(13f), ...)` | 13.0px semi | `Ink.Body` or `Ink.Headline` | Task title |
| 454 | `p.Text(..., Ink.Semi(12.5f), ...)` | 12.5px semi | `Ink.Callout` (12.5px) | Notification row title |
| 455 | `p.Text(..., Ink.Text(11.5f), ...)` | 11.5px text | `Ink.Caption` (11.0px) | Notification row body preview |
| 462 | `p.TextRight(..., Ink.Small(11f), ...)` | 11.0px small | `Ink.Caption` (11.0px) | Notification relative time |

#### B. `src/Views.cs`
| Line | Current Code | Raw Size | Proposed Token | Rationale |
|------|--------------|----------|----------------|-----------|
| 212, 213| `p.TextCenter(..., Ink.Semi(12f), ...)` | 12.0px semi | `Ink.Callout` (12.5px) | Idle pill status labels |
| 230 | `clockRoller.Draw(..., Ink.Display(15.5f), ...)`| 15.5px display | `Ink.Title2` (17.0px) | Idle time display |
| 245 | `p.TextCenter(..., Ink.Semi(10.5f), ...)` | 10.5px semi | `Ink.Caption` (11.0px) | Idle badge counter |
| 252 | `p.Measure(..., Ink.Semi(12.5f))` | 12.5px semi | `Ink.Callout` (12.5px) | Media progress text |
| 365, 366| `Font tf = Ink.Headline, af = Ink.Text(14.5f)` | 14.5px text | `af = Ink.Body` (13.5px) | Track header meta text |
| 428 | `var font = Ink.Display(14.5f);` | 14.5px display | `Ink.Headline` (14.5px) | Track title heading |
| 452 | `p.Text(..., Ink.Semi(14.5f), ...)` | 14.5px semi | `Ink.Headline` (14.5px) | Media flyout title |
| 453 | `p.Text(..., Ink.Text(12.5f), ...)` | 12.5px text | `Ink.Callout` (12.5px) | Media flyout artist |
| 465, 486| `Ink.Semi(13f)` | 13.0px semi | `Ink.Body` or `Ink.Headline` | Compact agent HUD title |
| 466, 498| `Ink.Semi(11.5f)` | 11.5px semi | `Ink.Caption` (11.0px) | Agent step counter |
| 467, 492| `Ink.Small(11f)` | 11.0px small | `Ink.Caption` (11.0px) | Agent kind badge |
| 499 | `p.Text(..., Ink.Text(12f), ...)` | 12.0px text | `Ink.Callout` (12.5px) | Agent step text |
| 500, 519, 531, 536, 633 | `Ink.Mono(12f)` | 12.0px mono | `Ink.Mono(Ink.Callout.Size)` | Approval terminal monospaced code |
| 591 | `p.Text(..., Ink.Semi(14.5f), ...)` | 14.5px semi | `Ink.Headline` (14.5px) | Approval request header |
| 594, 600, 602, 609, 616 | `Ink.Semi(12f)` | 12.0px semi | `Ink.Callout` (12.5px) | Approval risk/flag pills |
| 619 | `p.Text(..., Ink.Text(12f), ...)` | 12.0px text | `Ink.Callout` (12.5px) | Approval note |
| 645, 652| `Ink.Small(11.5f)` | 11.5px small | `Ink.Caption` (11.0px) | Terminal scroll notice |
| 664, 667, 671 | `Ink.Semi(13f)` | 13.0px semi | `Ink.Headline` or `Ink.Body` | Approval button labels ("Izinkan", "Tolak", "Selalu") |
| 675 | `Ink.Small(12f)` | 12.0px small | `Ink.Callout` (12.5px) | "Terminal" button label |
| 701, 703| `Ink.Small(11.5f)` | 11.5px small | `Ink.Caption` (11.0px) | Done toast timestamp / tail |
| 702 | `Ink.Semi(13.5f)` | 13.5px semi | `Ink.Body` or `Ink.Headline` | Done toast title |
| 706 | `Ink.Text(12f)` | 12.0px text | `Ink.Callout` (12.5px) | Done toast recap |
| 756, 757| `Ink.Small(11f)` | 11.0px small | `Ink.Caption` (11.0px) | Notification toast meta text |
| 758 | `Ink.Semi(13.5f)` | 13.5px semi | `Ink.Headline` (14.5px) | Notification toast title |
| 759 | `Ink.Text(12.5f)` | 12.5px text | `Ink.Callout` (12.5px) | Notification toast body preview |
| 780, 787, 795, 807, 847, 855 | `Ink.Semi(13.5f)` | 13.5px semi | `Ink.Body` (13.5px) | Status toast titles |
| 808, 812, 834, 858, 867 | `Ink.Text(12.5f)` | 12.5px text | `Ink.Callout` (12.5px) | Status toast details |
| 879, 899| `Ink.Semi(12.5f)` | 12.5px semi | `Ink.Callout` (12.5px) | Deadline toast class title |
| 912, 913| `Ink.Text(12.5f)` | 12.5px text | `Ink.Callout` (12.5px) | Deadline toast countdown details |

#### C. `src/WorkWindow.cs`
| Line | Current Code | Raw Size | Proposed Token | Rationale |
|------|--------------|----------|----------------|-----------|
| 248 | `fText = UiFont(14f);` | 14.0px | `UiFont(Ink.Body.Size)` (13.5f) | Primary body text in lists/inputs |
| 248 | `fSub = UiFont(12.5f);` | 12.5px | `UiFont(Ink.Callout.Size)` (12.5f) | Subtitle and secondary label font |
| 248 | `fSmall = UiFont(11.5f);` | 11.5px | `UiFont(Ink.Caption.Size)` (11.0f) | Small timestamp/save state font |
| 249 | `fBold = new Font(Ink.MenuFamily, 14f * s, FontStyle.Bold, GraphicsUnit.Pixel);` | 14.0px bold | `new Font(Ink.MenuFamily, Ink.Headline.Size * s, FontStyle.Bold, GraphicsUnit.Pixel)` | Bold item title (14.5px) |

---

## 4. Radius Scale Consolidation

### 4.1 Design System Reference: 3 Concentric Standard Radii (`src/Ink.cs:247`)

```csharp
// Concentric radii: shell, module, control
public const float RadiusShell = 32, RadiusModule = 20, RadiusControl = 12;
```
1. **`Ink.RadiusShell` (32px)**: Outer structural shell for all top-level windows, panels, flyouts, and dialog frames.
2. **`Ink.RadiusModule` (20px)**: Intermediate structural containers, cards, well areas, and large grouped hero tiles.
3. **`Ink.RadiusControl` (12px)**: Interactive controls, button surfaces, input boxes, hover highlights, and row hit targets.
*(Note: Capsule/pill elements use dynamic `height / 2` by geometric definition.)*

---

### 4.2 Audit & Consolidation Mapping

#### A. View Outer Shells (`src/Views.cs:60-79` — `ViewRadius`)
Currently, `ViewRadius` returns arbitrary numbers:
```csharp
// BEFORE (src/Views.cs:60-79)
float ViewRadius(View v, SizeF s)
{
    if (UprightNow(v)) return s.Width / 2;
    switch (v)
    {
        case View.Panel:
        case View.Approve: return 30; // Arbitrary 30
        case View.Track:
        case View.Done:
        case View.Notif:
        case View.Deadline:
        case View.Shot:
        case View.Drive:
        case View.Otp:
        case View.Prompter: return 26; // Arbitrary 26
        case View.Mirror: return 28; // Arbitrary 28
        case View.Convert: return 26; // Arbitrary 26
    }
    return s.Height / 2;
}
```
**Replacement**:
All outer window shells should standardize directly to `Ink.RadiusShell` (32px), with `Ink.Round`'s built-in budget clamp (`Math.Min(r.Width, r.Height) / 2`) safely handling pill views:
```csharp
// AFTER (src/Views.cs:60-79)
float ViewRadius(View v, SizeF s)
{
    if (UprightNow(v)) return s.Width / 2;
    switch (v)
    {
        case View.Panel:
        case View.Approve:
        case View.Track:
        case View.Done:
        case View.Notif:
        case View.Deadline:
        case View.Shot:
        case View.Drive:
        case View.Otp:
        case View.Prompter:
        case View.Mirror:
        case View.Convert:
            return Math.Min(Ink.RadiusShell, s.Height / 2);
    }
    return s.Height / 2;
}
```

#### B. Component & Well Containers
| File | Line | Current Code | Raw Radius | Proposed Token | Notes |
|------|------|--------------|------------|----------------|-------|
| `src/Schedule.cs` | 112 | `p.FillRound(hero, 18, p.T.Fill);` | 18 | `Ink.RadiusModule` (20) | Next class hero card |
| `src/ConvertPage.cs` | 134 | `p.FillRound(box, 22, ...);` | 22 | `Ink.RadiusModule` (20) | Drag-and-drop hero convert container |
| `src/WorkWindow.cs` | 328 | `Well(g, wellList, 14 * s);` | 14 * s | `Ink.RadiusModule * s` (20 * s) | Task list well container |
| `src/WorkWindow.cs` | 332 | `Well(g, wellNotes, 14 * s);` | 14 * s | `Ink.RadiusModule * s` (20 * s) | Notes list well container |
| `src/WorkWindow.cs` | 332 | `Well(g, wellEditor, 14 * s);` | 14 * s | `Ink.RadiusModule * s` (20 * s) | Note editor well container |
| `src/WorkWindow.cs` | 328, 332 | `Well(g, wellAdd/wellSearch, 12 * s);` | 12 * s | `Ink.RadiusControl * s` (12 * s) | Single-line input controls (Already matches!) |

#### C. Interactive Controls & Row Hover States
| File | Line | Current Code | Raw Radius | Proposed Token | Notes |
|------|------|--------------|------------|----------------|-------|
| `src/Panel.cs` | 30, 35, 36 | `p.FillRound(r, 10, ...)` | 10 | `Ink.RadiusControl` (12) | Legacy button radius |
| `src/Panel.cs` | 228, 231 | `p.FillRound(row, 16, ...)` | 16 | `Ink.RadiusControl` (12) | Agent session row hover |
| `src/Panel.cs` | 353 | `p.FillRound(row, 14, ...)` | 14 | `Ink.RadiusControl` (12) | Task list row hover |
| `src/Panel.cs` | 368, 369 | `p.FillRound(btn, 10, ...)` | 10 | `Ink.RadiusControl` (12) | "Tandai selesai" button |
| `src/Panel.cs` | 450 | `p.FillRound(row, 14, ...)` | 14 | `Ink.RadiusControl` (12) | Message list row hover |
| `src/Views.cs` | 662-673 | `p.FillRound(allow/deny/always/term, 10, ...)` | 10 | `Ink.RadiusControl` (12) | Approval action buttons |
| `src/WorkWindow.cs` | 577 | `Ink.Round(row, 10 * s)` | 10 * s | `Ink.RadiusControl * s` (12 * s) | Task list item hover |
| `src/WorkWindow.cs` | 757 | `Ink.Round(row, 10 * s)` | 10 * s | `Ink.RadiusControl * s` (12 * s) | Notes list item hover |
| `src/Clips.cs` | 137 | `p.FillRound(row, 14, ...)` | 14 | `Ink.RadiusControl` (12) | Clipboard row hover |
| `src/ConvertPage.cs` | 225 | `p.FillRound(row, 14, ...)` | 14 | `Ink.RadiusControl` (12) | Convert history row hover |
| `src/Music.cs` | 362, 363 | `p.FillRound(r, 14, ...)` | 14 | `Ink.RadiusControl` (12) | Lyrics row hover |
| `src/Shelf.cs` | 296, 313, 341 | `p.FillRound(hit, 16, ...)` | 16 | `Ink.RadiusControl` (12) | Shelf grid cell hover |

---

## 5. Toast Notification Meta Text Collision Fix (`src/Views.cs:755-759`)

### 5.1 Root Cause Analysis
In `src/Views.cs:749-761`:
```csharp
void DrawNotif(float w, float h)
{
    var item = toast != null ? toast.Data as NotifItem : null;
    if (item == null) return;
    float cy = h / 2;
    DrawAppBadge(item, new RectangleF(14, cy - 20, 40, 40));
    string meta = notifBurst > 1 ? notifBurst + Lang.T(" pesan · ") + item.AppName : item.AppName;
    float mw = Math.Min(130, p.Measure(meta, Ink.Small(11f)));
    p.TextRight(meta, Ink.Small(11f), p.T.Sub, w - 22, cy - 10);
    p.Text(NotifTitle(item), Ink.Semi(13.5f), p.T.Text, 66, cy - 10, w - 66 - 32 - mw, StringAlignment.Near);
    p.Text(NotifBody(item), Ink.Text(12.5f), p.T.Sub, 66, cy + 10, w - 66 - 22, StringAlignment.Near);
    AddHit(new RectangleF(0, 0, w, h), "notifOpen", delegate { OpenNotifApp(item); });
}
```
1. `float mw = Math.Min(130, p.Measure(meta, Ink.Small(11f)));` caps `mw` at 130px.
2. `p.TextRight(meta, ...)` calls `Text(s, f, c, right, cy, 2000, StringAlignment.Far)`. Because the max width passed to GDI+ is 2000px, if `meta` is 180px long, it renders 180px wide starting from `w - 22` towards the left.
3. Meanwhile, `NotifTitle` calculates its available width as `w - 66 - 32 - mw`. Since `mw` was clamped to 130, `NotifTitle` renders up to `w - 66 - 32 - 130 = w - 228`.
4. The long app name renders from `w - 22` leftward to `w - 202`. As a result, the right side of `NotifTitle` directly collides and overlaps with the left side of `meta`!

### 5.2 Proposed Solution
1. Use `Ink.Caption` (11.0px) for `meta`.
2. Limit the allocated width for `meta` proportionally to `float mw = Math.Min(w * 0.35f, p.Measure(meta, Ink.Caption));`.
3. Call `p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);` so that if `meta` exceeds `mw`, GDI+ clips/ellipsizes it within `mw` instead of expanding leftward.
4. Calculate title width as `w - 66 - 22 - mw - 12` to ensure a guaranteed 12px horizontal separation buffer.

```csharp
void DrawNotif(float w, float h)
{
    var item = toast != null ? toast.Data as NotifItem : null;
    if (item == null) return;
    float cy = h / 2;
    DrawAppBadge(item, new RectangleF(14, cy - 20, 40, 40));
    string meta = notifBurst > 1 ? notifBurst + Lang.T(" pesan · ") + item.AppName : item.AppName;
    float mw = Math.Min(w * 0.35f, p.Measure(meta, Ink.Caption));
    p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far);
    p.Text(NotifTitle(item), Ink.Headline, p.T.Text, 66, cy - 10, Math.Max(40, w - 66 - 22 - mw - 12), StringAlignment.Near);
    p.Text(NotifBody(item), Ink.Callout, p.T.Sub, 66, cy + 10, w - 66 - 22, StringAlignment.Near);
    AddHit(new RectangleF(0, 0, w, h), "notifOpen", delegate { OpenNotifApp(item); });
}
```

---

## 6. Implementation Risk Analysis

1. **Compilation & Binary Breaking Changes**:
   - `Panel.Empty` and `Panel.Button` are retained as backward compatibility delegates. Any internal or external code calling `Empty(...)` or `Button(...)` will continue to compile and function seamlessly.
2. **Layout Geometry Regressions**:
   - `Parts.EmptyState` dynamically computes `(area.Height - block) / 2`. In short panel heights (e.g. 220px) or tall panels (380px), the content is always vertically centered with guaranteed bounds.
   - Using `p.TextBox` with `Ink.Callout` ensures multi-line Indonesian descriptions (such as clipboard policy details) wrap elegantly into 2 lines rather than getting truncated or overflowing.
3. **Typography Height Shifts**:
   - Substituting `Ink.Semi(15f)` with `Ink.Headline` (14.5px) and `Ink.Text(12.5f)` with `Ink.Callout` (12.5px) introduces < 0.5px differences, which are fully absorbed by GDI+ subpixel rounding and layout paddings.
4. **Radius Token Shifts**:
   - Migrating view outer shells from arbitrary 30/28/26 to `Ink.RadiusShell` (32px) standardizes the squircle silhouette to match macOS and Windows 11 Fluent shells.
   - Adjusting button and row hover radii from 10/14/16 to `Ink.RadiusControl` (12px) unifies the visual tactile feedback across all views.
