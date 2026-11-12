# Arsitektur, Engineering, dan Rilis — Tepi
> Analisis oleh analis engineering/maintainability. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: baca kode + docs + ukur read-only (repo, proses PID 41828, log pengguna) + grep. Tanggal: 2026-11-12.

## Ringkasan eksekutif

Tepi padat dan konsisten: 144 file, 56.346 baris (52.017 non-kosong), build satu perintah tanpa SDK/NuGet. Tapi 98 dari 144 file adalah `partial class Island` dengan ±257 field dan 74 metode (`Island.cs` 1.899 baris). Nol test, analyzer, dan linter; parser besar (Ics 1.196 baris, PdfLite 1.189 baris, JSON di `Base.cs`) tak pernah diuji otomatis. Biner `Tepi.exe` (1.665.024 byte) dilacak git bersama 40 versi lamanya, sementara build source 1.727.000 byte → artefak rilis tak terbukti dari commit. i18n memakai teks Indonesia sebagai kunci (1.627 entri, fallback senyap), settings 143–155 kunci tanpa schema/migrasi. Observability minim: log 2×512 KB tanpa versi/OS, tanpa dump/laporan, satu error berulang = 42% baris log. Skor engineering **10/28**.

## Skor / penilaian

| Dimensi | Skor (0–4) | Alasan singkat |
|---|---|---|
| Arsitektur | 1 | Satu god-object partial class; modul dipisah nama file; state dibagi lewat field & static global |
| Testability | 1 | Nol test/CI test; parser tanpa golden test; seam `Pilot*` tak berimplementasi di repo |
| i18n | 2 | Kamus lengkap & konsisten, tapi kunci = copy Indonesia, fallback senyap, tanpa validasi |
| Settings | 2 | Tulis atomik, ekspor ber-allowlist, DPAPI token; tapi tanpa schema/tipe/migrasi, default tersebar |
| Build/release | 1 | Build 1 perintah, CI build+hash; tapi biner masuk repo, tak reproducible, unsigned |
| Observability | 1 | Rotasi log + pemulihan taskbar; tanpa dump/laporan, log tanpa konteks, 109 catch kosong |
| Dokumentasi | 2 | 10 docs bagus dan jujur soal unsigned; drift ukuran exe, performa basi, "semua kunci" salah |

**Total 10/28.**

## Yang sudah bagus

1. **File & rahasia berlapis.** `AtomicFile` (tmp→`File.Replace`, fallback copy) di `Base.cs:455-475`; `Vault` DPAPI current-user (`Base.cs:477-507`) dipakai untuk API key AI (`Ai.cs:63-65`), sesi Kulia (`Kulia.cs:127`), Notion, Todoist, kunci HP. Ekspor setelan tak pernah membawa rahasia (`SettingsIO.cs:14-34`).
2. **Update in-app hati-hati.** Aset hanya dari prefix rilis resmi (`Update.cs:17`), wajib HTTPS + SHA-256 terhadap digest rilis (`Update.cs:85-109`), backup `Tepi.old.exe` + rollback (`Update.cs:112-139`), kontinuitas Authenticode bila kelak ditandatangani (`Update.cs:114-116`, `Signature.cs`). Signing belum ada dan itu dinyatakan terbuka (`docs/privasi-keamanan.md:69`).
3. **Disiplin thread dasar.** Callback jaringan/timer kembali ke UI lewat `Post`/`BeginInvoke` (mis. `Life.cs:60-68`); log thread-safe + dedupe 60 detik (`Base.cs:24-52`); setelan dibaca `FileShare.ReadWrite` (`Base.cs:103`).
4. **Seam test/profiling tanpa dependensi baru.** `TEPI_DIR`/`TEPI_HOME` mengisolasi data+mutex (`Base.cs:59-81`), `TEPI_FPS` profil per bagian (`Base.cs:509-561`); `Ics.cs` hampir murni (0 referensi UI) — paling siap diuji.

## 10 prioritas utama

