# Audit Aksesibilitas & Permukaan Sekunder — Tepi
> Analisis oleh Auditor A11y & Dock. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: Audit kode terkini (commit `9f6f904`). Tanggal: 2026-11-12.

## Ringkasan Eksekutif
Aksesibilitas masih menjadi titik terlemah dari Tepi. Karena UI yang bersifat *owner-drawn* (GDI+), integrasi dengan Windows UI Automation hampir tidak ada.

## Metrik Aksesibilitas
| Metrik | Nilai | Catatan |
|---|---|---|
| AccessibleName vs Target Klik | 53 / 82 | Sangat rendah |
| Penggunaan HighContrast/DPI | 0 | Belum ada deteksi sistem |
| Integrasi UIA | Terbatas | Hanya `RaiseAutomationNotification` |

## Temuan Baru (NAK-01..)

### NAK-01 · P1 · Ketiadaan Pohon UIA
- **Area**: Aksesibilitas
- **Bukti**: `src/A11y.cs:12-46`, `Island.cs:145-158` (OnPaint kosong).
- **Masalah**: Island tidak melaporkan struktur UI kepada Windows UI Automation.
- **Dampak**: Pembaca layar tidak dapat menavigasi isi panel.
- **Perbaikan**: Tambahkan `AccessibleObject` kustom untuk surface island.
- **Usaha**: L
- **Quick win**: Tidak

### NAK-02 · P2 · Inkonsistensi Dock
- **Area**: UX / Dock
- **Bukti**: `src/Dock*.cs` (kurang state hover/aktif yang jelas).
- **Masalah**: Dock kurang memberikan feedback visual yang seragam dibanding island.
- **Dampak**: Pengguna sulit membedakan ikon aplikasi yang berjalan.
- **Perbaikan**: Tambahkan indikator status (running/active) di ikon Dock.
- **Usaha**: S
- **Quick win**: Ya

## Kandidat Patch
1. **Perbaikan Kontras Fokus**: Terapkan cincin fokus dua warna pada tombol-tombol di Dock. (Usaha S)
2. **AccessibleName Tambahan**: Tambahkan `AccessibleName` pada 20 tombol utama yang paling sering dipakai. (Usaha S)
3. **Penyelarasan Icon Dock**: Tambahkan indikator status aplikasi aktif sederhana pada Dock. (Usaha S)

## Yang sudah bagus
- Sudah ada navigasi keyboard (`Ctrl+Alt+I`) yang cukup fungsional.
- Sudah ada Announce untuk notifikasi penting (via `Speak`).
