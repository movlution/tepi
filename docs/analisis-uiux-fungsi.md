# Analisis Menyeluruh Tepi 2.6.1 — UI/UX dan Fungsi

> **Laporan sintesis** dari 5 aliran analisis independen + verifikasi silang Lead.
> Objek: `D:\PROJECT\Other\tepi` (fork `movlution/tepi`, upstream `odlaver/tepi`), commit `ff0183c`.
> Tanggal: 12 November 2026. Basis: 144 file C#, 56.346 baris (52.017 non-kosong), build terverifikasi (1.727.000 byte), aplikasi berjalan (PID 41828) diukur langsung, 2.702 baris log pengguna, GitHub API, dan situs resmi.
> Dokumen pendukung: [`00-brief.md`](analisis/00-brief.md) · [`01-visual.md`](analisis/01-visual.md) · [`02-ux.md`](analisis/02-ux.md) · [`03-fungsi.md`](analisis/03-fungsi.md) · [`04-teknis.md`](analisis/04-teknis.md) · [`05-riset.md`](analisis/05-riset.md).

---

## 1. Ringkasan eksekutif

**Tepi adalah produk dengan kedalaman fitur di atas rata-rata kategorinya, tetapi mutu eksekusinya belum merata.** Untuk aplikasi 1,7 MB tanpa dependensi, isinya luar biasa: 19 aktivitas, 11 halaman panel, Dock pengganti taskbar, kartu izin agent dengan diff, dikte online/offline, transkrip rapat tanpa bot, jadwal sholat offline, dan companion Android. Fondasi teknisnya juga lebih serius dari yang terlihat: token desain nyata, penulisan berkas atomik, DPAPI untuk rahasia, update ber-SHA-256 dengan rollback, dan hook agent ber-token yang hanya mendengarkan loopback.

Masalahnya bukan kurang fitur, melainkan **kesenjangan antara luas fitur dan jaminan kualitas**. Empat pola berulang muncul di semua area:

1. **Kegagalan senyap.** Fitur Pesan mati total di mesin ukur (≈10.100 percobaan baca notifikasi gagal dalam 19,4 jam), tetapi tab Pesan hanya menampilkan "tidak ada pesan". 109 dari 438 `catch` kosong menelan kegagalan aksi pengguna.
2. **Jaminan keterbacaan tidak ditegakkan.** Token `Faint` tidak pernah mencapai 4,5:1 (maks 2,96:1) padahal membawa metadata 11 px; material Frost tidak punya penjaga kontras; 2 dari 7 aksen preset hanya 3,07:1; mode kontras tinggi/teks besar Windows diabaikan.
3. **Aksesibilitas struktural tertinggal.** Island owner-drawn tanpa pohon UI Automation; pembaca layar hanya menerima notifikasi. ~99 target klik terdaftar manual, hanya 53 punya `AccessibleName`.
4. **Rilis tidak reproducible dan tak tepercaya.** `Tepi.exe` dilacak di git (40 objek, 30 commit, 24,97 MB histori), build source 1.727.000 byte ≠ biner komit 1.665.024 byte, exe belum ditandatangani, dan nol test otomatis.

**Skor ringkas (skala band: ≥80% sangat baik · 65–79% baik · 50–64% cukup · 35–49% lemah · <35% kritis):**

| Dimensi | Skor | Band | Inti masalah |
|---|---|---|---|
| Bahasa visual & design system | 16/32 (50%) | Cukup | Kontras, tipografi ad-hoc, token setengah dipakai |
| UX, IA & aksesibilitas | 23/40 (58%) | Cukup | Penemuan fitur, hover/scroll rawan, UIA kosong |
| Fungsi, keandalan & privasi | 23/35 (66%) | Baik | Pesan mati senyap, audio rapat bisa hilang, resource creep |
| Engineering & rilis | 10/28 (36%) | Lemah | God-object, nol test, biner di git, observability minim |

**Yang harus dikerjakan lebih dulu (7 hari):** selamatkan audio rapat saat transkripsi gagal (P0, risiko kehilangan data), beri status error + backoff pada notifikasi, naikkan kontras `Faint`/aksen + perbaiki cincin fokus, tampilkan hitung mundur izin agent, dan hentikan pertumbuhan handle/thread saat idle. Ini semua berbiaya ≤ 1 hari per item (lihat §7).

**Peluang strategis (bukti riset):** publik tidak punya saluran permintaan (0 issue, 0 diskusi; feedback hanya Google Form privat), padahal pesaing kategori mengumpulkan 44–940 issue dari pengguna nyata. Distribusi belum tepercaya (unsigned, tanpa Store/winget) sementara Tepi hanya 550 unduhan GitHub vs 11,7 rb–65,8 rb pesaing Indonesia. Celah fitur paling bernilai: multi-monitor, Mode Kuliah (rekam → ringkasan → tugas), dan zona aman interaksi.

---

## 2. Metode, cakupan, dan batasan

**Aliran analisis (paralel, independen, bukti `file:line`/ukur/URL):**