| ID | Sev | Judul | Usaha | Quick win |
|---|---|---|---|---|
| TEK-01 | P1 | Satu `partial class Island` 98 file, ±257 field berbagi state | L | tidak |
| TEK-02 | P1 | Nol test; parser Ics/PdfLite/Json/Suruh tanpa verifikasi | M | sebagian |
| TEK-03 | P1 | `Tepi.exe` dilacak git, tak reproducible, unsigned | M | ya (hapus+ignore) |
| TEK-04 | P1 | Log tanpa konteks, crash tanpa laporan, error membanjiri log | M | sebagian |
| TEK-05 | P1 | i18n: kunci = teks Indonesia, 32 titik bocor senyap | M | ya (validator) |
| TEK-06 | P1 | Settings tanpa schema/validasi/migrasi; token plaintext | M | sebagian |
| TEK-07 | P1 | Frame loop UI + GC penuh paksa tiap menit; memori 172 MB | M | tidak |
| TEK-08 | P1 | Aksesibilitas arsitektural: 103 hit target vs 53 nama, tanpa pohon UIA | M–L | sebagian |
| TEK-09 | P2 | Duplikasi P/Invoke/struct (68 nama ganda) & magic number warna | M | ya (struct kembar) |
| TEK-10 | P2 | Hook global (22 hotkey, 6 hook) & taskbar disembunyikan dengan state persisten | M | sebagian |

## Temuan detail (P1 dulu)

### TEK-01 [P1] Satu god-object `partial class Island` berbagi seluruh state
- **Area**: Arsitektur. **Bukti**: `partial class Island` di 98 dari 144 file (`Island.cs:49`); `Island.cs` 1.899 baris, 74 metode, ±257 deklarasi field level kelas (`Island.cs:51-103`); 14 file >1.000 baris, 35 file >500 baris. Konstruktor memasang 9 timer + `Application.Idle` (`Island.cs:97-98,105-143`); `OnLoad` memanggil 40+ fungsi berurutan (`Island.cs:201-249`).
- **Masalah**: batas modul hanya nama file. `Lang.English`, `Ink.Light`, `Fmt.H24`, `Anim.Reduced` adalah static global (`Lang.cs:10`, `Ink.cs:92`, `Base.cs:233-235,579`) yang diubah dari instance (`Prefs.cs:115-120`) sementara render membacanya langsung (`Island.cs:771-896`). Event `UpdateChanged` harus dibersihkan manual (`Prefs.cs:1414-1415`) — pola yang tak terulang di 186 langganan delegate lain.
- **Dampak**: tiap perubahan satu fitur berisiko regresi lintas fitur; mustahil membuat dua instance (multi-monitor) atau menguji modul tanpa `Form`; startup mengerjakan puluhan hal sinkron sebelum frame pertama (proses 16:56:41 → log pertama 16:56:45).
- **Perbaikan**: jadikan kelas statis berdiri sendiri yang sudah terisolasi (`Ics`, `PdfLite`, `Signature`), lalu modul ber-state (Quota, Converter, Phone, Rapat) ke kelas `XxxFeature` dengan antarmuka sempit (`ISettings`, `IPost`, `IKick`); `Island` tinggal komposisi + render.
- **Usaha**: L. **Quick win**: tidak.

