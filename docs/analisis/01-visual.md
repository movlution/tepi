# Bahasa visual & design system — Tepi
> Analisis oleh Analis Visual / Design System. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: baca kode owner-drawn (Ink/Glass/Kit/Theme/Colors + views), ukur token & kontras WCAG numerik (skrip Python; asumsi ditulis), ukur render resmi di situs. Tanggal: 2026-11-12.

## Ringkasan eksekutif

Fondasi visual Tepi jauh di atas rata-rata aplikasi WinForms owner-drawn: token `Tone`/`Ink`, squircle 0.6, kaca yang membaca layar, spring, dan komponen native yang dibungkus ulang. Masalahnya bukan ketiadaan design system, melainkan **sistem yang setengah ditegakkan**: token jarak/radius/tipografi didokumentasikan lalu dilewati (0 pemakaian `Ink.Sp*`, `RadiusShell` mati, 417 ukuran font ad-hoc), dan **kontras tidak dijamin di material tersering**. Terukur: `Faint` tak pernah mencapai 4,5:1 (maks 2,96:1; 3,14:1 di render resmi) padahal membawa metadata 11px; **Frost** tanpa penjaga kontras menjatuhkan teks utama ke 2,79:1 di wallpaper terang; 2 dari 7 aksen preset bertinta 3,07:1; dan `OnGlass()` hanya dipakai Dock, bukan island. Tidak ada P0—visual tidak memblokir pemakaian—tetapi kombinasi realistis membuat teks sekunder sulit dibaca. Total 24 temuan: 8 P1, 10 P2, 6 P3.

## Skor / penilaian

| Dimensi | Skor | Alasan singkat |
|---|---|---|
| Hierarki | 2/4 | Panel jelas (judul 14,5–22px, kartu, baris), tetapi 10–12 tab berbobot sama dan ukuran teks per-layar. |
| Kontras | 1/4 | Utama lulus (teks 19:1, kartu terang 17,9:1); Faint ≤3:1, Frost 1,9–4,3:1, aksen preset 3,07:1. |
| Tipografi | 2/4 | Keluarga/fallback bagus; skala 7 peran dilewati 417 panggilan, 19 ukuran termasuk setengah piksel. |
| Spacing & radius | 2/4 | Skala 4–32 dan radius konsentris ada, tetapi 0 token jarak dipakai dan 21 radius literal di 166 `FillRound`. |
| State | 2/4 | Hover/press/squish island hidup; fokus keyboard bisa tak terlihat; KitButton tanpa pressed, KitSwitch tanpa hover. |
| Motion | 3/4 | Spring konsisten, "Kurangi gerak" di 59 titik; celah: halo izin berdenyut terus, 51 spring inline tanpa token. |
| Token & native | 2/4 | Token island nyata; tanpa kontras tinggi/teks besar, tanpa aksen Windows, tanpa Mica/Acrylic, radius 30 vs panduan 8. |
| Personalisasi | 2/4 | Kaya tetapi tanpa batas kontras; perlakuan gambar tidak seragam. |
| **Total** | **16/32** | Bahasa visual berkarakter; disiplin sistem dan jaminan keterbacaan belum. |

## Yang sudah bagus

1. **Lapisan token nyata.** `Tone`/`Ink` (`src/Ink.cs:35-84`) memisahkan bg/text/sub/faint/fill/line/accent/onAccent, punya pembanding kontras WCAG (`src/Colors.cs:104-114`), dan tema menimpa token, bukan per-widget. Di render resmi: teks **11,5:1**, sekunder **5,44:1**, ikon tab non-aktif **6,47:1** (`p-ringkasan.webp`).
2. **Umpan balik interaksi kelas atas.** Press-squish spring dengan tuning tahan/lepas (`src/Parts.cs:15,43-49`), state hover/pressed per kontrol (`src/Parts.cs:101-113`), cincin fokus hanya saat keyboard (`src/Kit.cs:140-147`, `src/Keyboard.cs:151-162`).
3. **"Kurangi gerak" benar-benar dipakai.** 59 guard `Anim.Reduced` menyentuh mata, lirik, flyer, morph tab, minimasi, fade jendela (`src/Base.cs:230-260`)—jarang ada di aplikasi sejenis.
4. **Kerajinan permukaan.** Squircle figma (`src/Ink.cs:394-431`), bayangan 9-slice + rim + inner light (`src/Island.cs:1016-1134`), DWM dark frame + warna caption/border (`src/Native.cs:133-155`), sampul album monokrom (`src/Ink.cs:557-582`).