| Aliran | Output | Temuan | Skor |
|---|---|---|---|
| Visual & design system | [`01-visual.md`](analisis/01-visual.md) | 24 (P1 8 · P2 10 · P3 6) | 16/32 |
| UX & aksesibilitas | [`02-ux.md`](analisis/02-ux.md) | 23 (P1 6 · P2 11 · P3 6) | 23/40 Nielsen |
| Fungsi, keandalan, privasi | [`03-fungsi.md`](analisis/03-fungsi.md) | 27 (P1 5 · P2 5 · P3 17) | 23/35 |
| Arsitektur, build, rilis | [`04-teknis.md`](analisis/04-teknis.md) | 22 (P1 8 · P2 13 · P3 1) | 10/28 |
| Riset pengguna & pembanding | [`05-riset.md`](analisis/05-riset.md) | 24 (10 peluang + 14 observasi) | — |

**Verifikasi Lead:** klaim headline dicek ulang ke kode/log/proses (tabel lengkap §12.3). Angka yang tidak bisa diverifikasi ditandai di laporan area masing-masing.

**Batasan yang harus dibaca sebelum memakai angka:**
- Island **tidak bisa dipotret** (aplikasi mengecualikan diri dari screen capture, `capture.show` default mati), jadi audit visual bersandar pada kode token, render aset resmi di situs, dan perhitungan WCAG — bukan screenshot UI live.
- Tidak ada pengujian fungsional end-to-end (dilarang mengendalikan input). Penilaian fungsi berbasis kode + log + ukur proses.
- **Performa diukur pada konfigurasi pengguna ini** (Dock menggantikan taskbar aktif, banyak fitur menyala, aplikasi juga melayani sesi ini), bukan konfigurasi default. Perbandingan dengan klaim dokumen karena itu bersifat indikatif, bukan apple-to-apple.
- Angka issue/unduhan eksternal adalah snapshot 12 November 2026 dan sudah diverifikasi via GitHub API (kecuali yang ditandai sekunder).

---

## 3. Tujuh temuan yang paling berdampak

### IMP-01 · P0 · Audio rapat dihapus sebelum transkripsi dipastikan tersimpan
- **Bukti:** `src/Rapat.cs:133-136` — `WriteRapat` dipanggil, apa pun hasilnya `Directory.Delete(RapatTmp, true)`; `WriteRapat` mengembalikan `null` saat tidak ada baris transkrip (`Rapat.cs:203`), mis. key STT mati, kuota habis, atau model offline belum diunduh. Pesan akhir hanya "transkrip gagal ditulis" (`Rapat.cs:145`).
- **Dampak:** rekaman kuliah/rapat satu jam hilang dan tidak bisa diulang. Ini satu-satunya temuan yang memenuhi kriteria **P0 (kehilangan data)**.
- **Perbaikan:** bila `path == null`, pertahankan audio di `%APPDATA%\Tepi\rapat\sementara`, tawarkan "Coba transkripsi lagi" / "Simpan audio"; hapus hanya setelah sukses atau dipilih pengguna. **Usaha S · quick win.**

### IMP-02 · P1 · Fitur Pesan mati total tanpa satu pun pesan error
- **Bukti:** `%APPDATA%\Tepi\tepi.log` (19,4 jam, 2.702 baris) berisi **1.137 baris `notif read: WinRT timeout` + 8.977 counter dedupe ≈ 10.114 percobaan gagal** (≈42% isi log). `src/Notifs.cs:230-252` menangkap exception lalu hanya `Log.Write` dan mengulang; pembacaan memakai `MediaService.Await` dengan timeout 5 dtk (`src/Media.cs:317-327`). Panel Pesan hanya membedakan "dimatikan" dan "akses ditolak" (`src/Panel.cs:414-419`) — tidak ada state "gagal membaca".
- **Dampak:** kanal WhatsApp/Telegram di island — nilai jual persona utama — tidak pernah terisi, dan pengguna tidak tahu fitur rusak. Log juga membanjiri error lain.
- **Perbaikan:** backoff eksponensial 5→30→120 dtk setelah 3 kegagalan; state error eksplisit + tombol "Coba lagi" di empty state Pesan; toast sekali; fallback membaca DB SQLite (kunci perubahan sudah dibaca di `Notifs.cs:157-188`); kirim status ke halaman Diagnostik. **Usaha M · quick win sebagian.**

### IMP-03 · P1 · Resource creep saat idle + memori jauh di atas klaim
- **Bukti (diukur 12 Nov, PID 41828, tanpa interaksi):** handle **2.949 → 4.121** dan thread **219 → 325** dalam ±31 menit (≈0,6 handle/detik); private 81,8 → **95,5 MB**, peak working set **130,4 MB**; log sesi sebelumnya mencatat **366 baris `memory 150–175 MB private, collecting`**. Guard `LeakMb = 150` (`src/Memory.cs:19`) hanya mencatat lalu `GC.Collect()` ×2 + `SetProcessWorkingSetSize` (`Memory.cs:86-95`), sehingga pertumbuhan native tak turun.
- **Dampak:** sesi kerja seharian berpotensi memberatkan laptop 4–8 GB; klaim "ringan" (dokumen ±22 MB, situs 13 MB) tidak terbukti pada konfigurasi nyata.
- **Perbaikan:** profil alokasi per komponen (bitmap kaca/thumbnail/dock/ikon) tiap menit; turunkan ambang ke ±90 MB; pindahkan trim dari UI thread; audit `new Thread` (30 titik, `Agents.cs:167`, `Phone.cs:404`) dan objek WinRT dari loop retry notifikasi; target <100 thread. **Usaha M.**