### TEK-02 [P1] Nol test otomatis; parser besar tanpa golden test
- **Area**: Build/Testability. **Bukti**: tak ada `.sln`/`.csproj`/file test (glob kosong); `build.cmd:13-20` mengompilasi `src\*.cs` wildcard jadi winexe; CI hanya build+hash+upload (`.github/workflows/build.yml:17-26`). Seam `partial void PilotStart/PilotFrame` (`Island.cs:252-253`) dan `PilotPointer/PilotThrough` (`Mini.cs:47-48`) tanpa implementasi di repo (diinjeksi lewat arg2 `build.cmd:11`). Parser: `Ics.cs` 1.196 baris (murni), `PdfLite.cs` 1.189 (4 referensi UI), `Suruh.cs` bercampur `partial class Island`+WinForms, `Json` menumpang di `Base.cs:282-392` bersama `AutoStart` yang butuh WinForms.
- **Masalah/Dampak**: tak ada jaring regresi untuk 144 file; bug parser hanya terlihat saat pengguna memakai file nyata; dukungan iCal/PDF tak bisa dibuktikan untuk variasi file.
- **Perbaikan**: `tests.cmd` mengompilasi `Ics.cs` (+`PdfLite.cs` setelah referensi UI dicabut) jadi exe console dengan fixture `.ics`/`.pdf` dan pembanding output teks; pindahkan `Json` ke `Json.cs` bebas WinForms; ekstrak `SuruhParser.Parse(string)`; jalankan di CI sebelum build.
- **Usaha**: M. **Quick win**: sebagian (golden test Ics = S).

### TEK-03 [P1] Biner `Tepi.exe` masuk repo, tidak reproducible, belum ditandatangani
- **Area**: Build/Release. **Bukti**: `git ls-files Tepi.exe` → terlacak, HEAD 1.665.024 byte (=1.626 KB); 40 objek `Tepi.exe` di histori = 24,97 MB mentah (pack repo 9,66 MiB / 297 commit); 30 commit menyentuh biner; `.gitignore` hanya `*.pdb`. Build memakai csc dari `%WINDIR%` tanpa pin (`build.cmd:5,13`), tanpa `/deterministic`, source wildcard (`build.cmd:20`). Build source terverifikasi Lead **1.727.000 byte** ≠ biner komit. `README.md:17` menulis "1.626 KB" — cocok dengan biner komit, basi setelah rebuild. Belum ada signing (`docs/privasi-keamanan.md:69`), jadi cek kontinuitas Authenticode (`Update.cs:114-116`) belum aktif.
- **Masalah/Dampak**: biner bisa diganti lewat commit tanpa jejak source; pengguna tak bisa memverifikasi exe = hasil build commit; SmartScreen tetap muncul; hash CI hanya dicetak, tidak dipublikasikan sebagai attestation.
- **Perbaikan**: `git rm --cached Tepi.exe` + `Tepi*.exe` di `.gitignore`; rilis hanya via CI (artifact + SHA-256 di release notes); aktifkan Authenticode (atau SignPath OSS); pin compiler + `/deterministic`.
- **Usaha**: M. **Quick win**: ya (hapus biner+ignore = S).

### TEK-04 [P1] Observability: log tanpa konteks, crash tanpa laporan, satu error membanjiri log
- **Area**: Observability/Diagnosa. **Bukti**: `%APPDATA%\Tepi\tepi.log` (`Base.cs:18`), rotasi 512 KB → `.1` = maks ±1 MB (`Base.cs:34-41`); format hanya timestamp + pesan, tanpa versi/OS/thread (`Base.cs:44`); 282 `Log.Write`; kegagalan menulis log ditelan `catch { }` (`Base.cs:51`). Crash hanya ditulis ke log + `Taskbar.Restore`, tanpa minidump/MessageBox (`Program.cs:48-55`). Terukur: log 135.668 byte / 2.684 baris memuat **1.128 baris `notif read: WinRT timeout`** (`Notifs.cs:251`, `Media.cs:322`) + ±350 baris `memory N MB private, collecting` (`Memory.cs:42`). `Feedback.cs` hanya kirim teks+versi+Windows ke Google Form (`Feedback.cs:14-16,45-46`); log tak ikut.
- **Masalah/Dampak**: tak ada tombol "simpan diagnosa"; laporan "Tepi hilang/hang" tak bisa ditindaklanjuti; error nyata (notifikasi gagal dibaca) tak pernah tampil di UI — 109 dari 448 catch kosong (24%) mengubur kegagalan (`Speech.cs:101`, `PdfLite.cs:232,237`, `Native.cs:144`). Log 1 MB penuh satu error sehingga error baru cepat tergeser.
- **Perbaikan**: header per sesi (versi, OS build, arsitektur, locale); rate-limit log per kategori; tombol "Simpan diagnosa" (zip log + cuplikan settings tanpa rahasia); daftarkan `LocalDumps` Windows; buka `tepi.log` dari tray.
- **Usaha**: M. **Quick win**: sebagian (header+ekspor = S).