## 10 prioritas utama

| ID | Sev | Judul | Usaha | Quick win |
|---|---|---|---|---|
| VIS-01 | P1 | Faint tak pernah lolos 4,5:1 tetapi membawa metadata 11px | S | ya |
| VIS-02 | P1 | Frost tanpa penjaga kontras: teks utama <3:1 di wallpaper terang | M | tidak |
| VIS-03 | P1 | `OnGlass()` 74% hanya dipakai Dock, tidak dipakai island | S | ya |
| VIS-04 | P1 | Penjaga Liquid salah ruang warna: tema terang tetap 3,8:1 | M | tidak |
| VIS-05 | P1 | 2/7 aksen preset bertinta 3,07:1; aksen tema terang <3:1 | S | ya |
| VIS-06 | P1 | Warna sendiri & paket tema tanpa batas kontras (1,26:1) | M | tidak |
| VIS-07 | P1 | Tanpa mode kontras tinggi & teks besar Windows | M | tidak |
| VIS-08 | P1 | Cincin fokus keyboard tak terlihat di kontrol beraksen | S | ya |
| VIS-09 | P2 | Skala 7 peran dilewati 417 panggilan, 19 ukuran | M | tidak |
| VIS-10 | P2 | Token spacing/radius nol dipakai; 21 radius literal | M | tidak |

## Temuan detail

### [P1] VIS-01 — Faint tidak pernah lolos 4,5:1, tapi dipakai untuk teks 11px
- **Area**: Kontras / tipografi.
- **Bukti**: `src/Ink.cs:42` (`Faint = FromArgb(92,245,245,247)`) dan `src/Ink.cs:78` (tema terang). Komposit 36% di atas hitam → `#585859`, **2,96:1** (maksimum teoretis; di atas putih 1,03:1). Render panel resmi (`p-bicara.webp`, bg `#252527`) terukur `#717173` = **3,14:1**. Dipakai metadata 11px: `src/Suara.cs:181-186`, `src/Panel.cs:255`, `src/Schedule.cs:210`, `src/Clips.cs:141`, `src/Overview.cs:569`. 68 referensi Faint di `src/`.
- **Masalah**: Waktu, sumber, dan detail dibaca di bawah 4,5:1 WCAG AA normal text; tema terang 2,37:1.
- **Dampak**: Detail penting (umur pesan, ruang kelas, asal tugas) hilang saat layar redup atau di luar ruangan.
- **Perbaikan**: Naikkan alpha Faint ke ≥140 (≈4,6:1 di hitam) **atau** larang Faint untuk teks <12px dan alihkan ke Sub; tambah tes kontras semua pasangan token × material.
- **Usaha**: S. **Quick win**: ya.

### [P1] VIS-02 — Frost tanpa penjaga kontras; teks utama bisa <3:1
- **Area**: Kontras / material.
- **Bukti**: `src/Glass.cs:69` (`BaseTint=0,42`), `src/Glass.cs:327` menint saja; `LiquidPass` punya guard (`Glass.cs:383-427`), Frost tidak. Asumsi wallpaper putih: panel = 255×(1−0,42)×(1−0,224) = **`#737373`**, pil = `#949494`. Terukur: panel Text **4,35:1**, Sub **2,72:1**, Faint 1,86:1; pil Text **2,79:1**. Tema terang di wallpaper hitam: pil Text 3,46:1, Sub 2,36:1.
- **Masalah**: "Frost" material alternatif resmi (`docs/paket-tema.md`) tetapi satu-satunya tanpa jaring pengaman keterbacaan.
- **Dampak**: Di wallpaper terang/cerah (foto, PowerPoint, situs putih) island jadi abu-abu dengan teks pudar—persis kondisi notifikasi paling dibutuhkan.
- **Perbaikan**: Terapkan varian `LiquidPass` tanpa saturasi pada jalur frost (tint adaptif per-piksel berdasarkan backdrop), atau turunkan `BaseTint` dengan kompensasi alpha teks; uji matriks wallpaper {hitam, abu, putih} × material.
- **Usaha**: M. **Quick win**: tidak.

