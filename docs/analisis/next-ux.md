# Audit UX — Tepi
> Analisis oleh Auditor UX. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: Verifikasi kode terkini (commit `9f6f904`). Tanggal: 2026-11-12.

## Ringkasan Eksekutif
Perbaikan terbaru di branch `fix/quick-wins-uiux` telah secara signifikan meningkatkan umpan balik sistem (khususnya notifikasi dan izin agen). Namun, tantangan utama tetap pada **discoverability** (penemuan fitur) dan **beban kognitif** pada konfigurasi default yang padat.

## Penilaian Nielsen (Heuristik)
- **Visibility of system status**: 3/4 (Perbaikan notifikasi & rapat membantu).
- **Match real world**: 3/4 (Pola island sudah akrab).
- **User control & freedom**: 2/4 (Masih minim fitur *undo* pada aksi-aksi destruktif).
- **Consistency & standards**: 2/4 (Masih banyak teks hardcoded).
- **Error prevention**: 2/4 (Masih ada catch senyap di beberapa jalur; lihat NUX-02 versi terkoreksi).

## Temuan Baru (NUX-01..)

### NUX-01 · P2 · Penemuan Fitur (Dock & Hotkey)
- **Area**: UX / Onboarding
- **Bukti**: `src/PrefsDock.cs` (Dock mati secara default), `src/Hotkeys.cs` (Pintasan tersembunyi).
- **Masalah**: Fitur utama seperti Dock tidak aktif secara default dan pengguna awam tidak tahu hotkey Tepi.
- **Dampak**: Pengguna tidak menggunakan fitur-fitur yang sudah dikembangkan dengan susah payah.
- **Perbaikan**: Tambahkan "Welcome Tour" singkat saat pertama kali dijalankan.
- **Usaha**: M
- **Quick win**: Tidak

### NUX-02 · P2 · Catch senyap (Error Handling)
- **Area**: UX / Error Recovery
- **Bukti (dikoreksi 2026-11-12)**: rujukan lama `src/Panel.cs:414-419` dan `src/Shots.cs:241-245` **tidak valid**.
  - `Panel.cs:414-419` adalah pemanggilan `Empty(...)` untuk teks empty-state, bukan `catch`. `Panel.cs` hanya punya satu `catch` (`:422`) dan sudah memakai `Log.Write`.
  - `Shots.cs:241-245` adalah `CopyRead`, dan `catch` di `:245` sudah memakai `Log.Write`. Dari 10 `catch` di `Shots.cs`, hanya `:144` yang senyap (hapus berkas sementara, sah).
  - Bukti yang benar, `catch` senyap yang menelan kegagalan nyata: `src/Dictate.cs:388` (`Clipboard.SetText` gagal → tetap melaporkan "Teks disalin"). Contoh lain: `src/Notifs.cs:53`, `src/ConvertView.cs:218`.
  - **Bukan cacat**: `src/Base.cs:51` adalah `catch` milik `Log.Write`. `src/DockKeys.cs:784-900` ada di `RaycastUsesWinKey` yang dipanggil periodik; `src/Quota.cs` adalah host `--statusline`. Menambah `Log.Write` di ketiganya salah: rekursi pada logger, dan I/O ekstra pada jalur periodik/one-shot.
- **Masalah**: Sebagian blok `catch` senyap menelan kegagalan yang seharusnya dilaporkan ke pengguna.
- **Dampak**: Pengguna tidak tahu mengapa suatu fitur tidak berfungsi (misal: teks tidak tersalin).
- **Perbaikan**: Hanya pada `catch` yang mengubah pesan sukses menjadi palsu: laporkan kegagalan, dan `Log.Write` untuk diagnosis. Jangan menyapu rata semua `catch` kosong.
- **Usaha**: S
- **Quick win**: Ya

## Kandidat Patch
1. **Toast Error**: Tambahkan toast sederhana di blok catch utama untuk memberikan feedback ke pengguna. Sudah diterapkan untuk `src/Dictate.cs:388`. (Usaha S)
2. **Aktifkan Dock/Fitur**: Tambahkan opsi untuk mengaktifkan Dock secara opsional saat onboarding. (Usaha S)
3. **Penyederhanaan Menu Klik Kanan**: Sederhanakan daftar menu yang terlalu panjang di `src/Island.cs`. (Usaha S)

## Yang sudah bagus
- Umpan balik untuk notifikasi sudah jauh lebih baik (status gagal muncul).
- Izin agen sekarang memiliki countdown yang jelas.
- Dialog rekaman rapat sekarang lebih aman terhadap kegagalan penulisan.