### TEK-05 [P1] i18n: kunci = teks Indonesia, fallback senyap, tanpa validasi cakupan
- **Area**: i18n. **Bukti**: satu kamus 1.627 entri `{ "Indonesia", "English" }` (`Lang.cs:11-1649`); `T()` mengembalikan id apa adanya bila tak ada di kamus, tanpa log (`Lang.cs:1651-1655`); `F()` langsung `string.Format` (`Lang.cs:1657-1660`). 1.281 panggilan `Lang.T` + 202 `Lang.F`; 1.355 kunci literal unik; **32 kunci literal tak ada di kamus** (di UI Inggris tampil Indonesia: "Atur pintasan", "Cari catatan", "Daftar tugas", "Tambah tugas", "Catatan kosong", "Sematkan"); 284 entri kamus tanpa pemakaian literal; 175 entri berplaceholder; 111 baris teks Indonesia di luar `Lang` (`WhatsNew.cs:26-36` memakai kalimat rilis sebagai kunci, `Kit.cs:734`). Rasio EN/ID rata-rata 0,973 tapi 58 entri >1,4×; label pendek ekstrem: "HP"→"Phone" (2,5×), "Rabu"→"Wednesday" (2,25×), "Dikte"→"Dictation" (1,8×) — di panel ±330 px (`Island.cs:51`).
- **Masalah/Dampak**: mengubah copy Indonesia memutus terjemahan karena key berubah, tanpa alarm; fallback senyap menyembunyikan 32 kebocoran; `FormatException` di `F()` hanya ditangkap render guard (`Island.cs:738-739`) → view bisa kosong tanpa pesan; label memanjang tak teruji.
- **Perbaikan**: tanpa tulis ulang: (1) skrip CI membandingkan literal `Lang.T/F` vs kamus — gagal bila kunci hilang/duplikat/jumlah `{n}` beda; (2) `T()` mencatat fallback sekali per kunci; (3) migrasi bertahap ke ID stabil (`setlang.label`) mulai dari string baru + 32 entri bocor; (4) uji lebar teks EN pada label tetap.
- **Usaha**: M. **Quick win**: ya (validator+log fallback = S).

### TEK-06 [P1] Settings: 143–155 kunci tanpa schema/validasi/migrasi; token plaintext
- **Area**: Settings. **Bukti**: brief menyebut 143 kunci; grep menemukan **155 kunci literal unik** (30 tanpa prefix; `dictate.*` 11, `dockbar.*` 10, `panel.*` 6, `prompter.*` 6), sedangkan `docs/pengaturan.md:60` mengklaim "Semua kunci" padahal tabelnya 114 kunci unik → ±41 kunci tak terdokumentasi (`settings.v`, `agent.token`, `dockbar.winkey`, `start.pins`, `idle.right`, `tabs.convert`). Tanpa schema/tipe; **236 default inline** tersebar (94 `Get`, 45 `GetInt`, 97 `GetBool`); `settings.Save()` dipanggil 152× termasuk tiap toggle menulis ulang seluruh file (`Base.cs:119-134`); side effect per kunci berupa switch string (`Prefs.cs:82-113`). Migrasi hanya `settings.v` + `MigrateTabs` (`Tabs.cs:49-66`). `Portable` 122 entri + `KeepOnReset` 10 entri disinkronkan manual (`SettingsIO.cs:14-34`). `agent.token` 48 karakter plaintext di `settings.ini` (`Life.cs:452-458`, terverifikasi di profil mesin ini) dan token sama ditulis ke `~/.claude*/settings.json` (`HookSetup.cs:94,101`).
- **Masalah/Dampak**: nilai korup tak dilaporkan (`GetInt` fallback senyap, `Base.cs:144-156`); kunci baru mudah lupa didokumentasikan/di-reset/di-ekspor (drift ±41 kunci sudah terjadi); 152 save = tulis file penuh tiap klik; rahasia lokal terekspos.
- **Perbaikan**: satu tabel `KeySpec` (Nama, Tipe, Bawaan, Rentang, Secret, Portable, ResetKeep, Deskripsi) sebagai sumber tunggal load/validasi/ekspor/docs; validasi saat load + log; bump `settings.v` per perubahan skema; debounce `Save`; `agent.token` via `Vault`; redaksi Secret di log.
- **Usaha**: M. **Quick win**: ya (generator tabel docs + dokumentasikan 41 kunci = S).