### [P1] VIS-03 — Perbaikan kontras `OnGlass()` tidak dipakai di island
- **Area**: Kontras / glass.
- **Bukti**: `src/Ink.cs:28-33` menaikkan alpha Sub ke ≥189 (74%) dengan komentar "secondary text at 74% keeps 4.5:1"; pemakaian hanya `src/DockPaint.cs:35`, `src/DockCard.cs:343`, `src/DockSheet.cs:241`. Island memakai `Ink.Base` langsung (`src/Island.cs:805,846,1244`).
- **Masalah**: Material dan masalah sama ditangani di Dock, tidak di permukaan utama yang lebih sering di atas wallpaper.
- **Dampak**: Teks sekunder island lebih lemah dari Dock; pengguna melihat dua standar keterbacaan di satu produk.
- **Perbaikan**: Pakai `tone.OnGlass()` saat `GlassOn` di `Render`/`DrawContent`, atau satukan jadi satu `Tone.ForSurface(material, wallpaperLuma)`.
- **Usaha**: S. **Quick win**: ya.

### [P1] VIS-04 — Penjaga Liquid dihitung linear tetapi diterapkan di sRGB
- **Area**: Kontras / material.
- **Bukti**: `src/Glass.cs:389-390` menargetkan "light text L≤0,09, dark L≥0,62"; alpha dihitung dari luminance linear (`Glass.cs:413-418`) tetapi diterapkan pada kanal sRGB (`Glass.cs:419-421`). Hitungan: tema terang di wallpaper hitam → permukaan `#A6A6A6` (L=0,38, bukan ≥0,62); Sub **3,81:1** (gagal). Tema gelap di wallpaper putih menabrak `aMax=0,9` → `#191919`, hampir legap sehingga efek kaca hilang.
- **Masalah**: Guard hanya "setengah benar": tema terang kurang gelap, tema gelap terlalu gelap; klaim "kaca menyesuaikan terang latar" (situs resmi) tidak merata.
- **Dampak**: Pengguna tema terang di wallpaper gelap tetap gagal baca; pengguna tema gelap kehilangan karakter liquid di wallpaper terang.
- **Perbaikan**: Selesaikan alpha di ruang linear (kanal→linear, campur, konversi balik) atau kalibrasi ulang `limit` dengan LUT; uji 5 wallpaper acuan.
- **Usaha**: M. **Quick win**: tidak.

### [P1] VIS-05 — Aksen preset: 2 dari 7 bertinta 3,07:1
- **Area**: Kontras / personalisasi.
- **Bukti**: `src/Ink.cs:146-153` memilih `OnAccent` dengan heuristik luma `>150`, bukan kontras WCAG (bandingkan `src/Colors.cs:82`). Preset di `src/Prefs.cs:175-179`. Terukur: **Biru `#4C8DFF` → tinta `#FAFAFA` 3,07:1** (pilihan WCAG terbaik: tinta gelap 6,19:1); **Navy `#7F8DC6` 3,08:1** (terbaik 6,15:1). Sebagai elemen grafis di tema terang (`#F5F5F5`): Kuning 1,32:1, Hijau 1,72:1, Biru 2,94:1 (butuh 3:1).
- **Masalah**: Label pil/tab/countdown 10,5–13px di atas aksen; dua warna "aman" justru gagal 4,5:1, dan aksen sebagai garis progres/ikon di tema terang gagal 3:1.
- **Dampak**: Tab aktif berlabel dan tombol primer sulit dibaca; indikator progres samar di tema terang.
- **Perbaikan**: Ganti heuristik `Ink.cs:152` dengan `Colors.Contrast(accent, kandidat)` (pilih maksimum); tambahkan `OnAccent` per preset dan uji aksen terhadap bg gelap **dan** terang.
- **Usaha**: S. **Quick win**: ya.

