## 2026-11-12T14:54:21Z
Tingkatkan UI/UX dan tampilan visual antarmuka proyek Tepi untuk kesiapan produksi (production), mencakup seluruh komponen aplikasi (Island, Dock, Mini, Views/Panel, Settings, dan dialog) agar tampilan lebih konsisten, rapi, dan mudah dibaca.

Working directory: D:\PROJECT\Other\tepi
Integrity mode: development

## Verification Resources
- Panduan audit visual: `docs/analisis/01-visual.md` dan `docs/analisis/next-visual.md`
- Skrip build proyek: `build.cmd`

## Requirements

### R1. Peningkatan Kualitas Visual Antarmuka Keseluruhan
Tingkatkan tampilan visual dan cara aplikasi merender elemen UI pada seluruh komponen aplikasi Tepi (Island, Dock, Mini, Views/Panel, Settings, dan dialog). Tampilan antarmuka harus memiliki hierarki visual yang jelas, tata letak yang proporsional, dan rendering visual yang bersih serta bebas cacat visual.

### R2. Konsistensi Sistem Desain dan Token Visual
Terapkan standarisasi sistem desain di seluruh codebase dengan mengeliminasi nilai-nilai visual yang bersifat ad-hoc (seperti warna atau ukuran font yang didefinisikan secara hardcoded di luar sistem token). Seluruh elemen visual harus mengacu pada token visual terpusat yang konsisten untuk warna, kontras teks, hierarki tipografi, dan perlakuan tema.

### R3. Kepatuhan Kontras dan Keterbacaan
Pastikan kontras teks, ikon, dan elemen antarmuka memenuhi standar keterbacaan yang nyaman (minimal rasio kontras WCAG AA 4.5:1 untuk teks normal dan 3:1 untuk teks besar/komponen UI penting) baik pada tema terang maupun tema gelap.

### R4. Kestabilan Produksi dan Integritas Fungsional
Seluruh perubahan visual harus mempertahankan fungsi aplikasi yang sudah ada tanpa menimbulkan regresi fungsional, dan proyek harus dapat terkompilasi secara bersih.

## Acceptance Criteria

### Standar Visual dan Token Desain
- [ ] Tidak ada penggunaan warna atau font hardcoded baru di luar sistem token terpusat (`Ink.cs`).
- [ ] Masalah konsistensi warna literal dan tipografi ad-hoc yang tercatat pada `docs/analisis/next-visual.md` telah diselesaikan.
- [ ] Rasio kontras teks terhadap latar belakang di seluruh komponen antarmuka memenuhi standar minimal WCAG AA (4.5:1 untuk teks normal).

### Integritas Build dan Kestabilan
- [ ] Kompilasi proyek menggunakan `build.cmd` berhasil bersih tanpa error dan menghasilkan binary `Tepi.exe`.
- [ ] Seluruh fungsi interaksi antarmuka yang ada sebelumnya tetap berjalan normal tanpa regresi fungsional.


## 2026-11-12T22:54:39Z
Lanjutkan dan implementasikan seluruh sisa perombakan antarmuka visual Tepi untuk kesiapan produksi (Milestones 2–5), dengan kustomisasi tampilan dan tema di Settings dibuat simpel menggunakan preset terkurasi modern ala macOS yang menarik dan konsisten.

Working directory: d:\PROJECT\Other\tepi
Integrity mode: development

Verification Resources: `docs/analisis/01-visual.md`, `docs/analisis/next-visual.md`, `build.cmd`, `TEST_INFRA.md`, `tests/`

## Requirements
### R1. UI Toolkit & Dialog Modernization (Milestone 2)
### R2. Island, Navigation & Views Polish (Milestone 3)
### R3. Dock & Mini Polish (Milestone 4)
### R4. Build & Verifikasi (Milestone 5)