### TEK-07 [P1] Siklus hidup UI: satu thread, 9 timer, GC penuh paksa tiap menit, 244 thread
- **Area**: Performa/Arsitektur. **Bukti**: 9 timer + `Application.Idle` (`Island.cs:97-98,105-143`); loop frame `OnIdle` dengan `DwmFlush` + `Thread.Sleep(8)` di UI thread (`Island.cs:632-654`); `Frame()` 684-756; `Render()` 126 baris (771-896). `Memory.cs:19` menetapkan `LeakMb = 150`; `MemoryWatch` tiap menit memanggil `Trim()` = `GC.Collect()` dua kali + `WaitForPendingFinalizers` + `SetProcessWorkingSetSize` (`Memory.cs:34-49,86-95`). Terukur PID 41828: WS 46,1 MB, private 84,6 MB, 3.251 handle, **244 thread**; log mencatat private 172 MB sebelum restart; sampel CPU 10 detik 2,19% satu core (kondisi app saat sampel tak dikontrol).
- **Masalah/Dampak**: leak guard menutupi kebocoran (tumbuh 150–172 MB lalu dipangkas) alih-alih menyelesaikannya; GC penuh + trim di UI thread berpotensi hitch; memori jauh di atas klaim `docs/performa.md:11` ("sekitar 22 MB"); 244 thread untuk overlay sangat tinggi.
- **Perbaikan**: ganti trim buta dengan pengukuran alokasi (`GC.GetTotalAllocatedBytes` baseline) + audit cache/Bitmap tak di-dispose; jalankan `Trim` hanya saat idle penuh; kerja berat tetap di thread frost (`Glass.cs:230`); targetkan <100 thread; ukur startup→frame pertama.
- **Usaha**: M. **Quick win**: tidak.

### TEK-08 [P1] Aksesibilitas arsitektural: UI owner-drawn nyaris tanpa pohon UIA
- **Area**: Aksesibilitas/Arsitektur. **Bukti**: seluruh UI digambar ke satu kanvas (`Island.cs:771-896`, `Panel.cs`, `DockPaint.cs`); target klik didaftarkan manual (103 baris `Hit`/`hits.Add`); hanya 53 pemakaian `AccessibleName`, 6 `CreateAccessibilityInstance`, 2 `RaiseAutomationNotification` (`A11y.cs:39`). `A11y.cs` hanya mengumumkan teks (`A11y.cs:22-46`) dan bergantung pada `ScreenReaderOn()` + setelan `a11y.announce`.
- **Masalah/Dampak**: Narrator/NVDA tak bisa menelusuri tab, tombol, slider, daftar — hanya "toast" suara sesekali; pengguna screen reader/keyboard praktis tak bisa memakai mayoritas fitur; tak ada jalur UIA untuk otomasi uji.
- **Perbaikan**: tanpa rewrite: `AccessibleObject`/`AutomationPeer` generik yang memetakan daftar `hits` (`Island.cs:92`) jadi child UIA (role, name, action, state); ekspos tab list & baris list sebagai virtual children; isi nama aksesibel untuk 103 target (baru 53).
- **Usaha**: M–L. **Quick win**: sebagian (nama 20 kontrol utama = S).