### [P1] VIS-06 — "Warna sendiri" dan paket tema tanpa batas kontras
- **Area**: Kontras / personalisasi.
- **Bukti**: `src/Colors.cs:69-95` menurunkan palet tanpa memeriksa kontras text/sub/faint; hanya `card.accent` dikoreksi (`Colors.cs:84`). `src/Prefs.cs:825-830` hanya menampilkan peringatan teks untuk text/bg, tanpa menolak/mengoreksi sub/faint/aksen. Paket menerima `#RRGGBB` apa pun (`src/Ink.cs:103-123`), kunci invalid dilewati diam-diam (`Ink.cs:126-135`). Contoh: bg `#222222` + text `#333333` → **1,26:1**; preset "Putih"/"Krem" untuk bg tersedia berdampingan dengan "Putih" untuk teks (`src/Prefs.cs:806-813`).
- **Masalah**: Fitur personalisasi paling menonjol bisa membuat island tak terbaca, dengan umpan balik hanya satu baris kecil.
- **Dampak**: Pengguna mengira Tepi rusak setelah memilih warna; paket pihak ketiga dapat menghancurkan keterbacaan tanpa peringatan.
- **Perbaikan**: Setelah `DerivePalette`, paksa ladder kontras (text ≥7:1, sub ≥4,5:1, faint ≥3:1) dengan menggeser luminance; tandai paket gagal di UI + tombol "Perbaiki otomatis".
- **Usaha**: M. **Quick win**: tidak.

### [P1] VIS-07 — Tanpa mode kontras tinggi & teks besar Windows
- **Area**: Aksesibilitas visual / native.
- **Bukti**: Pencarian `HighContrast|SystemColors|UISettings` di 144 file `src/` → 0 hasil; pembacaan sistem hanya `GetDpiForWindow/GetDpiForSystem` (`src/Kit.cs:631,688`) dan `WM_DPICHANGED` (`src/Kit.cs:664-675`). Semua ukuran teks konstanta px (`src/Ink.cs:227-233`) + 417 panggilan ad-hoc; skala teks aksesibilitas Windows tidak dibaca.
- **Masalah**: Persona pengguna aksesibilitas (brief §2.4) tidak terlayani: kontras tinggi Windows tidak mengubah apa pun, "Perbesar teks" tidak memperbesar teks island.
- **Dampak**: Pengguna low-vision harus memakai pembesaran layar; island tetap kecil dan kontrasnya menurut token Tepi.
- **Perbaikan**: Deteksi `SystemInformation.HighContrast` → paksa Hitam/putih, garis 2px, matikan kaca; tambah `look.scale` (0,9–1,3) yang mengalikan semua `Ink.*(px)` lewat satu helper.
- **Usaha**: M. **Quick win**: tidak.

### [P1] VIS-08 — Cincin fokus keyboard tak terlihat di kontrol beraksen
- **Area**: State / aksesibilitas visual.
- **Bukti**: `src/Keyboard.cs:151-162` menggambar `StrokeRound(r, ..., p.T.Accent, 2f)`. Tab aktif mengisi pil yang sama dengan `p.T.Accent` (`src/Tabs.cs:526`); pil primer (`src/Parts.cs:190-194`) dan `CircleToggle` aktif (`src/Parts.cs:171-176`) juga. Fokus = cincin warna sama di atas warna sama.
- **Masalah**: Navigasi keyboard (Ctrl+Alt+I) tidak menunjukkan posisi saat berhenti di kontrol beraksen—kontrol yang paling mungkin difokus.
- **Dampak**: Pengguna keyboard-only kehilangan jejak; pelanggaran WCAG 2.4.7 pada subset kontrol.
- **Perbaikan**: Cincin dengan warna kontras terhadap isi (Flip.Bg/putih/hitam + outline 1px), atau teknik inset 2px + outline 1px seperti Fluent; uji semua kombinasi aksen.
- **Usaha**: S. **Quick win**: ya.