### IMP-04 · P1 · Keterbacaan tidak dijamin: Faint, Frost, aksen, dan warna sendiri
- **Bukti terverifikasi:** `Faint = FromArgb(92,…)` (`src/Ink.cs:42,78`) → komposit **2,96:1** di tema gelap dan **2,37:1** di tema terang; dipakai metadata 11 px di 68 tempat (`Clips.cs:141`, `ConvertPage.cs:230`, `Overview.cs:569`). `OnGlass()` yang menaikkan alpha ke 74% (`Ink.cs:28-33`) hanya dipakai Dock (`DockPaint.cs:35`, `DockCard.cs:343`, `DockSheet.cs:241`), tidak di island. Frost hanya menint 42% tanpa penjaga (`Glass.cs:69,327`) sementara jalur Liquid punya guard (`Glass.cs:383-427`) — estimate teks sekunder Frost 2,72:1 di wallpaper putih. Preset **Biru `#4C8DFF` → tinta putih 3,07:1**, Navy 3,08:1 (`Ink.cs:152` heuristik luma, bukan kontras); warna sendiri/paket tema bisa menghasilkan 1,26:1 (`Colors.cs:69-95`, `Ink.cs:103-123`).
- **Dampak:** detail penting (umur pesan, ruang kelas, asal tugas, waktu) sulit dibaca di layar redup atau material Frost di wallpaper terang; tab/tombol beraksen bisa gagal 4,5:1.
- **Perbaikan:** alpha Faint ≥140 atau larang <12 px; pilih `OnAccent` dengan fungsi kontras (`Colors.cs:104-114` sudah punya pembanding) dan uji 7 preset × 2 tema; terapkan `OnGlass()` pada island saat kaca aktif; paksa ladder kontras setelah `DerivePalette`; matriks uji kontras di CI. **Usaha S–M · quick win.**

### IMP-05 · P1 · Aksesibilitas struktural: pohon UIA kosong, kontras tinggi & teks besar diabaikan
- **Bukti:** `src/A11y.cs:12-46` — satu-satunya integrasi AT adalah `RaiseAutomationNotification`; island owner-drawn tanpa child control (`OnPaint` kosong, `Island.cs:145-158`), tidak ada `CreateAccessibilityInstance` untuk surface island; ~99 target klik manual (`AddHit`/`hits.Add`) vs 53 `AccessibleName`; `Keyboard.cs:120-149` `Label()` adalah whitelist ±20 ID sehingga sebagian besar fokus tidak diucapkan. Tidak ada referensi `HighContrast`/`SystemColors`/`TextScaleFactor` di 144 file; semua font `GraphicsUnit.Pixel` (`Ink.cs:235-245`). Cincin fokus memakai warna aksen yang sama dengan isi kontrol (`Keyboard.cs:151-162` vs `Tabs.cs:526`).
- **Dampak:** pengguna Narrator/NVDA tidak bisa menelusuri tab, tombol, tugas, atau pesan, padahal `docs/fitur.md:43` menjanjikan "seluruh island bisa dipakai keyboard". Pengguna low-vision yang menaikkan "Ukuran teks" Windows tidak melihat perubahan.
- **Perbaikan:** `AccessibleObject` kustom yang memetakan daftar `hits`/`focusId` menjadi child UIA (role, name, state, invoke); lengkapi `AccessibleName` 100% target interaktif; hormati `SystemInformation.HighContrast` dan `TextScaleFactor` lewat satu helper skala; cincin fokus kontras ganda. **Usaha M–L.**

### IMP-06 · P1 · Penemuan & IA: 10 tab bawaan jadi titik, hover 330 ms, aksi tersembunyi
- **Bukti:** `DefaultTabs` berisi 10 tab (`Tabs.cs:17`), dan `DotTabs` aktif otomatis saat >7 tab (`Tabs.cs:429-436`); nama tab hanya muncul saat hover/aktif (`Tabs.cs:650-653`) sehingga pengguna baru melihat deretan titik ±3 px. Panel terbuka setelah kursor diam 330 ms (`Island.cs:1413-1416`) — tepat di jalur kursor menuju tab browser; roda mouse di island tertutup langsung mengubah volume (`Island.cs:1525-1541`). Menu klik kanan berisi 18 item + submenu (`Island.cs:1746-1770`), Dock mati secara bawaan, dan 8 pintasan global harus dihafal. Riset pembanding: keluhan paling umum aplikasi sejenis adalah "island tidak terbuka saat di-hover", "menutupi tab browser", dan "tidak muncul saat startup".
- **Dampak:** fitur yang dibangun mahal tidak ditemukan; panel terbuka/tertutup tak sengaja puluhan kali sehari; volume berubah tanpa niat dan tanpa undo.
- **Perbaikan:** default 6 tab + tawarkan sisanya di Pengaturan; label tab persisten 2 dtk saat panel dibuka; tombol "⋯" di strip untuk membuka menu yang sama dengan klik kanan; opsi `panel.open=click` sebagai default untuk pengguna baru; tunda wheel-volume ≥600 ms; tambah diagnostik first-run "island tidak muncul". **Usaha S–M · quick win sebagian.**