### TEK-09 [P2] Duplikasi P/Invoke, struct kembar, dan magic number
- **Area**: Duplikasi. **Bukti**: ±316 deklarasi `extern` (317 `[DllImport]`); **68 nama fungsi dideklarasikan >1 kali** — `GetWindowThreadProcessId` ×8 (`AgentPrompt.cs:133`, `DockApps.cs:59`, `DockKeys.cs:106`, `DockShell.cs:472`, `DockTray.cs:68`, `Locks.cs:15`, `Mini.cs:43`, `Taskbar.cs:12`), `CloseHandle` ×6, `SendMessage` ×5, `IsWindow` ×5, `OpenProcess` ×5. Struct kembar: `KEYBDINPUT`/`INPUT` (`AgentPrompt.cs:18,21` vs `DockKeys.cs:56,59`), `RECT` (`AgentPrompt.cs:789` vs `Native.cs:28`), `POINT` (`Menus.cs:23` vs `Native.cs:19`), `SIZE`/`BITMAPINFOHEADER` (`Shelf.cs:469,481` vs `Native.cs:22,34`). Warna: 85 `Color.FromArgb` + 9 hex (`Prefs.cs:177-178,808-809`, `Redact.cs:50-51`) di luar token `Ink.cs`; konstanta ukuran `Gap/Pad/MaxH` (`Island.cs:51`).
- **Masalah/Dampak**: definisi kembar bisa beda layout/CharSet dan tetap lolos kompilasi; memperbaiki bug marshalling berarti mengulang di 5–8 tempat → bug native halus (crash/akses ditolak).
- **Perbaikan**: satu `Interop.cs` untuk semua `DllImport`+struct, hapus duplikat; jadikan warna/ukuran token di `Ink.cs`/`Kit.cs`; cegah duplikat baru lewat grep CI.
- **Usaha**: M. **Quick win**: ya (satukan struct kembar = S).

### TEK-10 [P2] Hook global & taskbar: 22 hotkey, 6 hook, taskbar disembunyikan dengan state persisten
- **Area**: Integrasi OS. **Bukti**: 22 definisi hotkey (`Hotkeys.cs:19-44`), 6 `RegisterHotKey`, 6 `SetWindowsHookEx` (`DockKeys.cs:79`, `Menus.cs:28`, `Dictate.cs:105`), 3 `SetWinEventHook` (`Island.cs:167-170`) + `Taskbar.cs:99`. `Taskbar.Hide` menyimpan `dockbar.taskbar.state` + `dockbar.taskbar.hidden` lalu `Save()` **sebelum** menyembunyikan taskbar (`Taskbar.cs:66-86`); `Restore` hanya dari handler fatal (`Program.cs:53`) atau start berikutnya (`Island.cs:227`); `keybd_event` memalsukan tombol Win (`Taskbar.cs:134-140`).
- **Masalah/Dampak**: bila proses mati paksa (Task Manager, BSOD, crash native/OOM) taskbar tetap tersembunyi sampai Tepi dijalankan lagi; bila Tepi gagal start, tak ada watchdog. Hook keyboard global bisa bentrok dengan aplikasi lain dan sulit didiagnosis. Pulih saat start berikutnya, jadi dinilai P2 (mendekati P0).
- **Perbaikan**: watchdog proses terpisah/scheduled task; tombol "Pulihkan taskbar" di tray; batasi hook keyboard saat Dock aktif; matriks uji bentrok hotkey.
- **Usaha**: M. **Quick win**: sebagian (tombol restore = S).

## Temuan ringkas lanjutan