### [P2] VIS-09 — Skala tipografi ada, tetapi dilewati hampir seluruhnya
- **Area**: Tipografi.
- **Bukti**: Skala 7 peran di `src/Ink.cs:227-233` (Hero 40, Title1 22, Title2 17, Headline 14,5, Body 13,5, Callout 12,5, Caption 11). Terukur: 417 panggilan `Ink.<role>(px)` dengan **19 ukuran**—10; 10,5; 11; 11,5; 12; 12,5; 13; 13,5; 14; 14,5; 15; 15,5; 17; 18; 20; 22; 26; 34; 44—termasuk 9 panggilan 10,5px dan 41 panggilan 11,5px; peran bernama hanya 46 kali. Contoh: `src/Panel.cs:356-357`, `src/Views.cs:212`, `src/Kit.cs:561-562`, `src/Tour.cs:243-246`.
- **Masalah**: Tidak ada ritme tipe yang bisa diprediksi; ukuran setengah piksel sulit dibedakan tetapi menggeser garis dasar.
- **Dampak**: Panel terasa "hampir rapi" tetapi tidak konsisten; setiap fitur baru menambah ukuran baru.
- **Perbaikan**: Bekukan 7 peran + maks 2 ukuran khusus; migrasi bertahap per layar; grep/tes CI menolak angka baru.
- **Usaha**: M. **Quick win**: tidak.

### [P2] VIS-10 — Token spacing/radius dideklarasikan tetapi nol dipakai
- **Area**: Spacing / token.
- **Bukti**: `src/Ink.cs:183-188` mendefinisikan `Sp4…Sp32`, `RadiusShell/Module/Control`, `ModuleInset/Gap/Pad`. Terukur: `Ink.Sp*` **0 pemakaian**, `RadiusShell` **0**, `RadiusModule/Control` 15, sementara 166 `FillRound` memakai **21 radius literal** (1; 1,5; 2; 2,5; 5; 6; 7; 8; 9; 10; 10,5; 11; 12; 13; 14; 15; 16; 18; 20; 22) dan 377 literal px berskala.
- **Masalah**: Klaim "concentric radii: shell, module, control" (`Ink.cs:186`) tidak benar dalam praktik: shell yang dipakai 30 (`src/Views.cs:66`), bukan 32; kartu 26; kontrol 10–16.
- **Dampak**: Sudut dan jarak antar-layar tidak seragam, mempercepat drift desain dan menyulitkan kontributor.
- **Perbaikan**: Hapus atau pakai token mati; sediakan `Ink.R(role)`/`Ink.Gap(n)`; migrasi view per view + screenshot diff.
- **Usaha**: M. **Quick win**: tidak.

## Temuan ringkas lanjutan