### IMP-07 · P1 · Rilis tidak reproducible, tidak tepercaya, dan pipeline tanpa jaring pengaman
- **Bukti:** `git ls-files Tepi.exe` → terlacak; 40 objek biner di histori = 24,97 MB, 30 commit menyentuh biner (`04-teknis.md:60-64`); build source terverifikasi **1.727.000 byte** ≠ biner HEAD **1.665.024 byte**; `README.md:17` dan situs menulis "1.626 KB" — cocok dengan biner komit, basi terhadap source. Update memverifikasi SHA-256 + HTTPS (`Update.cs:85-110`) tetapi kontinuitas Authenticode hanya aktif bila exe sudah ditandatangani (`Update.cs:114-120`) — sekarang tidak. Tidak ada test/analyzer; CI hanya build + cetak hash (`.github/workflows/build.yml`). `Update.cs:17` hardcode asset `odlaver/tepi`, sementara fork `movlution/tepi` tidak punya release: **build fork yang di-update akan diganti biner upstream.**
- **Dampak:** biner bisa berubah tanpa jejak source, pengguna tidak bisa memverifikasi exe = hasil build commit, SmartScreen menekan konversi, dan jalur distribusi fork ambigu.
- **Perbaikan:** `git rm --cached Tepi.exe` + `.gitignore`; rilis hanya dari CI dengan attestation SHA-256; aktifkan Authenticode (EV atau SignPath OSS); pin compiler + `/deterministic`; tentukan kanal update fork (repo sendiri atau sengaja mengikuti upstream) dan tampilkan changelog sebelum instal. **Usaha M.**

---

## 4. Tema temuan (peta lengkap)

### Tema A — Keandalan senyap & integritas data
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| A1 | **P0** | Audio rapat dihapus sebelum transkrip aman | `Rapat.cs:133-136,203` | S |
| A2 | P1 | Pesan mati senyap, ~10.100 percobaan gagal | `Notifs.cs:230-252`, log | M |
| A3 | P1 | Resource creep handle/thread saat idle | ukur PID 41828 | M |
| A4 | P2 | 109 catch kosong (dari 438) menelan kegagalan aksi | `DockShell.cs:456-462`, `Shots.cs:241-245` | S |
| A5 | P2 | AI tanpa retry; dikte gagal membuang audio di memori | `Ai.cs:229-250`, `Dictate.cs:263-295` | S |
| A6 | P2 | Unduh model whisper 574 MB tanpa resume | `Speech.cs:190-232` | S |
| A7 | P2 | Tidak ada cache offline tugas/jadwal | `Sources.cs:130-172` | M |

### Tema B — Keterbacaan & aksesibilitas
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| B1 | P1 | `Faint` 2,96:1 (gelap) / 2,37:1 (terang), dipakai 11 px | `Ink.cs:42,78`; 68 pemakaian | S |
| B2 | P1 | Frost tanpa guard; Liquid guard salah ruang warna | `Glass.cs:69,327,383-427` | M |
| B3 | P1 | `OnGlass()` tidak dipakai island | `Ink.cs:28-33` vs Dock | S |
| B4 | P1 | 2/7 aksen preset 3,07:1; warna sendiri bisa 1,26:1 | `Ink.cs:152`, `Colors.cs:69-95` | S |
| B5 | P1 | Tanpa high-contrast & skala teks Windows | 0 referensi di `src/` | M |
| B6 | P1 | Cincin fokus aksen-di-atas-aksen | `Keyboard.cs:151-162`, `Tabs.cs:526` | S |
| B7 | P1 | Pohon UIA island kosong; 53 nama untuk ~99 target | `A11y.cs`, `Island.cs:145-158` | M–L |
| B8 | P2 | Tipografi ad-hoc: 402–417 ukuran px (19 nilai) vs 46 pemakaian peran | `Ink.cs:227-233` | M |
| B9 | P2 | Token spacing/radius 0—15 pemakaian; 21 radius literal | `Ink.cs:183-188`; 166 `FillRound` | M |

