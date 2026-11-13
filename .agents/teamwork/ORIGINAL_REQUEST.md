# Original User Request

## Initial Request — 2026-11-12T22:53:15Z

Lanjutkan dan implementasikan seluruh sisa perombakan antarmuka visual Tepi untuk kesiapan produksi (Milestones 2–5), dengan kustomisasi tampilan dan tema di Settings dibuat simpel menggunakan preset terkurasi modern ala macOS yang menarik dan konsisten.

Working directory: d:\PROJECT\Other\tepi
Integrity mode: development

Verification Resources: `docs/analisis/01-visual.md`, `docs/analisis/next-visual.md`, `build.cmd`, `TEST_INFRA.md`, `tests/`

## Requirements

### R1. UI Toolkit & Dialog Modernization (Milestone 2)
Implementasikan modernisasi UI Toolkit dan dialog (`src/Kit.cs`, `src/Menus.cs`, `src/TaskEditor.cs`, `src/ColorPicker.cs`, `src/Kulia.cs`, `src/Prefs.cs`):
- Tingkatkan kontras teks redup pada mode terang (`KitInk.Faint` mix dinaikkan dari 0.57 ke 0.65) dan kontras submenu serta item nonaktif pada `MenuLook` (`Sub` mix >= 0.62f).
- Sediakan status visual pressed dan focus ring yang kontras pada `KitButton`, status hover pada `KitSwitch`, kontras thumb nonaktif pada `KitSlider` (`KitInk.Disabled`), dan perbaiki kontras `KitRow.MarkGlyph`.
- Ganti seluruh warna merah hardcoded (`Color.IndianRed`, `Color.FromArgb(224, 96, 84)`) dengan token semantik `Ink.Base.Negative`.
- Sediakan mekanisme penyebaran tema terpusat untuk dialog (`KitWindow.BroadcastThemeChange()`).
- Perbaiki judul/lokalisasi pada `KitAsk`, refaktor `KuliaLogin` agar menggunakan `KitWindow` dan token `KitInk`, serta selaraskan loupe pada `ColorPicker` dengan token tema.
- Sediakan kustomisasi tampilan dan tema di Settings (`src/Prefs.cs`) berbasis preset terkurasi bergaya modern / macOS-like (pilihan preset palet aksen dan gaya visual yang bersih dengan kendali simpel tanpa kontrol/slider berlebih).

### R2. Island, Navigation & Views Polish (Milestone 3)
Tingkatkan polesan visual dan konsistensi pada Island, navigasi, dan tampilan (`src/Island.cs`, `src/Tabs.cs`, `src/Views.cs`, `src/Panel.cs`, `src/Parts.cs`, `src/WorkWindow.cs`):
- Terapkan `tone.OnGlass()` pada rendering teks di `src/Island.cs`, tambahkan bayangan elevasi halus (subtle elevation shadow) pada glass pill saat H <= 60, dan batasi breathing pulse halo persetujuan dengan `Anim.Reduced`.
- Perbaiki logika ternary status hover/pressed yang terbalik di `src/Tabs.cs` (`Pressed ? FillPressed : FillHover`).
- Selesaikan tabrakan teks meta pada notifikasi toast di `src/Views.cs`, satukan implementasi empty state (`Panel.Empty` ke `Parts.EmptyState`), serta standarisasi skala tipografi dan skala radius sudut (`RadiusShell/Module/Control`).

### R3. Dock & Mini Polish (Milestone 4)
Sempurnakan antarmuka Dock dan Mini (`src/DockPaint.cs`, `src/DockCard.cs`, `src/DockSheet.cs`, `src/DockCal.cs`, `src/Mini.cs`):
- Tokenisasi warna hardcoded pada Dock (`BadgeRed`, `BadgeRedSoft`, dan rim light) ke token tema `p.T.Negative`, `p.T.Highlight`, dan `p.T.Text`.
- Tambahkan penanganan status visual pressed pada tombol modul Dock (`DockCal.cs`).
- Tingkatkan kejelasan visual indikator Mini (radius titik notifikasi >= 2.5px dan pertebal track status).

### R4. Build & Verifikasi (Milestone 5)
Lakukan kompilasi bersih menggunakan `build.cmd` (`Tepi.exe`) dan pastikan seluruh test suite otomatis di `tests/` lulus tanpa regresi serta memenuhi panduan visual pada `docs/analisis/`.

## Acceptance Criteria

### UI Toolkit & Controls
- [ ] `KitInk.Faint` pada tema terang menghasilkan kontras teks yang memenuhi standar keterbacaan (mix 0.65).
- [ ] Kontras submenu dan item nonaktif pada `MenuLook` memenuhi ambang batas kontras minimum (`Sub` mix >= 0.62f).
- [ ] Seluruh kontrol `KitButton`, `KitSwitch`, `KitSlider`, dan `KitRow` merespons status interaktif (hover, pressed, focus ring, disabled) secara konsisten dengan token tema.
- [ ] Semua instans hardcoded semantic red digantikan dengan token semantik `Ink.Base.Negative`.
- [ ] Pergantian tema menyebar secara otomatis ke seluruh jendela dialog aktif via `KitWindow.BroadcastThemeChange()`.
- [ ] `KuliaLogin` menggunakan `KitWindow` dan token `KitInk`, judul `KitAsk` terlokalisasi, dan `ColorPicker` menggunakan token tema.
- [ ] Antarmuka kustomisasi tema di `Prefs.cs` menyajikan preset terkurasi modern ala macOS dengan kendali simpel tanpa kontrol/slider berlebih.

### Island & Views
- [ ] Teks sekunder pada `Island.cs` menggunakan `tone.OnGlass()` sehingga kontras tetap terjaga di atas glass.
- [ ] Pill glass (H <= 60) memiliki elevation shadow halus pada latar terang.
- [ ] Animasi halo pada Island menghormati pengaturan reduced motion (`Anim.Reduced`).
- [ ] Tab pada `Tabs.cs` merender state pressed (`FillPressed`) dan hover (`FillHover`) dengan benar.
- [ ] Teks meta pada toast notifikasi `Views.cs` tidak bertabrakan dengan judul notifikasi.
- [ ] Komponen empty state menggunakan `Parts.EmptyState` terpadu, dan radius sudut mematuhi skala `RadiusShell/Module/Control`.

### Dock & Mini
- [ ] Warna badge dan rim light pada Dock menggunakan token tema (`Negative`, `Highlight`, `Text`).
- [ ] Tombol pada modul `DockCal.cs` menampilkan umpan balik visual saat ditekan (pressed state).
- [ ] Titik notifikasi Mini memiliki radius minimal 2.5px dan track status dipertebal untuk visibilitas optimal.

### Build & Regresi
- [ ] Proyek terkompilasi bersih tanpa error melalui `build.cmd` menghasilkan `Tepi.exe`.
- [ ] Seluruh pengujian otomatis pada suite pengujian di `tests/` lulus 100% tanpa regresi.