| ID | Sev | Area | Bukti | Masalah → perbaikan | Usaha | QW |
|---|---|---|---|---|---|---|
| VIS-11 | P2 | State komponen | `src/Kit.cs:398-418,164-210,356-359,548-570` | KitButton tanpa pressed, KitSwitch tanpa hover, thumb slider tetap `Text` saat disabled, KitRow tanpa hover — samakan dengan state island. | S | ya |
| VIS-12 | P2 | Motion | 51 `new Spring(`, 24 pasangan K/D (K=60…900), preset `Ink.cs:656-673` dipakai 4×; `src/Island.cs:1139-1151` halo izin `sin()` tanpa cek `Anim.Reduced` | Motion tanpa token + satu animasi abai "Kurangi gerak" — tambah `Motion.*` dan guard di DrawGlow. | S | ya |
| VIS-13 | P2 | Motion | `src/Kit.cs:170-184,648-655`, `src/Tour.cs:103,205`; ~20 durasi tangan 0,14–1,6 dtk | Dua mesin gerak (spring vs timer-lerp); switch 75ms terasa patah — satukan + token durasi. | S | ya |
| VIS-14 | P2 | Native | `src/Native.cs:133-155`, tanpa atribut 38/Mica; kaca = capture layar; radius 30 (`src/Views.cs:66`) vs Windows 11 8px | Sengaja iOS-like; biaya: terasa bukan bagian Windows 11, tak pakai material hemat daya — dokumentasikan + opsi "ikut Windows". | M | tidak |
| VIS-15 | P2 | Tipografi | `src/Ink.cs:209` (`"…Small Semibol"`); `src/Menus.cs:105` 9,5pt vs Kit 13,5px; `src/ColorPicker.cs:190` 10pt lepas token | Caption-semibold fallback senyap; menu lebih kecil dari body; picker beda unit — perbaiki ejaan, satukan ke `families[]`+px. | S | ya |
| VIS-16 | P2 | Personalisasi | `src/Ink.cs:557-582` vs `src/Theme.cs:455-480,483-509,566-577` | Sampul ditundukkan token, lambang/maskot/knob bebas warna — sediakan mode tonal atau pandu kontras di docs paket. | M | tidak |
| VIS-17 | P2 | Ikonografi | `src/Tabs.cs:725-787` + Fluent (`src/Ink.cs:171-176`), `"★/☆"` (`src/WorkWindow.cs:591`), glyph PUA (`src/Prefs.cs:685`) | Tiga bahasa ikon dalam satu tab bar; PUA bisa tofu bila font absen — standarkan satu set vektor. | M | tidak |
| VIS-18 | P3 | Tema/paket | `src/Ink.cs:103-123,126-135`; `docs/paket-tema.md:11-31` | Kunci invalid dilewati diam-diam — tampilkan kunci ditolak di Pengaturan › Paket. | S | ya |
| VIS-19 | P3 | Empty state | `src/Panel.cs:13-20` vs `src/Parts.cs:374-387` | Dua implementasi dengan padding/tipe berbeda — satukan ke `EmptyState`. | S | ya |
| VIS-20 | P3 | Copy visual | `src/Prefs.cs:963` (`"Liquid"`, `"Frost"`, `"Hitam"`) | Campur istilah Inggris/Indonesia di satu kontrol — pilih satu istilah per konsep. | S | ya |
| VIS-21 | P3 | Ukuran target | `src/Mini.cs:15` (56×6 / 40×14), `src/Tabs.cs:626` (dot 3,2px), `:409` (TabH 28) | Target visual kecil meski hit area lebih besar — dot ≥4px, label hover, atau TabH 32. | S | ya |
| VIS-22 | P3 | Onboarding | `src/Tour.cs:239` + `285-294` | Progres tampil dua kali — pilih satu. | S | ya |
| VIS-23 | P3 | Elevasi | `src/Island.cs:815-821` vs panel berbayangan | Elevasi berubah saat kaca aktif; pil terasa ditempel di wallpaper terang — tambah bayangan tipis. | S | ya |
| VIS-24 | P3 | Toast | `src/Views.cs:27`, `src/Views.cs:741` | Nama aplikasi panjang + "N pesan" terpotong — perlebar dinamis atau ringkas meta. | S | ya |

## Pertanyaan terbuka / yang perlu diverifikasi

1. **Kontrak kontras: 4,5:1 untuk semua teks, atau Faint dekoratif?** Menentukan apakah VIS-01 diperbaiki di token (68 pemakaian berubah) atau hanya pemakaian <12px.
2. **Seberapa sering "wallpaper terang + Frost gelap" terjadi?** Tidak bisa memotret island live (excluded from capture); butuh `TEPI_DUMP` dari Lead. *Perlu verifikasi.*
3. **Masih layakkah Liquid disebut "kaca" saat wallpaper putih memaksa alpha 0,90?** Kejar kontras (VIS-04) atau pertahankan transparansi dengan menggeser beban ke tinta.
4. **Bagaimana perilaku mode kontras tinggi Windows di window owner-drawn ini?** Hipotesis: tidak berubah karena semua warna dari token — perlu uji.
5. **Siapa prioritas aksen saat beberapa sumber aktif** (Windows accent, wallpaper sync, album, preset)? Urutan diterapkan di `Ink.Apply`/`WallApply` tetapi tidak terdokumentasi.

## Lintas area (bukan analisis mendalam)

- **UX (02)**: Tur 9 langkah dan empty state menuntun, tetapi discoverability klik-kanan/hover tetap masalah utama onboarding.
- **Teknis (04)**: 51 spring inline + 49 timer membuat state animasi sulit diuji; VIS-09/10/12 adalah gejala sistem yang sama.
- **Riset (05)**: Aset promosi situs mengekspor island tanpa backdrop (alpha), sehingga kontras material tidak bisa dinilai dari situs—hanya dari kode.