### Tema C — Penemuan, IA, dan alur
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| C1 | P1 | 10 tab bawaan → titik; nama hanya saat hover | `Tabs.cs:17,429-436,650-653` | M |
| C2 | P1 | Hover 330 ms + wheel-volume/scroll-tab di tepi atas | `Island.cs:1413-1416,1525-1541` | S–M |
| C3 | P1 | Penemuan fitur: menu klik kanan 18 item, 8 hotkey, Dock mati bawaan | `Island.cs:1746-1770`, `PrefsDock.cs:20-21` | S–M |
| C4 | P2 | Izin agent kedaluwarsa 110 dtk tanpa hitung mundur/toast | `Agents.cs:228-243`, `Views.cs:576` | S |
| C5 | P2 | Tab "Pengingat" tidak bisa membuat pengingat | `Reminders.cs:482-506` | S |
| C6 | P2 | `WorkWindow`/`TaskEditor` tak diterjemahkan; 32 kunci i18n bocor | `WorkWindow.cs:102-117`, `Lang.cs:1651-1655` | M |
| C7 | P2 | Pengaturan 23 halaman/6 kategori; pencarian ada tapi tanpa `AccessibleName`/Ctrl+F | `Prefs.cs:356-360,417-434` | S–M |
| C8 | P3 | Toast beraksi tanpa affordance & cepat hilang; empty state tak seragam | `Views.cs:836-856`, `Panel.cs:414` | S |

### Tema D — Performa & resource
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| D1 | P1 | Handle/thread naik monoton idle (2.949→4.121 / 219→325) | ukur 35 menit | M |
| D2 | P1 | Memori private 95,5 MB (peak WS 130,4 MB); log sesi lalu 150–175 MB; klaim 13–22 MB | `Memory.cs:19,86-95`; `performa.md:11` | M |
| D3 | P1 | Idle CPU 1,56–2,29% satu core (klaim 0,2–1%) — sebagian karena badai notifikasi | ukur | M |
| D4 | P2 | Frame loop `DwmFlush`+`Sleep(8)` di UI thread; GC penuh + trim tiap menit | `Island.cs:632-654`; `Memory.cs` | M |

### Tema E — Rilis, build, dan ekosistem
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| E1 | P1 | `Tepi.exe` dilacak git; build ≠ biner komit; tidak reproducible | `git ls-files`, 40 objek/30 commit | M |
| E2 | P1 | Unsigned; digest update dari API yang sama; fork update ke upstream | `Update.cs:17,114-120` | M |
| E3 | P1 | Nol test/analyzer; parser Ics 1.196 & PdfLite 1.189 baris tak diuji | repo/CI | M |
| E4 | P2 | Tanpa installer/uninstall; update menulis di folder exe → gagal di Program Files | `Update.cs:111-139` | M |
| E5 | P2 | Hook global 6 `SetWindowsHookEx` + 6 `RegisterHotKey`; taskbar disembunyikan dengan state persisten | `Taskbar.cs:66-86,99`; `DockKeys.cs:79` | M |

### Tema F — i18n, settings, dokumentasi
| ID | P | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| F1 | P1 | Kunci i18n = teks Indonesia; fallback senyap; ≥6 dari 32 kunci bocor terverifikasi | `Lang.cs:1651-1655` | S–M |
| F2 | P1 | 143–155 kunci setelan tanpa schema/validasi/migrasi; `agent.token` plaintext | `Base.cs:119-134`, `Life.cs:452-458` | M |
| F3 | P2 | Drift dokumen: performa diukur di 2.1/2.4/2.5; "semua kunci" settings salah; ukuran exe basi | `performa.md`, `pengaturan.md:60`, `README.md:17` | S |
| F4 | P2 | 68 nama P/Invoke dideklarasikan ganda; struct kembar (`RECT`, `INPUT`, `KEYBDINPUT`) | `DockKeys.cs`, `Native.cs`, `AgentPrompt.cs` | S–M |

**Celah fitur fungsional yang terbukti belum ada** (`03-fungsi.md:151-162`): tulis acara kalender, jadwal Senyap/DND otomatis, island multi-monitor, sinkron antar-laptop, manajemen kuota AI (baru tampilan), plugin/extension API, pencarian universal, dan dokumentasi "Tugas dan catatan".

---

## 5. Daftar prioritas gabungan (setelah dedupe)