| ID | Sev | Temuan | Bukti |
|---|---|---|---|
| TEK-11 | P2 | Urutan inisialisasi rapuh: setelan dibaca di konstruktor sebelum `Lang.English`/`Anim` diterapkan | `Island.cs:114-118` vs `206`; `201-249` |
| TEK-12 | P2 | Metode raksasa: `Prefs.Build` 504 baris (switch 23 halaman), `FrostLoop` 133, `Render` 126, `DrawSchedulePage` 136 | `Prefs.cs:883-1386`; `Glass.cs:230`; `Island.cs:771-896`; `Schedule.cs:83` |
| TEK-13 | P2 | 39 field `static` mutable lintas instance (`Ink.Base/Epoch`, `Fmt.H24`, `Kit.ByMouse`, `Notifs.ExtraApps`) → sulit dites/diinstansiasi ganda | `Ink.cs:91-138`; `Kit.cs:15`; `Base.cs:233-235,579`; `Notifs.cs:91` |
| TEK-14 | P2 | 186 langganan `+= delegate/new` tanpa satu pun `-= delegate`; sebagian ke publisher panjang umur sehingga jendela bisa tertahan | `WorkWindow.cs` 21 langganan; `Prefs.cs:1414-1415` satu-satunya pola bersih |
| TEK-15 | P2 | Konkurensi tanpa cancellation: 30 `new Thread`, 53 ThreadPool/Task, 61 `BeginInvoke`, 26 `Thread.Sleep` termasuk di UI thread | `Island.cs:652`; `DockQuick.cs:200`; `Converter.cs:1236` |
| TEK-16 | P2 | CI hanya memverifikasi kompilasi: tanpa test/lint/warnaserror/smoke launch; hash hanya dicetak | `.github/workflows/build.yml:17-26`; `build.cmd:13` |
| TEK-17 | P2 | Versi hardcoded di tiga tempat (kode, WhatsNew, README) | `Life.cs:86`; `WhatsNew.cs:23`; `README.md:21` |
| TEK-18 | P2 | Tanpa installer; update menulis `Tepi.new/old.exe` di folder exe → gagal di `Program Files` | `Update.cs:111-139`; `docs/privasi-keamanan.md:59` |
| TEK-19 | P2 | `.gitignore` hanya `*.pdb`; artefak update tidak diabaikan | `.gitignore` (1 baris) |
| TEK-20 | P2 | `HookSetup` menulis ulang `~/.claude*/settings.json` dengan serializer sendiri, backup sekali, token plaintext di sana | `HookSetup.cs:43-63,94,101,179-194` |
| TEK-21 | P2 | Drift dokumen: performa diukur pada 2.1/2.4/2.5 padahal produk 2.6.1; klaim 22 MB vs 84,6/172 MB terukur; "semua kunci" settings salah | `docs/performa.md:5-13,11`; `docs/pengaturan.md:60`; `Life.cs:86` |
| TEK-22 | P3 | Teks panjang EN bisa terpotong keras tanpa indikator | `Base.cs:655-661`; 58 entri EN >1,4×; "Rabu"→"Wednesday" 2,25× |

## Lintas area

- Notifikasi gagal dibaca terus-menerus (1.128 baris log) — relevan untuk area Fungsi (`Notifs.cs:251`).
- 109 catch kosong (24%) membuat kegagalan fitur tak terlihat — relevan untuk UX/error states.

## Pertanyaan terbuka / yang perlu diverifikasi

1. **Kenapa build source 1.727.000 byte vs biner komit 1.665.024 byte?** Perlu dua build berurutan dari commit sama di mesin bersih untuk memastikan non-determinisme compiler (tidak dilakukan di run ini).
2. **Berapa waktu startup→frame pertama?** Belum diukur; perlu `TEPI_FPS=1` + ETW di mesin bersih.
3. **Apakah 284 entri kamus tanpa pemakaian literal benar-benar mati**, atau dipakai lewat variabel (mis. `Lang.T(PageNames[...])`)? Perlu instrumentasi fallback.
4. **Apakah angka 143 kunci settings** dihitung dari revisi docs lain? Ukuran saya: 155 di kode, 114 di docs; perlu rekonsiliasi.
5. **Apakah `notif read: WinRT timeout` bug produk atau lingkungan mesin ini?** Perlu uji mesin bersih.
6. **Apakah taskbar hilang saat force-kill pernah dilaporkan?** Cek issue upstream + uji kill paksa pada mode Dock menggantikan taskbar.
