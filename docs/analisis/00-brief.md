# Brief Analisis UI/UX & Fungsi — Tepi

Dokumen ini adalah kontrak kerja bersama untuk tim analisis. Baca seluruh brief ini sebelum membaca source atau menulis temuan.

## 1. Fakta proyek

- **Produk**: Tepi — dynamic island untuk Windows. Overlay di tepi atas layar (bisa dipindah ke pojok/sisi), berubah ukuran jadi panel dengan ~10 tab, ditambah Dock pengganti taskbar, Mini (sliver tembus klik + mata), dan aplikasi companion Tepi Android.
- **Repo lokal**: `D:\PROJECT\Other\tepi` (origin: `movlution/tepi`, upstream: `odlaver/tepi`).
- **Bahasa/framework**: C# 5/.NET Framework 4.8, WinForms, owner-drawn (semua UI digambar manual lewat GDI+), tanpa NuGet, tanpa browser engine.
- **Build**: `build.cmd` memanggil `csc.exe` bawaan Windows dengan `/target:winexe /optimize+ /platform:x64`, source `src\*.cs` wildcard. CI: `.github/workflows/build.yml` hanya build + hash + upload artifact.
- **Source**: 144 file `.cs`, ±52.000 baris, semuanya namespace `Tepi`; hampir semua file adalah `partial class Island` (Island.cs saja 89 KB). File terbesar: Lang.cs 114 KB, Prefs.cs 112 KB, Island.cs 90 KB, Converter.cs 61 KB, SuruhChat.cs 60 KB.
- **Download**: `Tepi.exe` ±1,7 MB, belum code-signed (SmartScreen warning), update mandiri dari GitHub Releases.
- **Dokumentasi**: `README.md` (98 baris) + `docs/*.md` (10 file; `docs/fitur.md` = inventaris fitur terlengkap; `docs/pengaturan.md` = 143 kunci `settings.ini`).
- **Pengukuran yang sudah dilakukan Lead**: source ter-build bersih (build OK, 1.727.000 byte), app sedang berjalan (PID 41828), layar 1920x1080. WinRT APIs, P/Invoke 312 deklarasi, 438 `catch`, 109 catch kosong, 1.627 entri kamus `Lang`, 1.667 panggilan `Lang.T`, 103 `Color.FromArgb`, 26 literal `#hex`, 3 timer WinForms.
- **Lingkungan**: Windows 10.0.28120 (Windows 11), DPI aware (`SetProcessDpiAwarenessContext(-4)`), single instance mutex, opsi `capture.show` default **mati** (island tidak ikut screenshot/recording).
- **Catatan**: screenshot live island tidak bisa diambil (WDA_EXCLUDEFROMCAPTURE); jangan buang waktu mencoba. Bukti visual pakai situs resmi (https://odlaver.github.io/tepi/) dan aset tema, atau kode.

## 2. Pengguna & persona

1. **Mahasiswa/pekerja Indonesia (persona utama)**: pakai Kulia/tugas, jadwal kuliah, WhatsApp, rekam rapat, pengingat sholat. Tidak ingin ribet; ingin informasi sekilas tanpa pindah jendela.
2. **Developer power user**: Claude Code/Codex/Copilot tiap hari, jawab izin agent, cek kuota, ganti taskbar dengan Dock, navigasi keyboard.
3. **Pengguna baru/awam**: unduh exe, kena SmartScreen, tidak tahu island di-hover, tidak tahu klik kanan, tidak tahu pintasan. Butuh first-run yang menuntun.
4. **Pengguna aksesibilitas**: screen reader (Narrator/NVDA), keyboard-only, "Kurangi gerak", kontras tinggi, teks besar.
5. **Pengguna companion HP**: pairing Tepi Android (QR), OTP, notifikasi, kirim berkas.
6. **Laptop kantor/IT**: exe unsigned, API key tersimpan lokal, tidak mau telemetry, minta jejak jaringan jelas.

## 3. Ruang lingkup tiap analis (tidak boleh tumpang tindih kepemilikan file)

| File output | Fokus |
|---|---|
| `docs/analisis/01-visual.md` | Bahasa visual, token warna/tipografi/spacing/motion, kualitas komponen owner-drawn, tema & personalisasi, kesesuaian Windows/native, kontras terukur |
| `docs/analisis/02-ux.md` | Alur & IA, onboarding/discoverability, beban kognitif, Pengaturan, navigasi keyboard, copy & i18n UX, feedback/error/empty states, aksesibilitas UIA |
| `docs/analisis/03-fungsi.md` | Kelengkapan & keandalan tiap fitur, integrasi, failure mode, performa pemakaian, privasi/keamanan sisi pengguna, celah fitur fungsional |
| `docs/analisis/04-teknis.md` | Arsitektur & maintainability, infrastruktur i18n/settings, build/test/CI/release engineering, observability, drift dokumentasi, aksesibilitas arsitektural |
| `docs/analisis/05-riset.md` | Riset eksternal: issue/release upstream & fork, keluhan pengguna nyata, situs resmi, pembanding produk dynamic-island/notch, peluang fitur berbasis permintaan pasar |

Batas: **jangan edit `src/` sama sekali**. Hanya tulis file output milikmu. Jangan commit, jangan push, jangan ubah `settings.ini` milik pengguna, jangan kendalikan mouse/keyboard, jangan jalankan instance Tepi kedua, jangan jalankan `build.cmd` (Lead sudah verifikasi build; menghindari rebutan file).
Read-only yang boleh: baca file, grep, PowerShell untuk ukur proses berjalan (CPU/RAM/handle), hitung metrik, unduh halaman/aset situs, `gh api` read-only.

## 4. Format temuan (WAJIB, bahasa Indonesia)

Setiap temuan punya ID unik: `VIS-01`, `UX-01`, `FUN-01`, `TEK-01`, `RIS-01`.

```
### [P?] Judul singkat
- **Area**: Visual / Motion / Navigasi / Pengaturan / Integrasi / Performa / Privasi / Build / dll.
- **Bukti**: `src/File.cs:123-145` (kode), hasil ukur, atau screenshot/sumber URL.
- **Masalah**: apa yang salah, untuk siapa, dalam kondisi apa.
- **Dampak**: konsekuensi nyata ke pengguna (bukan teori).
- **Perbaikan**: langkah konkret, sebut file/fungsi yang disentuh.
- **Usaha**: S / M / L (S ≤ 1 hari, M = 2-5 hari, L > 1 minggu).
- **Quick win**: ya/tidak.
```

Aturan bukti:
- **Setiap klaim teknis harus punya rujukan `file:line` atau hasil ukur/URL.** Jangan mengarang nomor baris. Kalau ragu, tulis "perlu verifikasi" dan jelaskan cara verifikasinya.
- Bedakan **fakta** (terbaca di kode/ukur) vs **hipotesis** (tandai "hipotesis").
- Jangan menulis rekomendasi generik ("buat desain lebih baik", "tambah dark mode"). Harus spesifik ke Tepi dan bisa dieksekusi.
- Sebutkan juga **yang sudah bagus** (2-4 hal) supaya laporan seimbang.

## 5. Rubrik severity

- **P0 — Blocking/berbahaya**: bikin fitur tidak bisa dipakai, kehilangan data, kebocoran privasi/keamanan, atau merusak taskbar/OS.
- **P1 — Major**: friksi besar, fitur utama sering gagal, pelanggaran aksesibilitas serius, inkonsistensi mencolok yang membingungkan.
- **P2 — Minor**: mengganggu tapi ada workaround; ineffisiensi; polish yang terasa.
- **P3 — Polish**: kosmetik/ide bagus, dampak kecil.

Target per file: **minimal 20 temuan** (boleh lebih; prioritaskan kualitas), dengan **10 teratas dibahas detail** dan sisanya tabel ringkas. Maksimum ±2.500 kata per file. Jangan menyalin isi `docs/` mentah-mentah.

## 6. Rubrik penilaian yang dipakai

**UX (Nielsen 10 heuristics, skor 0-4)**: visibility status, match real world, user control, consistency, error prevention, recognition vs recall, flexibility/efficiency, aesthetic-minimalist, error recovery, help/documentation. Beri skor + alasan singkat + total /40.

**Visual**: hierarchy, contrast (ukur WCAG: teks ≥4.5:1, teks besar ≥3:1, UI/ikon ≥3:1), spacing rhythm, typography scale & fallback font, state design (hover/pressed/focus/disabled/empty/loading/error), motion (durasi/easing/reduced-motion), design token coverage, native Windows conformance (Fluent, DPI, multi-monitor, high contrast, taskbar replacement).

**Fungsi**: kelengkapan vs dokumen, keandalan/failure mode, degradasi tanpa jaringan/tanpa dependensi (ffmpeg/LibreOffice/Word), integritas data, privasi/keamanan, performa, update/instalasi.

**Teknis**: seams & testability, duplikasi, kompleksitas, observability, build/release, i18n, settings schema, drift dokumen, risiko regresi.

## 7. Pertanyaan kunci yang harus dijawab area masing-masing

**Visual (01)**:
- Apakah token warna (`Ink.cs`, `Colors.cs`, `Theme.cs`) konsisten dan kontrasnya lolos? Ukur pasangan teks/latar untuk tema gelap+terang, 3 material (Glass/Frost/Hitam pekat), dan aksen pilihan pengguna.
- Tipografi: font apa, berapa ukuran dipakai, ada hierarki? Bagaimana teks Indonesia vs Inggris (rata-rata +30% panjang) di panel sempit?
- Motion: berapa spring/timer, apakah "Kurangi gerak" benar-benar mematikan semua? Ada animasi yang mengganggu/menunda baca?
- Komponen `Kit.cs`: switch, segmented, slider, field, list item — apakah state hover/focus/disabled/error lengkap dan seragam? Fokus keyboard terlihat?
- Personalisasi: tema pack, emblem, mata, wallpaper sync — apakah menambah karakter atau malah mengacak konsistensi?
- Konformitas Windows 11: Fluent/Mica/Acrylic, radius, ikon, DPI/multi-monitor, high-contrast mode, taskbar replacement.

**UX (02)**:
- Hitung langkah untuk task kunci (jawab izin agent, kirim berkas ke HP, dikte, ubah format, buat pengingat, buka kelas, simpan catatan) dari kondisi idle. Di mana friksinya?
- Discoverability: fitur tersembunyi (klik kanan, hover, drag target, 10 tab, Dock, shortcut). Pengguna baru tahu dari mana? Cek `Tour.cs`, `WhatsNew.cs`, empty state.
- IA: 10 tab + Dock + Start + Pengaturan 8 halaman + 143 setelan. Terlalu banyak? Apa yang harus dicari/dipermudah? Cek apakah ada pencarian setelan.
- Onboarding: default aman? Tur 9 langkah — apakah memaksa, bisa di-skip, bisa diulang? SmartScreen + tray icon + tidak tahu hover = activation gagal di mana?
- Feedback & recovery: toast, undo, konfirmasi destruktif, error message konkret? Cek 109 catch kosong = user tidak pernah tahu saat gagal.
- Aksesibilitas: UIA tree owner-drawn (A11y.cs hanya RaiseAutomationNotification), fokus keyboard, target size, kontras, reduced motion, skala teks Windows.
- Copy/i18n: 1.627 entri `Lang`, apakah ada teks hardcoded tak diterjemahkan? Nada bahasa konsisten? Istilah campur ID/EN (Dock, Start, toast) membingungkan?

**Fungsi (03)**:
- Inventaris semua fitur dari `docs/fitur.md`, nilai kesiapan (matang/rapuh/eksperimental). Fitur mana yang paling berdampak kalau ditingkatkan?
- Integrasi (`Sources.cs`, `Kulia.cs`, `Notion.cs`, `Todoist.cs`, `Ics.cs`, `Ai.cs`, `Phone.cs`, `Handset.cs`, `Agents.cs`, `Quota.cs`, `Media.cs`, `Music.cs`, `Lyrics.cs`, `Weather.cs`, `Update.cs`): autentikasi, retry/timeout, rate limit, data cache, error surface, offline.
- Failure mode: internet putus, API key salah, token kedaluwarsa, dependency tidak ada, folder tidak bisa ditulis, berkas terkunci, agent mati di tengah izin, HP terputus.
- Performa pemakaian: ukur proses berjalan (CPU %, working set, private bytes, handle, GDI objects, thread) saat idle dan bandingkan `docs/performa.md`. Cari timer/polling yang boros (grep interval).
- Privasi/keamanan sisi pengguna: API key di `settings.ini` (plaintext?), endpoint HTTP/TLS, port bridge agent (`agent.port`, `agent.token`), pairing HP (QR/TLS), OTP di clipboard, log berisi data sensitif, `capture.show` default, update tanpa signature.
- Celah fitur: apa yang pengguna wajar harapkan tapi belum ada (mis. jadwal senyap, sinkron antar-perangkat, backup/restore setelan, plugin, multi-monitor island, integrasi kalender tulis, quick search universal)?
- Ketergantungan eksternal: ffmpeg, LibreOffice, Word, OCR, whisper.cpp — bagaimana pesan saat tidak ada? Apakah kegagalan dijelaskan?

**Teknis (04)**:
- Arsitektur: 1 partial class raksasa berbagi state, static mutable, UI thread + timer + hook. Di mana ini menghambat (regresi, race, kebocoran, startup)? Beri bukti pola nyata, bukan teori.
- Duplikasi: P/Invoke dobel (mis. `KEYBDINPUT`, `RECT` di beberapa file), helper berulang, magic number. Ukur.
- i18n infra: kamus Indonesia→Inggris 1.627 entri, kunci = teks Indonesia (mengubah copy = merusak terjemahan), fallback senyap, tidak ada validasi cakupan. Risiko & perbaikan.
- Settings: 143 kunci string, tanpa schema/validasi/migrasi, `settings.ini` plaintext berisi key. Risiko & perbaikan.
- Build/release: wildcard `src\*.cs`, tanpa test, tanpa analyzer, exe biner masuk repo, tanpa signing, update manual GitHub, tanpa crash reporting/telemetry opt-in, CI hanya build. Nilai risikonya + usulan minimum viable engineering.
- Parsing tidak teruji: Ics.cs (53 KB), PdfLite.cs (51 KB), Json di Base.cs, parser surat perintah `Suruh.cs`. Fuzzing/golden test?
- Observability: `Log.Write` — rotasi? ukuran? berisi apa? Crash handling (`Program.cs`), diagnosa pengguna.
- Drift dokumen: README "1.626 KB" vs build 1.727.000 byte; klaim performa docs vs ukur; versi di README/AssemblyInfo.
- Aksesibilitas arsitektural: owner-drawn canvas tanpa UIA tree — apa dampaknya dan bagaimana menambah tanpa rewrite?

**Riset (05)**:
- Ambil issue upstream `odlaver/tepi` (semua state) + `movlution/tepi`; kelompokkan keluhan/bug/permintaan fitur nyata. Kutip issue number.
- Release notes upstream: apa yang baru/terakhir, ke mana arah produk.
- Situs resmi: positioning, klaim, screenshot, halaman pack tema. Catat URL aset screenshot.
- Pembanding: aplikasi dynamic island/notch Windows dan macOS (mis. Dynamic Island for Windows, Fluent/Windows 11 widgets, NotchNook/boring.notch/Alcove di macOS, PowerToys) — fitur/UX yang layak dicontoh, jangan plagiat.
- Hasil: 10 peluang fitur/UX paling bernilai + bukti permintaan (issue/vote/pemakaian), plus 5 risiko positioning.

## 8. Struktur file output (semua file mulai dengan ini)

```
# <Judul area> — Tepi
> Analisis oleh <nama-peran>. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: baca kode + docs + ukur/riset. Tanggal: 2026-11-12.

## Ringkasan eksekutif (5-8 baris)
## Skor / penilaian (tabel)
## Yang sudah bagus
## 10 prioritas utama (tabel: ID, severity, judul, usaha, quick win)
## Temuan detail (P0/P1 dulu)
## Temuan ringkas lanjutan (tabel)
## Pertanyaan terbuka / yang perlu diverifikasi
```

## 9. Aturan kerja tim

- Selesai = file output ditulis + task di board di-`complete` + pesan ringkas ke Lead (maks 10 baris: jumlah temuan per severity, 3 temuan teratas, path file).
- Jangan menunggu Lead; jangan bertanya balik kecuali benar-benar blocker.
- Tulis file lebih awal (kerangka), lalu perbaiki; jangan menumpuk semua di akhir.
- Jika menemukan masalah di luar area Anda, catat 1 baris di bagian "Lintas area" file Anda; jangan analisis mendalam.