| # | ID | P | Perbaikan | Sumber | Usaha | Quick win |
|---|---|---|---|---|---|---|
| 1 | IMP-01 | **P0** | Simpan audio rapat bila transkripsi gagal | FUN-04 | S | ya |
| 2 | IMP-02 | P1 | Status error + backoff + fallback notifikasi | FUN-01 | M | sebagian |
| 3 | IMP-04 | P1 | Jaminan kontras (Faint, Frost, aksen, warna sendiri, `OnGlass` island) | VIS-01..06 | S–M | ya |
| 4 | IMP-05 | P1 | UIA tree + nama aksesibel + kontras tinggi + skala teks | UX-03/TEK-08/VIS-07/UX-05 | M–L | sebagian |
| 5 | IMP-03 | P1 | Profil & perbaiki resource creep; turunkan guard memori; trim di luar UI | FUN-02/03, TEK-07 | M | tidak |
| 6 | IMP-06 | P1 | IA & penemuan: 6 tab default, label persisten, tombol "⋯", kebijakan hover | UX-01/02/11 | S–M | ya |
| 7 | IMP-07 | P1 | Rilis: hapus biner dari git, reproducible, signing, kanal update fork | TEK-03/16/18, RIS-01 | M | ya (git) |
| 8 | — | P1 | Test minimum: golden Ics/PdfLite/Json + validator i18n di CI | TEK-02/05 | M | sebagian |
| 9 | — | P1 | Cincin fokus keyboard kontras (accent-on-accent) | VIS-08 | S | ya |
| 10 | — | P1 | Izin agent: hitung mundur + toast kedaluwarsa + opsi tanpa timeout | UX-04 | S | ya |
| 11 | — | P1 | Retry AI/dikte + simpan WAV sementara + "Coba lagi" | FUN-07 | S | ya |
| 12 | — | P1 | Onboarding aktivasi: diagnostik "island tidak muncul" + tray fallback | RIS-07 | S | ya |
| 13 | — | P2 | Offline cache tugas/jadwal + umur data di UI | FUN-06 | M | tidak |
| 14 | — | P2 | i18n: lengkapi 32 kunci bocor, terjemahkan WorkWindow/TaskEditor, validator | F1, UX-08 | M | sebagian |
| 15 | — | P2 | Settings schema tabel-tunggal + migrasi + `agent.token` via Vault + debounce save | F2, FUN-19 | M | sebagian |
| 16 | — | P2 | Observability: header log (versi/OS/locale), rate-limit per kategori, "Simpan diagnosa" | TEK-04 | M | sebagian |
| 17 | — | P2 | Unduh model whisper dengan Range/resume + estimasi | FUN-05 | S | ya |
| 18 | — | P2 | Bridge HP: bind alamat privat + tolak profil Public + rate-limit per IP | FUN-09 | S | ya |
| 19 | — | P2 | Jadwal Senyap/DND otomatis + filter notifikasi per aplikasi | FUN-12, RIS-09 | M | tidak |
| 20 | — | P2 | Multi-monitor: island per layar / ikut monitor aktif | FUN-13, RIS-03 | L | tidak |

---

## 6. Quick wins (masing-masing ≤ 1 hari)

| # | Perubahan | File kunci | Dampak |
|---|---|---|---|
| 1 | Naikkan alpha `Faint` 92→≥140, atau larang untuk teks <12 px dan alihkan ke `Sub` | `Ink.cs:42,78` + 68 pemakaian | Semua metadata lolos 4,5:1 |
| 2 | Pilih `OnAccent` dengan fungsi kontras, bukan heuristik luma; uji 7 preset | `Ink.cs:152`, `Colors.cs:104-114` | Tab/tombol beraksen terbaca |
| 3 | Pakai `tone.OnGlass()` saat kaca aktif di island | render `Island.cs:771-896` | Teks island setara Dock di atas wallpaper |
| 4 | Cincin fokus kontras ganda (Flip.Bg + outline 1 px) | `Keyboard.cs:151-162` | Posisi fokus keyboard selalu terlihat |
| 5 | Notifikasi: status error + tombol "Coba lagi" + backoff + toast sekali | `Notifs.cs:230-252`, `Panel.cs:414-419` | Fitur mati tidak lagi senyap |
| 6 | Simpan audio rapat saat `path == null` + tombol coba lagi/simpan | `Rapat.cs:133-145` | Mencegah kehilangan data P0 |
| 7 | Izin agent: "sisa N dtk" + toast kedaluwarsa + opsi nonaktifkan timeout | `Views.cs:576`, `Agents.cs:228-243` | Agent tidak menggantung tanpa penjelasan |
| 8 | Hover: default klik / jeda 500 ms; wheel-volume hanya setelah hover ≥600 ms; wheel-ganti-tab hanya di strip tab | `Island.cs:1413-1416,1525-1541`, `Tabs.cs:229-277` | Menghilangkan panel/volume tak sengaja |
| 9 | Kolom cari Pengaturan: `AccessibleName`, Ctrl+F, fokus saat dibuka | `Prefs.cs:356-360` | Setelan lebih mudah dan aksesibel |
| 10 | Header log per sesi + tombol "Simpan diagnosa" (zip log tanpa rahasia) | `Base.cs:24-52`, halaman Tentang | Laporan bug bisa ditindaklanjuti |
| 11 | Validator i18n di CI: kunci literal `Lang.T/F` vs kamus; log fallback sekali per kunci | `Lang.cs`, skrip CI | Mencegah bocoran Indonesia di UI Inggris |
| 12 | `git rm --cached Tepi.exe` + `.gitignore` `Tepi*.exe`; SHA-256 dipublikasikan di release notes | repo + CI | Repo bersih, artefak bisa diverifikasi |
| 13 | Wrap `WorkWindow`/`TaskEditor` dengan `Lang.T`; perbaiki 32 kunci bocor | `WorkWindow.cs`, `TaskEditor.cs`, `Lang.cs` | Mode English konsisten |
| 14 | Refresh `docs/performa.md` + ukuran exe README/situs; dokumentasikan 41 kunci setelan yang hilang | `docs/` | Berhenti menyesatkan pengguna/kontributor |
| 15 | Tingkatkan `BaseTint`/pakai varian guard pada Frost | `Glass.cs:69,327` | Teks Frost terbaca di wallpaper terang |

---

## 7. Roadmap 3 fase

