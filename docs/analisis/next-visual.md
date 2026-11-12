# Audit Visual & Design System — Tepi
> Analisis oleh Auditor Visual. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: Verifikasi kode terkini (commit `9f6f904`), hitung kontras WCAG, audit token. Tanggal: 2026-11-12.

## Ringkasan eksekutif
Audit visual menemukan bahwa perbaikan quick-win (`ad1c40f`, `9f6f904`) telah berhasil menaikkan kontras teks sekunder (`Faint`) ke 4,5:1 dan memperbaiki pemilihan warna aksen (`OnAccent`). Namun, konsistensi token masih menjadi masalah karena banyaknya penggunaan literal/hardcoded GDI+ (`103 Color.FromArgb`, `26 literal #hex`).

## Skor penilaian
| Dimensi | Skor | Status | Inti masalah |
|---|---|---|---|
| Kontras & Warna | 20/32 | Cukup | Masih ada penggunaan `Color.FromArgb` manual di luar `Ink.cs` |
| Tipografi & Spacing | 14/32 | Lemah | Scaling font masih ad-hoc, spacing jarang konsisten |
| Motion & Interaksi | 18/32 | Cukup | Masih ada animasi yang berdurasi tetap (tidak mengikuti system motion) |
| Native Windows Conformity | 16/32 | Cukup | Masih banyak owner-drawn yang belum menangani High Contrast/Dark Mode sistem secara otomatis |

## Temuan Baru (NVI-01..)

### NVI-01 · P2 · Konsistensi Warna (Literal Hardcoded)
- **Area**: Visual / Token
- **Bukti**: `src/DockPaint.cs:45`, `src/Island.cs:892` (literal hex/rgb)
- **Masalah**: Masih banyak warna yang didefinisikan manual (hardcoded) alih-alih merujuk ke `Ink.cs`.
- **Dampak**: Tema kustom tidak akan konsisten di seluruh bagian aplikasi (terutama Dock).
- **Perbaikan**: Pindahkan ke `Ink.cs` atau gunakan `p.T` (theme) yang tersedia.
- **Usaha**: S
- **Quick win**: Ya

### NVI-02 · P2 · Tipografi Ad-hoc
- **Area**: Visual / Tipografi
- **Bukti**: `src/Ink.cs:222-228` (banyak ukuran font 11f, 12f, 13f, 14.5f)
- **Masalah**: Terlalu banyak varian ukuran font yang tidak terstandardisasi (19 nilai ukuran px).
- **Dampak**: Hierarki visual menjadi tidak tegas.
- **Perbaikan**: Definisikan ulang skala tipografi (Type Scale) 5-6 varian saja.
- **Usaha**: M
- **Quick win**: Tidak

## Kandidat Patch
1. **Pembersihan warna hardcoded**: Ganti literal warna di `DockPaint.cs` dengan referensi `Ink.Base.Bg` atau `Ink.Base.Text`. (Usaha S)
2. **Standardisasi font**: Terapkan satu fungsi `Ink` untuk teks di `Panel.cs` guna menggantikan literal font size. (Usaha S)
3. **Peningkatan kontras pada elemen kecil**: Tambahkan `stroke` 1px untuk icon kecil di Dock agar lebih terbaca. (Usaha S)

## Yang sudah bagus
- `Ink.cs` sudah menjadi single source of truth untuk warna dan font.
- Kontras teks sekunder sudah diperbaiki di commit `ad1c40f`.
- Implementasi `OnAccent` yang sekarang berbasis WCAG, bukan heuristik luma.
