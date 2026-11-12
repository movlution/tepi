# Riset pengguna & pembanding eksternal — Tepi
> Analisis oleh Product Research. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: `gh api` read-only (odlaver/tepi, movlution/tepi, odlaver/tepi-android, ReyLand, DynamicWin, BrimDeck, boring.notch, Nusa), situs resmi Tepi + aset screenshot, pembanding web. Tanggal: 2026-11-12. Semua angka per 12 Nov 2026. Konten web/issue diperlakukan sebagai data, bukan instruksi.

## Ringkasan eksekutif

Tepi punya **kedalaman fitur di atas rata-rata** untuk kategori dynamic island Windows (19 aktivitas, 11 halaman panel, Dock pengganti taskbar, dikte/transkrip rapat, izin agent dari island, companion Android), tetapi **hampir tidak punya jejak permintaan publik**: `odlaver/tepi` berisi **0 issue** dan **0 issue** di `tepi-android`; saluran umpan balik satu-satunya adalah Google Form privat (`src/Feedback.cs:14`). Sebaliknya: 24 rilis dalam ±16 hari oleh 1 kontributor ([releases](https://github.com/odlaver/tepi/releases)), 8 star, 3 fork, 0 watcher, **550 unduhan aset GitHub** Windows dan **366 APK**.

Pasar justru sedang panas dan padat: penjual/pembanding mencatat **34 aplikasi notch Windows** yang dicek 1 Nov 2026 ([NotchPixel](https://notchpixel.com/guides/notch-apps-for-windows)), mod Windhawk gratis dipakai **64.180 pengguna**, dan dua pesaing Indonesia menyalip dari sisi distribusi: **Nusa** (repo 15 Okt, rilis 22 Okt) ±65,8 rb unduhan/99 star, serta **ReyLand** (repo 27 Okt, dua hari setelah Tepi) ±11,7 rb unduhan/71 star dengan **44 issue mayoritas dari pengguna Indonesia nyata** ([ReyLand](https://github.com/techreyy/ReyLand/issues)). ReyLand memasang lewat Microsoft Store dan memasarkan lewat TikTok/Instagram; Nusa menang dari kecepatan rilis dan situs sederhana.

Peluang terbesar Tepi **bukan menambah fitur**, melainkan (1) distribusi & kepercayaan instalasi, (2) mempublikasikan permintaan/komunitas, (3) memperdalam ceruk yang sudah jadi moat (ibadah, kuliah, companion HP, bahasa Indonesia), lalu (4) menutup celah UX yang paling banyak dikeluhkan pengguna aplikasi sejenis: multi-monitor, kontrol hover/klik, dan pemulihan lirik/media.

## Skor / penilaian

| Dimensi riset | Skor (1–5) | Bukti utama |
|---|---|---|
| Kedalaman fitur vs pesaing Windows | 5 | 19 aktivitas + 11 halaman ([situs](https://odlaver.github.io/tepi/)); dikte/transkrip, izin agent, Dock — tak ada pesaing Windows yang menyamai paket ini |
| Diferensiasi ceruk Indonesia/Islam | 4 | Kemenag, Kulia, ID-first, QRIS; ReyLand/Nusa menyalin sebagian dalam hitungan hari |
| Bukti permintaan publik | 1 | 0 issue di kedua repo Tepi; feedback ke Google Form privat (`src/Feedback.cs:14`) |
| Kematangan komunitas | 1 | 8 star, 3 fork, 0 watcher, 0 diskusi (Discussions mati), 2 PR terbuka tanpa review |
| Kepercayaan distribusi | 2 | exe unsigned + SmartScreen ([README:57-58](README.md)); tanpa Microsoft Store/winget; pesaing pakai Store/penandatanganan |
| Multi-monitor & ARM | 1 | hanya kunci setelan `monitor` tunggal (`docs/pengaturan.md:80`); build `/platform:x64` |
| Transparansi privasi/kinerja | 4 | halaman privasi + angka 0,2% CPU/13 MB jujur dengan metode; tanpa telemetri |

## Yang sudah bagus

- **Kecepatan dan kedisiplinan rilis**: 24 tag dari v1.0.0 (25 Okt) ke v2.6.1 (10 Nov), 282 commit, setiap rilis dipisah perbaikan kecil dengan catatan rilis sangat spesifik — jarang di kategori ini.
- **Kedalaman fitur yang sulit ditiru cepat**: izin agent + diff berwarna + kunci perintah berisiko, transkrip rapat tanpa bot, dikte offline, Dock pengganti taskbar dengan Start sendiri, Mini tembus klik. Pesaing terdekat hanya menyentuh 1–3 dari ini.
- **Moat lokal nyata**: jadwal sholat Kemenag tanpa internet + ibadah sendiri + suara adzan kustom, Kulia, WhatsApp, dan seluruh UI Indonesia. ReyLand membuktikan permintaan ceruk ini nyata — Tepi sudah 2 versi lebih dalam.
- **Companion Android dua arah** (OTP, notifikasi, kirim berkas, izin agent dari HP) — tidak ditemukan di pesaing Windows yang dicek; hanya Nusa/ReyLand punya "kirim file ke HP" sederhana.
- **Kejujuran teknis**: SHA-256 tiap rilis, verifikasi digest saat update, DPAPI untuk token, port acak + token hook, tanpa telemetri — modal kuat untuk persona IT/kantor.
- **Aksesibilitas di atas rata-rata kategori**: navigasi keyboard penuh Ctrl+Alt+I, toast dibacakan, reduced motion — pesaing seperti DynamicWin masih berjuang dengan DPI, font CJK, dan positioning.

## 10 prioritas utama

| ID | Severity | Judul | Usaha | Quick win |
|---|---|---|---|---|
| RIS-01 | P1 | Distribusi tepercaya: signing + Microsoft Store/winget | M | ya (signing + winget) |
| RIS-02 | P1 | Papan permintaan publik & kanal rilis beta | S | ya |
| RIS-03 | P1 | Multi-monitor: island per layar + profil posisi | L | tidak |
| RIS-04 | P1 | Mode Kuliah: rekam kuliah → ringkasan + tugas | M | tidak |
| RIS-05 | P1 | Kontrol interaksi & zona aman (hover/klik, click-through, game) | S | ya |
| RIS-06 | P1 | Ibadah andal + lokalisasi kabupaten/Malaysia/Arab | S–M | ya |
| RIS-07 | P1 | Diagnostik aktivasi first-run ("island tidak muncul") | S | ya |
| RIS-08 | P2 | Pairing HP tahan banting (status, retry, firewall) | M | ya (status) |
| RIS-09 | P2 | Filter notifikasi per aplikasi + jam senyap terjadwal | M | tidak |
| RIS-10 | P2 | Pemulihan lirik/media saat sumber gagal | M | ya (geser global) |

## Tabel issue/keluhan (bukti permintaan)

| Sumber | Nomor + judul (status) | Kategori | Sinyal | Peluang |
|---|---|---|---|---|
| Tepi `odlaver/tepi` | 0 issue; PR [#1](https://github.com/odlaver/tepi/pull/1) & [#2](https://github.com/odlaver/tepi/pull/2) terbuka (0 komentar) | — | Bukti permintaan **tidak terlihat**; feedback lewat Google Form | RIS-02 |
| Tepi release notes | [v2.5.2](https://github.com/odlaver/tepi/releases/tag/v2.5.2) "Mini lebih mudah dibuka… sebelumnya harus tepat di piksel paling atas"; [v2.5.1](https://github.com/odlaver/tepi/releases/tag/v2.5.1) mic nyangkut; [v2.0.0.2](https://github.com/odlaver/tepi/releases/tag/v2.0.0.2) lirik patah; [v1.0.1](https://github.com/odlaver/tepi/releases/tag/v1.0.1) pesan hilang 6 detik | UX, bug | Cacat nyata yang ditemukan pemakaian | RIS-05, RIS-10 |
| ReyLand | [#29](https://github.com/techreyy/ReyLand/issues/29) Island tidak terbuka saat cursor diarahkan (closed); [#42](https://github.com/techreyy/ReyLand/issues/42) Response lambat ketika kursor diarahkan; [#31](https://github.com/techreyy/ReyLand/issues/31) "MENGGANGGU SAYA BEKERJA" | UX | Harapan hover vs klik, island menutupi tombol | RIS-05 |
| ReyLand | [#11](https://github.com/techreyy/ReyLand/issues/11) island hilang saat tak ada aplikasi; [#43](https://github.com/techreyy/ReyLand/issues/43) tidak muncul saat menyalakan laptop; [#45](https://github.com/techreyy/ReyLand/issues/45) perlu buka ulang | Setup | Aktivasi/startup gagal | RIS-07 |
| ReyLand | [#36](https://github.com/techreyy/ReyLand/issues/36) menambah opsi posisi; [#22](https://github.com/techreyy/ReyLand/issues/22) menutupi tab browser | UX | Butuh posisi fleksibel (Tepi sudah punya) | RIS-03 |
| ReyLand | [#7](https://github.com/techreyy/ReyLand/issues/7) shortcut tangkap layar (Ctrl+Shift+S bentrok); [#6](https://github.com/techreyy/ReyLand/issues/6) opsi tampil saat fullscreen (closed); [#30](https://github.com/techreyy/ReyLand/issues/30) shelf tak bisa ditutup | UX | Konflik pintasan & fullscreen | RIS-05 |
| ReyLand | [#41](https://github.com/techreyy/ReyLand/issues/41) / [#27](https://github.com/techreyy/ReyLand/issues/27) suara adzan tidak keluar; [#35](https://github.com/techreyy/ReyLand/issues/35) pemisah adzan Subuh; [#1](https://github.com/techreyy/ReyLand/issues/1) wilayah kota kecil; [#21](https://github.com/techreyy/ReyLand/issues/21) bahasa/Brunei | Fitur | Permintaan ibadah sangat konkret | RIS-06 |
| ReyLand | [#40](https://github.com/techreyy/ReyLand/issues/40) filter notifikasi per aplikasi; [#5](https://github.com/techreyy/ReyLand/issues/5)/[#38](https://github.com/techreyy/ReyLand/issues/38) HP tak tersambung; [#32](https://github.com/techreyy/ReyLand/issues/32) QR kosong; [#3](https://github.com/techreyy/ReyLand/issues/3) transfer satu arah | Integrasi | Notifikasi & pairing rapuh | RIS-08, RIS-09 |
| ReyLand | [#14](https://github.com/techreyy/ReyLand/issues/14) tidak bisa uninstall; [#24](https://github.com/techreyy/ReyLand/issues/24)/[#26](https://github.com/techreyy/ReyLand/issues/26) lirik Spotify hilang/tak sinkron; [#20](https://github.com/techreyy/ReyLand/issues/20)/[#25](https://github.com/techreyy/ReyLand/issues/25) tombol media lompat ke shelf | Distribusi, media | Uninstall bersih & lirik | RIS-01, RIS-10 |
| DynamicWin | [#102](https://github.com/FlorianButz/DynamicWin/issues/102) "Is this malware?"; [#60](https://github.com/FlorianButz/DynamicWin/issues/60) terdeteksi virus; [#40](https://github.com/FlorianButz/DynamicWin/issues/40) tak bisa uninstall; [#96](https://github.com/FlorianButz/DynamicWin/issues/96) sisa registry | Distribusi | Ketakutan malware pada exe unsigned | RIS-01 |
| DynamicWin | [#7](https://github.com/FlorianButz/DynamicWin/issues/7) multi-display; [#19](https://github.com/FlorianButz/DynamicWin/issues/19) pilih lokasi; [#51](https://github.com/FlorianButz/DynamicWin/issues/51)/[#46](https://github.com/FlorianButz/DynamicWin/issues/46) tidak center; [#74](https://github.com/FlorianButz/DynamicWin/issues/74) DPI | Kompatibilitas | Multi-monitor/DPI gagal | RIS-03 |
| DynamicWin | [#54](https://github.com/FlorianButz/DynamicWin/issues/54) taskbar tertutup; [#87](https://github.com/FlorianButz/DynamicWin/issues/87) memblokir tab browser; [#89](https://github.com/FlorianButz/DynamicWin/issues/89) tampil di fullscreen Valorant; [#83](https://github.com/FlorianButz/DynamicWin/issues/83) tak bisa disembunyikan | UX/OS | Overlay mengganggu | RIS-05 |
| DynamicWin | [#58](https://github.com/FlorianButz/DynamicWin/issues/58) makan baterai; [#32](https://github.com/FlorianButz/DynamicWin/issues/32) CPU tinggi; [#73](https://github.com/FlorianButz/DynamicWin/issues/73) framerate | Performa | Beban sistem | RIS-11 (ringkas) |
| BrimDeck | [#195](https://github.com/MoFeng2223/BrimDeck/issues/195) klip buka saat diklik (21 komentar); [#185](https://github.com/MoFeng2223/BrimDeck/issues/185) mouse passthrough; [#199](https://github.com/MoFeng2223/BrimDeck/issues/199) muncul di Alt+Tab | UX | Model interaksi & higiene OS | RIS-05 |
| BrimDeck | [#151](https://github.com/MoFeng2223/BrimDeck/issues/151) data CPU suhu/power/SSD salah (34 komentar); [#152](https://github.com/MoFeng2223/BrimDeck/issues/152) clipboard; [#178](https://github.com/MoFeng2223/BrimDeck/issues/178) plugin; [#220](https://github.com/MoFeng2223/BrimDeck/issues/220) WeChat/QQ; [#201](https://github.com/MoFeng2223/BrimDeck/issues/201) OTP email | Fitur | Permintaan widget & integrasi | RIS-09, ringkas |
| boring.notch | [#417](https://github.com/TheBoredTeam/boring.notch/issues/417) Now Playing rusak setelah macOS 15.4 (58 komentar, 54 👍); [#336](https://github.com/TheBoredTeam/boring.notch/issues/336) notch hilang setelah sleep; [#341](https://github.com/TheBoredTeam/boring.notch/issues/341) stuttering | Bug | Integrasi media rapuh terhadap update OS | RIS-10 |
| boring.notch | [#174](https://github.com/TheBoredTeam/boring.notch/issues/174) "show on specific display" berubah sendiri; [#1260](https://github.com/TheBoredTeam/boring.notch/issues/1260) baterai; [#855](https://github.com/TheBoredTeam/boring.notch/issues/855)/[#1046](https://github.com/TheBoredTeam/boring.notch/issues/1046) tanda tangan/update | Multi-monitor, distribusi | Keluhan universal kategori | RIS-01, RIS-03 |

**Catatan metodologis:** karena Tepi tidak punya issue publik, "keluhan pengguna Tepi" hanya bisa dibaca dari catatan rilis dan PR; angka reaksi/upvote Tepi **tidak tersedia** (0 issue, 0 reaksi). Semua angka issue di atas berasal dari repo pesaing, bukan Tepi.

## Tabel pembanding

| Produk | Platform | Harga/model | Fitur kunci | Yang layak dicontoh |
|---|---|---|---|---|
| **Tepi** | Windows 10/11 x64 + Android | Gratis + donasi QRIS | 19 aktivitas, 11 halaman, Dock/Start, izin agent, dikte/rapat, ibadah, companion HP | — |
| [ReyLand](https://techreyy.github.io/ReyLand/) | Windows | Gratis (Store + installer, .NET 8) | Musik+lirik, sholat 514 kabupaten + 56 kota Malaysia, adzan (jeda musik), OTP, sambung HP, tema, robot, 30+ fitur | **Store + TikTok/Instagram**, adzan per waktu, "tandai lirik salah", multi-monitor "di monitor mana saja" |
| [Nusa](https://github.com/rama2555/nusa) | Windows | Gratis (bisa berbayar nanti) | Rust, lirik LRCLIB, shelf, timer, air, to-do, ~30 MB | Distribusi cepat + situs sederhana; klaim "tanpa CPU saat diam" |
| [NotchPixel](https://notchpixel.com/guides/notch-apps-for-windows) | Windows | $9.99 sekali (trial 7 hari), Store | Stats FPS di game, mute mic global, kirim file ke HP via QR, chat stream | **Halaman footprint** (metode ukur), positioning "mengerjakan tugas", Store |
| [DynamicWin](https://github.com/FlorianButz/DynamicWin) | Windows | Gratis, GitHub | Media, kalender Google, shelf, baterai Bluetooth | Pelajaran negatif: 88 issue soal crash, malware, fullscreen, multi-monitor |
| [BrimDeck](https://github.com/MoFeng2223/BrimDeck) | Windows | Gratis, OSS | Kuota AI, stats, musik, resource monitor | Plugin/ekosistem, komentar issue sebagai riset permintaan |
| [boring.notch](https://github.com/TheBoredTeam/boring.notch) | macOS | Gratis, GPL, 11,3 rb star | Media, shelf, kalender, live activities | 940 issue = bank keluhan siap pakai; stabilitas media lintas update OS |
| [NotchNook](https://getnotchnook.com/) | macOS | Berbayar: trial 48 jam, bulanan/lifetime | 37 fitur, Liquid Glass, teleprompter, AI agents | Model monetisasi jelas + trial; halaman compare VS |
| [Alcove](https://alcovetasks.com/) | macOS/iOS | Gratis + $29.99 sekali | To-do/planner menu bar, meeting notes | Model sekali bayar lintas perangkat; catatan rapat lokal |
| [Windhawk island mod](https://windhawk.net/mods/dynamic-island-for-windows) | Windows | Gratis, MIT | Media+lirik, kalender, stats, shelf, 12 bahasa | **64.180 pengguna** membuktikan permintaan; distribusi lewat katalog mod |

## 10 peluang fitur/UX paling bernilai

### [P1] RIS-01 — Distribusi tepercaya: signing, Store, winget
- **Area**: Distribusi/kepercayaan.
- **Bukti**: Tepi unsigned + SmartScreen ([README:57-58](README.md)); 550 unduhan GitHub vs Nusa 65,8 rb & ReyLand 11,7 rb yang menyediakan Store ("Diperiksa dan ditandatangani Microsoft", [ReyLand](https://techreyy.github.io/ReyLand/)); DynamicWin dituduh malware ([#102](https://github.com/FlorianButz/DynamicWin/issues/102), [#60](https://github.com/FlorianButz/DynamicWin/issues/60)); NotchPixel menonjolkan Store ([guide](https://notchpixel.com/guides/notch-apps-for-windows)).
- **Masalah**: pengguna awam dan IT kantor berhenti di SmartScreen; tidak ada jalur instalasi yang dipercaya.
- **Dampak**: kehilangan konversi terbesar di kategori ini sebelum fitur sempat dinilai.
- **Perbaikan**: Azure Trusted Signing (atau sertifikat OV/EV) di `build.cmd`/CI; paket MSIX + listing Store; paket winget; halaman unduhan dengan checksum & "verifikasi exe" yang sudah ada di `docs/privasi-keamanan.md`.
- **Usaha**: M. **Quick win**: Signing + winget dulu.

### [P1] RIS-02 — Papan permintaan publik + kanal beta
- **Area**: Komunitas/riset.
- **Bukti**: 0 issue Tepi vs ReyLand 44, BrimDeck 63, DynamicWin 88, boring.notch 940; feedback Tepi hanya Google Form privat (`src/Feedback.cs:14`); 2 PR terbuka tanpa komentar ([#1](https://github.com/odlaver/tepi/pull/1), [#2](https://github.com/odlaver/tepi/pull/2)).
- **Masalah**: permintaan nyata tidak terlihat, tidak bisa divote, dan pengguna baru tidak punya "bukti sosial" bahwa aplikasi hidup.
- **Dampak**: fitur dibangun tanpa prioritas pasar; SEO/komunitas nol; kontributor luar tak punya pintu masuk.
- **Perbaikan**: aktifkan Discussions + template issue bug/fitur; tombol "Kirim saran" tetap, tapi tawarkan "lihat & vote di GitHub" plus kode tiket; changelog RSS; label `beta` + setelan `update.channel`.
- **Usaha**: S. **Quick win**: ya.

### [P1] RIS-03 — Multi-monitor: island per layar
- **Area**: Kompatibilitas.
- **Bukti**: Tepi hanya punya satu kunci `monitor` (`docs/pengaturan.md:80`); keluhan nyata: DynamicWin [#7](https://github.com/FlorianButz/DynamicWin/issues/7), [#19](https://github.com/FlorianButz/DynamicWin/issues/19), [#51](https://github.com/FlorianButz/DynamicWin/issues/51); boring.notch [#174](https://github.com/TheBoredTeam/boring.notch/issues/174) (9 komentar); pesaing menjual "one island on every monitor" (Isle Notch) dan "several monitors" (Notchify) di [guide](https://notchpixel.com/guides/notch-apps-for-windows).
- **Masalah**: laptop + monitor eksternal adalah konfigurasi kerja/mahasiswa paling umum; island hanya di satu layar.
- **Dampak**: setengah waktu kerja tanpa island → fitur inti tidak terpakai.
- **Perbaikan**: opsi muncul di semua monitor (satu instance per layar, sinkron state) atau pindah otomatis mengikuti monitor jendela aktif; profil posisi per monitor di `Prefs`; uji DPI campuran (100%/150%).
- **Usaha**: L. **Quick win**: tidak.

### [P1] RIS-04 — Mode Kuliah: rekam kuliah → ringkasan + tugas
- **Area**: Fitur/persona utama.
- **Bukti**: Tepi sudah punya transkrip rapat tanpa bot dan ringkasan + to-do ([fitur.md:33](docs/fitur.md)); permintaan pasar: Alcove menjual "meeting notes" sebagai fitur kunci berbayar ([alcovetasks.com](https://alcovetasks.com/)); tidak ada pesaing Windows yang menggabungkannya dengan jadwal/tugas; persona mahasiswa di brief + Kulia sudah terintegrasi.
- **Masalah**: mahasiswa merekam kuliah dengan HP/aplikasi terpisah, lalu menyalin ke catatan; jembatan ke tugas tidak ada.
- **Dampak**: fitur paling diferensiatif belum punya alur khusus yang mudah ditemukan dari tab Kuliah.
- **Perbaikan**: tombol "Rekam kuliah" di kartu kelas berikutnya (`Kulia.cs`/`Island.cs`), transkrip → ringkasan → ekstrak tugas ke Kulia/Todoist, simpan ke `%APPDATA%\Tepi\rapat` dan Rak; indikator mikrofon/izin+consent.
- **Usaha**: M. **Quick win**: tidak.

### [P1] RIS-05 — Kontrol interaksi & zona aman
- **Area**: UX/navigasi.
- **Bukti**: v2.5.2 mengakui Mini "sebelumnya harus tepat di piksel paling atas" ([release](https://github.com/odlaver/tepi/releases/tag/v2.5.2)); ReyLand [#29](https://github.com/techreyy/ReyLand/issues/29) (harapan hover), [#42](https://github.com/techreyy/ReyLand/issues/42) (respons lambat), [#31](https://github.com/techreyy/ReyLand/issues/31) menutupi tombol, [#30](https://github.com/techreyy/ReyLand/issues/30) shelf macet; DynamicWin [#87](https://github.com/FlorianButz/DynamicWin/issues/87)/[#54](https://github.com/FlorianButz/DynamicWin/issues/54)/[#89](https://github.com/FlorianButz/DynamicWin/issues/89); BrimDeck [#195](https://github.com/MoFeng2223/BrimDeck/issues/195) (21 komentar), [#185](https://github.com/MoFeng2223/BrimDeck/issues/185), [#199](https://github.com/MoFeng2223/BrimDeck/issues/199).
- **Masalah**: pengguna tidak tahu kapan island membuka/menutup, dan takut kehilangan klik; tidak ada mode "hanya tampil, tidak menghalangi" yang jelas.
- **Dampak**: salah klik, tab browser tertutup, aplikasi terasa mengganggu → uninstall.
- **Perbaikan**: setelan delay hover, area klik 40 px (sudah ada di PR #1), tombol "uji di sini" di Pengaturan; zona tembus klik selebar sliver; status "diabaikan di aplikasi X"; jangan pernah tampil di atas game exclusive fullscreen — beri mode game.
- **Usaha**: S. **Quick win**: ya.

### [P1] RIS-06 — Ibadah andal + lokalisasi
- **Area**: Fitur/lokal.
- **Bukti**: ReyLand [#41](https://github.com/techreyy/ReyLand/issues/41)/[#27](https://github.com/techreyy/ReyLand/issues/27) adzan tanpa suara, [#35](https://github.com/techreyy/ReyLand/issues/35) pembeda adzan Subuh, [#1](https://github.com/techreyy/ReyLand/issues/1) kota kecil, [#21](https://github.com/techreyy/ReyLand/issues/21) bahasa/Brunei; Tepi sudah punya Kemenag + suara sendiri ([fitur.md:25](docs/fitur.md)).
- **Masalah**: audio pengingat adalah titik gagal paling sensitif; kesalahan adzan = kepercayaan hilang total. Cakupan kota & bahasa belum seluas ReyLand (514 kabupaten + Malaysia).
- **Dampak**: pengguna Indonesia/Muslim pindah ke pesaing yang lebih terbukti.
- **Perbaikan**: tombol "Coba suara" per waktu sholat, uji fallback audio (laptop muted, Bluetooth, do-not-disturb), cari kota via kode wilayah, impor jadwal manual, opsi bahasa Arab/Melayu untuk teks ibadah, kanal pengingat yang bebas Senyap.
- **Usaha**: S–M. **Quick win**: ya (tes suara + kota).

### [P1] RIS-07 — Diagnostik aktivasi first-run
- **Area**: Onboarding/setup.
- **Bukti**: ReyLand [#11](https://github.com/techreyy/ReyLand/issues/11) island hilang saat idle, [#43](https://github.com/techreyy/ReyLand/issues/43) tidak muncul setelah restart, [#45](https://github.com/techreyy/ReyLand/issues/45) perlu buka ulang; DynamicWin [#43](https://github.com/FlorianButz/DynamicWin/issues/43) hanya ikon tray, [#65](https://github.com/FlorianButz/DynamicWin/issues/65) "where is the dynamic island", [#81](https://github.com/FlorianButz/DynamicWin/issues/81) tak tahu buka Pengaturan; Tepi sudah punya Tur 9 langkah ([fitur.md:47](docs/fitur.md)) dan tray.
- **Masalah**: kegagalan paling awal ("tidak ada apa-apa setelah install") tidak terdiagnosis; pengguna menyimpulkan aplikasi rusak.
- **Dampak**: review buruk/uninstall dini; dukungan manual membengkak ke pembuat tunggal.
- **Perbaikan**: cek mandiri first-run: "Island terlihat? coba arahkan kursor 2 detik", uji posisi layar/monitor, status tray, status autostart, firewall untuk HP, tombol "kirim diagnostik" (versi + log + monitor/DPI) yang bisa ditempel ke issue; empty-state di tray.
- **Usaha**: S. **Quick win**: ya.

### [P2] RIS-08 — Pairing HP tahan banting
- **Area**: Integrasi.
- **Bukti**: ReyLand [#5](https://github.com/techreyy/ReyLand/issues/5), [#38](https://github.com/techreyy/ReyLand/issues/38) HP tak tersambung, [#32](https://github.com/techreyy/ReyLand/issues/32) QR kosong, [#3](https://github.com/techreyy/ReyLand/issues/3) transfer satu arah; Tepi sudah punya QR, kode 12 karakter, AES/HMAC ([README:19](README.md)).
- **Masalah**: ketika pairing gagal, pengguna tidak tahu langkah berikutnya (firewall? Wi-Fi beda? Android 13 restricted settings?).
- **Dampak**: fitur pembeda terasa rapuh justru saat demo pertama.
- **Perbaikan**: state machine pairing dengan 5 status yang terlihat (mencari HP → QR terbaca → TLS → selesai) + tombol "kenapa gagal?"; deteksi Wi-Fi/AP isolation/firewall dan saran; pin pairing ulang tanpa restart; log pairing tanpa data sensitif.
- **Usaha**: M. **Quick win**: ya (status).

### [P2] RIS-09 — Filter notifikasi per aplikasi + jam senyap
- **Area**: Pengaturan/integrasi.
- **Bukti**: ReyLand [#40](https://github.com/techreyy/ReyLand/issues/40) filter notifikasi per aplikasi; BrimDeck [#220](https://github.com/MoFeng2223/BrimDeck/issues/220) WeChat/QQ, [#201](https://github.com/MoFeng2223/BrimDeck/issues/201) OTP email; Tepi punya "Aturan per aplikasi" dan "Pengirim prioritas" ([fitur.md:42](docs/fitur.md)).
- **Masalah**: belum ada jadwal senyap (jam kuliah/tidur) dan filter per aplikasi yang mudah dipindai; pengguna Indonesia memakai WhatsApp untuk hampir semua hal.
- **Dampak**: island jadi bising → dimatikan permanen.
- **Perbaikan**: tabel aplikasi dengan 3 status (tampil/hitung saja/sembunyikan), jadwal senyap harian, pengecualian pengirim prioritas, ringkasan setelah senyap (sudah ada untuk fokus).
- **Usaha**: M. **Quick win**: tidak.

### [P2] RIS-10 — Pemulihan lirik/media
- **Area**: Integrasi/konten.
- **Bukti**: boring.notch [#417](https://github.com/TheBoredTeam/boring.notch/issues/417) (58 komentar, 54 👍) dan [#554](https://github.com/TheBoredTeam/boring.notch/issues/554) media mati setelah update; ReyLand [#24](https://github.com/techreyy/ReyLand/issues/24), [#26](https://github.com/techreyy/ReyLand/issues/26) lirik hilang/tak sinkron; Tepi sudah punya offset per lagu + fallback NetEase ([fitur.md:12](docs/fitur.md)).
- **Masalah**: saat lirik tidak ketemu, pengguna buntu; tidak ada cara melaporkan/memperbaiki.
- **Dampak**: fitur "wow" pertama (lirik) jadi sumber kekecewaan.
- **Perbaikan**: empty-state "Lirik tidak ditemukan" dengan aksi (cari manual, impor `.lrc`, geser default, laporkan); indikator sumber (LRCLIB/NetEase/lokal); tombol "lirik salah?" (ReyLand sudah punya); fallback visualizer/jam.
- **Usaha**: M. **Quick win**: ya (geser global + lapor).

## Temuan ringkas lanjutan

| ID | Severity | Temuan | Bukti |
|---|---|---|---|
| RIS-11 | P2 | Kategori sangat padat: 34 app Windows dicek pesaing, mayoritas gratis/OSS, harga $0,99–$12 sekali bayar; Windhawk 64.180 pengguna | [guide](https://notchpixel.com/guides/notch-apps-for-windows) |
| RIS-12 | P1 | Tidak ada jalur umpan balik publik; permintaan tidak bisa divote dan tidak muncul di mesin pencari | 0 issue; `src/Feedback.cs:14` |
| RIS-13 | P2 | Skala adopsi kecil: 550 unduhan Windows, 366 APK, 8 star | [releases](https://github.com/odlaver/tepi) |
| RIS-14 | P1 | Bus factor 1: 282 commit/1 kontributor, 24 rilis/±16 hari; ritme ini tidak berkelanjutan jangka panjang | `gh api contributors` |
| RIS-15 | P2 | Tidak ada CONTRIBUTING/template issue; 2 PR fitur besar terbuka tanpa review | PR [#1](https://github.com/odlaver/tepi/pull/1)/[#2](https://github.com/odlaver/tepi/pull/2) |
| RIS-16 | P2 | Companion Android: 2 rilis, 366 unduhan, 0 issue — moat belum terbukti dan belum punya saluran keluhan | tepi-android releases |
| RIS-17 | P2 | Tidak ada build ARM64 (Windows on ARM tumbuh); .NET Framework 4.8 x64 saja | `build.cmd`/brief |
| RIS-18 | P2 | Tumpang tindih OS: Windows 11 26H1 merombak panel widget, PowerToys/Windhawk gratis; Dock pengganti taskbar berisiko tiap update Windows | [163.com](https://www.163.com/dy/article/L2EIFUG10511B8LM.html), guide |
| RIS-19 | P2 | Ketakutan malware adalah pola kategori: DynamicWin [#102](https://github.com/FlorianButz/DynamicWin/issues/102)/[#60](https://github.com/FlorianButz/DynamicWin/issues/60); NotchPixel & Nusa menjawab lewat Store/tanda tangan | guide; [Nusa](https://lumbungdata.id/nusa-dynamic-island-sudah-hadir-di-windows-ini-fitur-dan-cara-mendapatkannya/) |
| RIS-20 | P3 | i18n: Tepi ID+EN; ReyLand menambah EN; pesaing lain 12 bahasa; kegagalan font CJK/Arab di DynamicWin | DynamicWin [#88](https://github.com/FlorianButz/DynamicWin/issues/88)/[#69](https://github.com/FlorianButz/DynamicWin/issues/69) |
| RIS-21 | P2 | Monetisasi: Tepi gratis + QRIS; pesaing $0,99–$29,99 sekali bayar atau langganan (NotchNook) — donasi saja sulit membiayai 1 pengembang penuh waktu | [NotchNook pricing](https://getnotchnook.com/guides/notchnook-pricing-trial), [guide](https://notchpixel.com/guides/notch-apps-for-windows) |
| RIS-22 | P3 | Klaim performa Tepi (0,2% CPU/13 MB) sebanding dengan NotchPixel (13 MB/0%) dan lebih baik dari Nusa (~30 MB), tapi belum ada halaman metode publik seperti NotchPixel `/footprint` | [situs Tepi](https://odlaver.github.io/tepi/), [guide](https://notchpixel.com/guides/notch-apps-for-windows) |
| RIS-23 | P3 | Privasi sudah jadi kekuatan (tanpa telemetri, DPAPI, lokal); pesaing Store justru mencantumkan analitik anonim (WinIsland) — layak dijadikan materi positioning | [guide](https://notchpixel.com/guides/notch-apps-for-windows) |
| RIS-24 | P2 | Tidak ditemukan liputan media/pihak ketiga untuk Tepi; ReyLand & Nusa sudah diliput media Indonesia dan punya TikTok/Instagram | [lumbungdata](https://lumbungdata.id/nusa-dynamic-island-sudah-hadir-di-windows-ini-fitur-dan-cara-mendapatkannya/), [suarababel](https://suarababel.com/detail/45853/notchify-hadirkan-fitur-ala-dynamic-island-di-windows-11-bisa-tampilkan-notifikasi-hingga-cuaca) |

## 5 risiko positioning

1. **Terlalu luas vs pesaing spesialis.** Tepi mencakup 19 aktivitas + Dock + Start + panel 11 halaman + companion; pesaing menang dengan satu cerita (media, stats, kuota AI). Risiko: pesan pemasaran kabur, permukaan regresi besar, satu pengembang merawat semua.
2. **Gesekan dengan OS.** Mengganti taskbar/Start/quick settings adalah area paling sensitif Windows; update Windows bisa merusaknya dan pengguna akan menyalahkan Tepi. Mitigasi: sakelar aman, auto-rollback, dan jangan pernah mengubah setelan permanen tanpa jejak (sudah dicatat di situs).
3. **Distribusi unsigned tanpa Store.** SmartScreen + tuduhan malware adalah pola berulang di kategori ini (DynamicWin #102); konversi dan kepercayaan adalah plafon pertumbuhan utama Tepi saat ini.
4. **Privasi/izin sebagai risiko reputasi.** Tepi meminta clipboard, screenshot, mikrofon, notifikasi, akses HP, dan API key AI. Satu insiden atau kebocoran log akan menghapus keunggulan "lokal dan jujur"; pesaing sudah menjadikan transparansi sebagai fitur.
5. **Komoditisasi dan kloning cepat.** 34 app Windows, sebagian besar gratis/OSS, dan ReyLand (repo 27 Okt) sudah menawarkan sholat+notifikasi+HP+Store dalam dua minggu. Keunggulan Tepi harus pada eksekusi, kedalaman Indonesia, dan companion — bukan daftar fitur yang mudah disalin. Model donasi saja juga berisiko tidak membiayai laju 24 rilis/±16 hari.

## Pertanyaan terbuka / yang perlu diverifikasi

- **Jumlah pengguna aktif nyata** tidak bisa diukur dari unduhan aset GitHub (self-update ikut terhitung, tidak ada telemetri). Perlu survei opt-in atau metrik update-check agregat.
- **Isi Google Form** (`src/Feedback.cs:14`) tidak dapat diakses publik; tema keluhan nyata Tepi belum diketahui. Perlu izin pemilik data.
- **Ketersediaan winget/Store** Tepi belum diverifikasi; tidak ditemukan paket dalam riset ini.
- **Multi-monitor Tepi**: hanya ada kunci `monitor` tunggal di dokumentasi; perilaku aktual (mis. pindah otomatis) perlu dikonfirmasi tim 03/04.
- **Klaim performa situs** (0,2% CPU, 13 MB, 5 Nov 2026) belum diukur independen; sediakan halaman metode seperti NotchPixel `/footprint`.
- **PR #1/#2** terbuka tanpa review — apakah upstream menerima kontribusi? Belum ada CONTRIBUTING/issue template.
- **Target model bisnis**: bertahan gratis+QRIS atau menyiapkan "Tepi Pro" (multi-monitor, sinkron, dukungan) — keputusan positioning yang belum terlihat di publik.
- **Legal/etika**: consent rekam rapat, adzan/audio pihak ketiga, dan distribusi APK Android di luar Play Store.

## Sumber

Repo & issue: [odlaver/tepi](https://github.com/odlaver/tepi) · [releases](https://github.com/odlaver/tepi/releases) · [PR #1](https://github.com/odlaver/tepi/pull/1) · [PR #2](https://github.com/odlaver/tepi/pull/2) · [tepi-android](https://github.com/odlaver/tepi-android) · [ReyLand](https://github.com/techreyy/ReyLand/issues) · [DynamicWin](https://github.com/FlorianButz/DynamicWin/issues) · [BrimDeck](https://github.com/MoFeng2223/BrimDeck/issues) · [boring.notch](https://github.com/TheBoredTeam/boring.notch/issues) · [Nusa](https://github.com/rama2555/nusa) · [rama2555/nusa releases](https://github.com/rama2555/nusa/releases).
Situs & data produk: [situs Tepi](https://odlaver.github.io/tepi/) · [pembuat paket tema](https://odlaver.github.io/tepi/pack/) · [ReyLand](https://techreyy.github.io/ReyLand/) · [NotchPixel guide](https://notchpixel.com/guides/notch-apps-for-windows) · [NotchNook](https://getnotchnook.com/) · [NotchNook pricing](https://getnotchnook.com/guides/notchnook-pricing-trial) · [Alcove](https://alcovetasks.com/) · [Windhawk island mod](https://windhawk.net/mods/dynamic-island-for-windows).
Media: [lumbungdata.id — Nusa](https://lumbungdata.id/nusa-dynamic-island-sudah-hadir-di-windows-ini-fitur-dan-cara-mendapatkannya/) · [suarababel — Notchify](https://suarababel.com/detail/45853/notchify-hadirkan-fitur-ala-dynamic-island-di-windows-11-bisa-tampilkan-notifikasi-hingga-cuaca) · [163.com — panel widget Win11 26H1](https://www.163.com/dy/article/L2EIFUG10511B8LM.html).
Aset screenshot Tepi (diunduh ke `%TEMP%\tepi-site`, terverifikasi): `assets/img/a-beranda.webp` (mockup Android), `dock.webp` (Dock), `place-0.webp` (island + Dock di desktop), `q-agents.webp` (kuota agent).