**Fase 0 — "Jangan hilangkan, jangan butakan" (minggu 1, ±5 hari kerja)**
Semua quick win P0/P1: simpan audio rapat, status error notifikasi, kontras Faint/aksen/Frost, `OnGlass` island, cincin fokus, hitung mundur izin, wheel/hover policy, diagnostik aktivasi, header log + simpan diagnosa, hapus biner dari git. Ukur ulang kontras dengan matriks 3 material × 2 tema × 7 aksen dan lampirkan hasilnya.

**Fase 1 — Aksesibilitas & keandalan (minggu 2–6)**
Adapter UIA untuk island + 100% `AccessibleName`; high-contrast & skala teks; profil resource (ETW/handle) + perbaikan kebocoran + turunkan guard memori; retry AI/STT + WAV sementara; cache offline tugas/jadwal; unduh model dengan resume; fallback notifikasi; signing + build reproducible + golden test parser + validator i18n di CI; settings schema-table + migrasi + token via Vault.

**Fase 2 — Penemuan, distribusi, dan fitur baru (bulan 2–3)**
Default 6 tab + label persisten + tombol "⋯"; onboarding aktivasi + tur singkat terukur; 4–6 tile "quick access" di Ringkasan; jadwal DND + filter notifikasi per aplikasi; Store/winget + code signing; papan permintaan publik + kanal beta (ini juga sumber riset pengguna); **Mode Kuliah** (rekam → transkrip → ringkasan → tugas) sebagai diferensiasi; spike multi-monitor; evaluasi plugin API.

**Fase 3 — Opsional/strategis (kuartal berikutnya)**
Sinkron antar-laptop (E2E, opt-in), multi-monitor penuh, manajemen kuota AI lintas-provider, ekosistem plugin, dan peningkatan aksesibilitas tingkat lanjut (navigasi UIA penuh + high-contrast token map).

---

## 8. Metrik keberhasilan

| Area | Metrik | Target |
|---|---|---|
| Keterbacaan | Matriks kontras token × material × tema × aksen | 100% teks ≥4,5:1; UI/ikon ≥3:1 |
| Aksesibilitas | Cakupan `AccessibleName` target interaktif; uji Narrator/NVDA alur izin, pesan, tugas | 100%; alur inti selesai tanpa bantuan |
| Notifikasi | Error UI muncul <1 menit; percobaan/total log | Error rate <1%; <20 baris log/hari |
| Stabilitas | Pertumbuhan handle/thread saat idle 2 jam; memori private 8 jam Dock+musik | <1 handle/menit; <80 MB |
| Performa | CPU idle / panel terbuka (konfigurasi default) | ≤1% / ≤1% satu core |
| Rilis | Biner di git; build reproducible; artifact signed | 0; hash identik 2 build; 100% signed |
| Test | Golden test parser & validator i18n di CI | ≥3 suite, 100% lulus |
| i18n | Kunci literal tak ada di kamus | 0 |
| Distribusi | Unduhan & kanal (GitHub/Store/winget); feedback publik | Pertumbuhan bulanan + issue masuk |
| Aktivasi | Tur selesai; keluhan "island tidak muncul" | Baseline dari feedback, turun 50% |

---

## 9. Yang sudah bagus (jangan dirusak saat memperbaiki)

1. **Lapisan token nyata** — `Tone`/`Ink` (`Ink.cs:35-84`) dengan skala peran, radius konsentris, dan tema yang menimpa token, bukan per-widget.
2. **Kartu izin agent** — arm 0,8 dtk, tombol Izinkan/Selalu terkunci sampai diff digulir habis, perintah berisiko merah, karakter bidi disanitasi (`Views.cs:538-661`, `AgentRisk.cs`).
3. **Keamanan rahasia & jaringan** — DPAPI per akun Windows untuk key AI/integrasi (`Base.cs:477-507`), hook agent loopback + token + `Origin` ditolak + compare waktu-konstan (`Agents.cs:126-143,199-204`), fetch HTTPS-only (`Sources.cs:22-128`), OTP anti-history + bersihkan clipboard 60 dtk.
4. **Operasi berkas berhati-hati** — `AtomicFile` tmp→replace, Rapikan Downloads tak menimpa + undo 1 jam, Rak menolak UNC/`.lnk`, update dengan rollback `Tepi.old.exe`.
5. **Ketahanan fungsional** — fallback STT offline, chip format redup dengan pesan alat hilang, `Retry-After`/backoff sumber, pengingat sholat 100% offline, `--notify`/`--run` untuk skrip.
6. **Fondasi aksesibilitas yang sudah ada** — navigasi keyboard penuh `Ctrl+Alt+I`, 59 guard "Kurangi gerak", pengumuman toast, kontrol Pengaturan dengan nama/nilai/status, reduced-motion mengikuti setelan Windows.
7. **Pengaturan hidup** — pencarian lintas halaman, perubahan langsung berlaku, ekspor/impor ber-whitelist tanpa rahasia, reset dua-klik, tur bisa diulang.
8. **Kerajinan permukaan** — squircle konsisten, kaca yang membaca layar, spring dengan tuning tahan/lepas, DWM dark frame, sampul album monokrom.
9. **Disiplin dokumentasi** — 10 dokumen + privasi/keamanan yang jujur soal unsigned dan rincian endpoint; cocok untuk persona IT.
10. **Kecepatan rilis** — 24 rilis dalam ±16 hari dengan catatan rilis spesifik; ini modal yang jarang di kategori ini.

---

## 10. Keputusan produk yang perlu diambil

1. **Kontrak `Faint`:** dekoratif (boleh <3:1) atau teks (wajib 4,5:1)? Keputusan ini menentukan 68 pemakaian dan arah token berikutnya.
2. **Model interaksi default:** hover 330 ms vs klik; wheel-volume di island tertutup vs hanya saat kursor berhenti. Ini trade-off kecepatan vs risiko salah picu.
3. **`capture.show` default mati:** bagus untuk privasi, tetapi island tidak muncul di screenshot/recording — pengguna yang ingin berbagi/melapor kesulitan. Perlu tombol "tampilkan sekali" atau jelaskan di docs.
4. **Kanal update fork:** saat ini hardcode ke `odlaver/tepi` (`Update.cs:17`) sedangkan fork `movlution/tepi` tanpa release. Tetapkan: ikut upstream (risiko perubahan biner) atau build+sign release sendiri.
5. **Ambisi multi-monitor:** satu island per layar adalah permintaan paling universal di kategori ini (RIS-03) tetapi berbiaya L; setuju/tunda secara eksplisit.
6. **Backup & retensi data:** setelan bisa diekspor, tetapi catatan/transkrip/pengingat/rak tidak punya backup. Putuskan apakah perlu "Backup data Tepi" (zip) dan retensi transkrip.

---

## 11. Verifikasi Lead (klaim headline vs hasil cek ulang)

| # | Klaim | Cara cek | Hasil |
|---|---|---|---|
| 1 | `Faint` 2,96:1 gelap / 2,37:1 terang | hitung WCAG ulang | **Terverifikasi** (2,95–2,96 / 2,37) |
| 2 | `OnGlass()` hanya dipakai Dock | grep pemakaian | **Terverifikasi** (3 file Dock + definisi) |
| 3 | Preset Biru/Navy 3,07:1 | hitung luminansi | **Terverifikasi** (3,07–3,10) |
| 4 | 10 tab bawaan → titik saat >7 | baca `Tabs.cs:17,429-436` | **Terverifikasi** |
| 5 | Hover 330 ms + wheel-volume | baca `Island.cs:1413-1416,1525-1541` | **Terverifikasi** |
| 6 | Notifikasi gagal ≈10.000×, 42% log | hitung log: 1.137 + 8.977 supresi | **Terverifikasi** (≈10.114) |
| 7 | Audio rapat dihapus sebelum transkrip aman | baca `Rapat.cs:133-136,203` | **Terverifikasi** |
| 8 | Guard memori 150 MB hanya log; 150–175 MB | `Memory.cs:19`; 366 baris log | **Terverifikasi** |
| 9 | Handle/thread naik saat idle | ukur langsung 3 titik | **Terverifikasi** (2.949→4.121; 219→325) |
| 10 | Biner di git, 40 objek/30 commit, 1.665.024 vs 1.727.000 B | `git ls-files`, `git rev-list`, build | **Terverifikasi** |
| 11 | ≥6 kunci i18n bocor (dari 32) | grep 6 sampel di `Lang.cs` | **Terverifikasi** (6/6 tidak ada) |
| 12 | Island tanpa child control → UIA kosong | grep `Controls.Add` di `Island.cs`/`Panel.cs` | **Terverifikasi** (0) |
| 13 | Riset: 8 star/3 fork/0 issue/2 PR/24 rilis/550 unduhan | `gh api` | **Terverifikasi** |
| 14 | 143 kunci setelan (analis teknis: 155) | grep `settings.Get/Set` | **Sebagian** — 143 dari pola Lead; perlu rekonsiliasi 155 |
| 15 | Sumber `WinRT timeout` & sumber kebocoran handle | perlu ETW/handle.exe + mesin bersih | **Belum terverifikasi** |
| 16 | Perilaku high-contrast/Narrator/NVDA & multi-monitor | perlu uji UI langsung | **Belum terverifikasi** |

**Statistik temuan:** 96 temuan mentah dari lima area → setelah dedupe & sintesis: **1 P0 · 11 P1 · 8 P2** pada daftar prioritas gabungan (§5) + **15 quick win** (§6). Area terbanyak: fungsi (27), visual (24), UX (23), teknis (22), riset (24 observasi).

**Lampiran sumber utama:** `docs/fitur.md`, `docs/pengaturan.md`, `docs/performa.md`, `docs/privasi-keamanan.md`; situs <https://odlaver.github.io/tepi/>; repo upstream `odlaver/tepi`; pesaing `techreyy/ReyLand`, `FlorianButz/DynamicWin`, `MoFeng2223/BrimDeck`, `TheBoredTeam/boring.notch`, NotchNook, Alcove, Windhawk island mod (detail URL di `05-riset.md`).

> **Cara memakai laporan ini:** mulai dari 7 temuan §3 dan quick wins §6 untuk perbaikan mingguan; gunakan §5 sebagai backlog; §8 untuk acceptance criteria. Detail bukti dan temuan non-prioritas ada di lima dokumen area.
