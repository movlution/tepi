# Fungsi, Keandalan, dan Privasi — Tepi
> Analisis oleh function-audit. Bagian dari analisis menyeluruh; lihat `00-brief.md`.
> Metode: baca kode + docs + ukur proses yang sedang berjalan (PID 41828, tidak dijalankan ulang). Tanggal: 2026-11-12.

## Ringkasan eksekutif

Tepi 2.6.1 punya kelengkapan fitur luar biasa untuk aplikasi 1,7 MB tanpa dependensi, dengan banyak pengamanan matang (HTTPS-only, backoff sumber, key AI DPAPI, SHA-256 unduhan offline). Masalah utamanya bukan jumlah fitur, melainkan **keandalan jangka panjang dan kejujuran status**: di mesin ukur **Pesan mati total** karena `GetNotificationsAsync` timeout ~10.000× dalam 19,4 jam log tanpa pesan ke pengguna; **memori sesi sebelumnya bertahan 151–175 MB private** (klaim dokumen ~22 MB) dan guard kebocoran hanya mencatat log; **handle/thread naik monoton saat idle** (2949→3598, 219→276); **transkrip rapat menghapus audio sebelum transkrip aman** (kehilangan data nyata). Privasi relatif baik; sisa risiko: `agent.token` plaintext, rilis unsigned, bridge HP di semua antarmuka, ditambah tujuh celah fitur yang wajar diharapkan. Skor fungsi: **23/35**.

## Skor / penilaian

| Dimensi | Skor | Alasan singkat (bukti) |
|---|---|---|
| Kelengkapan vs dokumentasi | 4/5 | Hampir semua fitur `docs/fitur.md` ada di kode; "Tugas dan catatan" (`Work.cs`) malah tak terdokumentasi di `fitur.md` |
| Keandalan & failure mode | 2/5 | Pesan mati di mesin ukur (log), rapat bisa kehilangan audio, tanpa cache offline |
| Degradasi tanpa jaringan/dependensi | 3/5 | STT offline fallback + chip format redup (baik); AI teks & agenda butuh jaringan, unduhan model tanpa resume |
| Integritas data | 3/5 | `AtomicFile` dipakai luas (baik); audio rapat dihapus walau transkrip gagal |
| Privasi/keamanan sisi pengguna | 4/5 | DPAPI, HTTPS-only, loopback+token, OTP bersih; `agent.token` plaintext, update unsigned |
| Performa pemakaian | 2/5 | Klaim 22 MB / 0,2–1% vs ukur 35,7 MB private WS (82–88 MB commit) / ~2,3% satu core; thread+handle creep |
| Update/instalasi | 3/5 | SHA-256 + HTTPS + restore exe (baik); unsigned, digest dari GitHub API (TOFU) |

**Total 23/35.** Rubrik: kelengkapan, keandalan, degradasi, integritas, privasi, performa, update.

## Yang sudah bagus

1. **Jaringan defensif**: `Fetch` hanya HTTPS, body dibatasi, redirect manual, token tak menyeberang origin (`Sources.cs:22-128`); Notion diserialkan 350 ms, `Retry-After` 429 dihormati, backoff 2–60 menit (`Notion.cs:128-141`, `Sources.cs:439-450`).
2. **Rahasia pengguna**: key AI & token integrasi DPAPI per akun Windows (`Base.cs:477-507`, `Ai.cs:61-65`); sesi Kulia di vault (`Kulia.cs:57,127`); ekspor/impor setelan berwhitelist tanpa token (`SettingsIO.cs:14-34`).
3. **Hook agent aman**: hanya `127.0.0.1`, token sebelum body, `Origin` browser ditolak, compare waktu-konstan, request ≤10 dtk (`Agents.cs:126-143,199-204,258-265,287`); OTP berflag anti-history/cloud + hapus clipboard 60 dtk (`Handset.cs:133-158`).
4. **Operasi berkas berhati-hati**: Rapikan melewati berkas terkunci/partial, tak menimpa, undo persisten (`Tidy.cs:97-136,191-200`); Rak menolak UNC & `.lnk` (`Shelf.cs:39-49`); konversi menghapus output parsial (`Converter.cs:366-376`); tulisan atomik (`Base.cs:454-475`).

## 10 prioritas utama

| ID | Sev | Judul | Usaha | Quick win |
|---|---|---|---|---|
| FUN-01 | P1 | Pesan mati: `notif read: WinRT timeout` ~10.000×, tanpa error UI | M | ya |
| FUN-02 | P1 | Memori 151–175 MB sesi lalu; guard 150 MB hanya log tiap menit | M | sebagian |
| FUN-03 | P1 | Thread 219→276 & handle 2949→3598 saat idle (~1 handle/detik) | M | tidak |
| FUN-04 | P1 | Transkrip rapat gagal = audio rapat terhapus (kehilangan data) | S | ya |
| FUN-05 | P1 | Unduh model whisper tanpa resume; 574 MB mulai dari nol | S | ya |
| FUN-06 | P2 | Tak ada cache disk tugas/jadwal → buka offline = kosong | M | tidak |
| FUN-07 | P2 | AI tanpa retry: satu timeout 90–120 dtk = dikte/perintah hilang | S | ya |
| FUN-08 | P2 | 109 catch kosong (448 total) menelan kegagalan aksi pengguna | S | ya |
| FUN-09 | P2 | Bridge HP `TcpListener(IPAddress.Any)` di Wi-Fi publik | S | ya |
| FUN-10 | P2 | Update unsigned, SHA hanya dipercaya dari GitHub API | M | tidak |

## Tabel kesiapan fitur

| Fitur | Status | Risiko utama |
|---|---|---|
| Island/Mini, letak, tema, aksesibilitas keyboard | Matang | CPU idle 1,5–3,4% satu core |
| Timer, pengingat, jadwal sholat | Matang | Kalkulasi offline murni (`Reminders.cs:10-36`) |
| Musik + lirik | Matang | Cache + backoff 10–120 dtk (`Lyrics.cs:60-100,173-185`); judul lagu masuk log |
| Rak, Clipboard, Rapikan, Flashdisk, Unduhan, Teleprompter | Matang | Batas operasi berkas jelas (`Shelf.cs:39-49`, `Tidy.cs:97-136`) |
| Ubah format + OCR/ZIP/Kompres | Matang* | Butuh ffmpeg/LibreOffice/Pandoc/Word; chip redup + pesan alat hilang (`Converter.cs:217-296`) |
| Kulia / Notion / Todoist / iCal | Matang | Error granular + backoff; token mati = Stop sampai diperbaiki (`Sources.cs:141-155,439-450`) |
| Dikte (online/offline) | Rapuh | Fallback offline ada, tapi STT gagal membuang audio di memori (`Dictate.cs:263-286`) |
| Suruh Tepi (offline intents) | Matang | Whitelist aksi ketat, tanpa shell/berkas (`Suruh.cs:248-277`) |
| Agent coding + izin + kuota | Rapuh | Menulis config agent pihak ketiga (`HookSetup.cs:43-101`); format log Codex/Copilot bisa berubah |
| Dock / ganti taskbar | Rapuh | Beban memori/thread terbesar; mengganti taskbar OS berisiko saat crash (mitigasi `Program.cs:48-53`) |
| Pesan / notifikasi Windows | **Rusak di mesin ukur** | WinRT timeout berulang, tanpa UI (`Notifs.cs:230-252`) |
| Transkrip rapat | Rapuh | Audio hilang bila transkripsi gagal (`Rapat.cs:133-136`) |
| HP companion | Rapuh (belum diuji) | Bind semua antarmuka; pairing 5 percobaan; tanpa TLS |
| Kuota AI (4 agent) | Rapuh | Membaca format internal log agent (`Quota.cs:600-643`); tampil saja, tanpa batas |
| Cuaca | Matang fungsional | Kegagalan hanya log, kartu diam basi (`Weather.cs:48-55`) |
| Mode berbagi layar, screenshot, mode rapat | Matang | Heuristik judul jendela tiap 2 dtk (`Share.cs:39-56`) |
| Update mandiri | Fungsional | Unsigned; digest dari API GitHub yang sama |
| Skrip `--notify`/`--run` | Matang | Token sama dengan hook; 1 toast/0,5 dtk (`Plugin.cs:55-58`) |
| Tur/What's New/Kirim saran | Matang | Saran default menyertakan versi + build Windows (`Feedback.cs:38-47,68`) |

## Temuan detail

### [FUN-01][P1] Fitur Pesan mati total di mesin ukur tanpa satu pun pesan ke pengguna
- **Area**: Integrasi / Pesan / Observability.
- **Bukti**: `tepi.log` 19,4 jam berisi 1128 baris `notif read: WinRT timeout` + counter dedupe (`previous line 11 more times`) ≈ **10.006 percobaan gagal**, ±12/menit (≈tiap 5 dtk). `Notifs.cs:230-252` menangkap exception lalu hanya `Log.Write` dan mengulang; baca notifikasi memakai `MediaService.Await` timeout 5 dtk (`Media.cs:317-327`). Tidak ada state error yang digambar panel Pesan.
- **Masalah**: `UserNotificationListener.GetNotificationsAsync` gagal terus (dugaan: build Windows 11 28120 + antrean notifikasi), tab Pesan tak pernah terisi; pengguna tak tahu fitur rusak.
- **Dampak**: Fitur andalan persona mahasiswa (WhatsApp/Telegram di island) mati senyap; log 132 KB menutupi error lain.
- **Perbaikan**: backoff eksponensial setelah 3 kegagalan (5→30→120 dtk) + status `Error` di empty-state tab Pesan + toast sekali; fallback baca DB SQLite (`ChangeKey` sudah ada, `Notifs.cs:157-188`).
- **Usaha**: M. **Quick win**: ya.

### [FUN-02][P1] Memori jauh di atas klaim dan guard kebocoran tidak menurunkan memori
- **Area**: Performa / Stabilitas.
- **Bukti**: log memuat **366 baris** `memory 15x MB private, collecting` — sesi sebelum restart bertahan **151→175 MB private** (01:54–16:55), jadi `Trim()` (`Memory.cs:86-95`) tak menurunkan private bytes. Proses sekarang: private working set ("Memori" Task Manager) **35,7 MB**, commit **81,8–88,0 MB**, peak WS **130,4 MB**; klaim dokumen ~22 MB (`performa.md:11`).
- **Masalah**: guard hanya mencatat lalu GC+EmptyWorkingSet; GC tak mengembalikan memori native (GDI+/kaca/dock/thumbnail), ambang 150 MB terlalu tinggi sehingga kebocoran lolos berjam-jam.
- **Dampak**: Laptop 4–8 GB dengan Dock aktif bisa berat/kehabisan memori — Tepi tampak "aplikasi berat" meski klaimnya ringan.
- **Perbaikan**: turunkan `LeakMb` ke ~90 MB; log metrik per komponen (bitmap `Glass.cs`/`DockFrost.cs`, thumbnail Rak, ikon tray) tiap menit; trim saat panel ditutup; uji 8 jam Dock+musik.
- **Usaha**: M. **Quick win**: sebagian.

### [FUN-03][P1] Handle dan thread naik monoton saat idle
- **Area**: Performa / Stabilitas.
- **Bukti**: ukur PID 41828 (idle, tanpa interaksi UI): handle **2949 → 3598**, thread **219 → 276** dalam ±29 menit; ~1 handle/detik, 276 thread untuk aplikasi tray. GDI 160, USER 241.
- **Masalah**: sumber kebocoran belum terbukti — hipotesis: loop retry notifikasi (FUN-01) membuat objek WinRT/thread, ditambah thread per-request hook/HP dan dock; perlu verifikasi 1–2 jam dengan dump handle.
- **Dampak**: sesi seharian berpotensi menembus batas GDI 10.000/handle; startup lambat, crash saat banyak notifikasi.
- **Perbaikan**: catat `HandleCount`/thread ke log tiap 5 menit; batasi `new Thread` per request (`Agents.cs:168`, `Phone.cs:404`) dengan pool kecil; hentikan retry storm (FUN-01).
- **Usaha**: M. **Quick win**: tidak.

### [FUN-04][P1] Audio rapat dihapus sebelum transkrip dipastikan tersimpan
- **Area**: Transkrip rapat / Integritas data.
- **Bukti**: `StopRapat` memanggil `WriteRapat` lalu **selalu** `Directory.Delete(RapatTmp, true)` (`Rapat.cs:133-136`). `WriteRapat` mengembalikan `null` bila tidak ada baris transkrip (`Rapat.cs:203`) — misalnya key STT mati, kuota habis, atau internet putus dan model offline belum diunduh; pada chunk yang gagal, audio tetap dibuang (`Rapat.cs:180-203`). Notifikasi akhir hanya "transkrip gagal ditulis" (`Rapat.cs:145`).
- **Masalah**: Rekaman satu jam hilang tanpa jalan pulih; bertentangan dengan janji "rekaman audionya dihapus" (sesudah transkrip jadi).
- **Dampak**: Kehilangan data rapat/kuliah yang tidak bisa diulang — dampak terbesar dari seluruh temuan fungsi.
- **Perbaikan**: simpan audio ke `rapat\sementara` bila `path == null`, tawarkan "Coba transkripsi lagi / simpan audio"; hapus setelah sukses atau setelah pengguna memilih buang.
- **Usaha**: S. **Quick win**: ya.

### [FUN-05][P1] Unduhan model offline whisper.cpp tidak bisa lanjut setelah terputus
- **Area**: Dikte / Dependensi / Jaringan.
- **Bukti**: `Speech.Download` membuka `File.Create(part)` dari nol dan tidak memakai HTTP Range (`Speech.cs:190-232`); saat error, `.part` dihapus. Ukuran model: kecil 60 MB, seimbang 190 MB, akurat **574 MB** (`Speech.cs:116-121`).
- **Masalah**: Di jaringan kampus/hotel (kasus umum pengguna), unduhan 574 MB sering putus; setiap retry mulai dari 0 dan tidak ada tombol lanjutkan/pause. Ini juga menghabiskan kuota seluler.
- **Dampak**: Fitur dikte offline (pembeda utama, dan jalur pemulihan saat internet down) praktis tak tercapai bagi pengguna dengan koneksi buruk.
- **Perbaikan**: lanjutkan dari `.part` dengan header `Range`, retry otomatis 3× dengan backoff, tampilkan estimasi sisa; opsional unduh model "cepat" saja secara default.
- **Usaha**: S. **Quick win**: ya.

### [FUN-06][P2] Tidak ada cache di disk untuk tugas/jadwal; buka Tepi offline = agenda kosong
- **Area**: Integrasi / Offline.
- **Bukti**: state sumber hanya di memori (`Sources.cs:130-172`); tak ada berkas cache di `%APPDATA%\Tepi` (isi nyata: `lyrics/`, `rapat/`, `catatan/`, `settings.ini`, `statusline.json`, `tepi.log`, `tugas.tsv`); `SourceHub` dimuat kosong lalu `Queue` saat start.
- **Masalah**: sesi yang start sebelum login Wi-Fi kampus (atau setelah restart di kereta) menampilkan "tidak terjangkau · dicoba lagi otomatis" — data kemarin hilang dari layar.
- **Dampak**: mahasiswa kehilangan daftar tugas/jadwal tepat saat paling butuh (offline).
- **Perbaikan**: cache per sumber + timestamp "data 2 jam lalu" (pola `SourceHub.Status` sudah menyediakan umur data).
- **Usaha**: M. **Quick win**: tidak.

### [FUN-07][P2] AI tanpa retry; kegagalan dikte membuang rekaman di memori
- **Area**: AI / Dikte.
- **Bukti**: `Ai.Ask` sekali panggil, timeout 90 dtk (OpenAI) / 120 dtk (Anthropic), tanpa retry (`Ai.cs:229-250,274-308`); 429/5xx hanya jadi teks error. `FinishDictate` menyimpan `pcm` di memori; setelah transkripsi `rec.Dispose()` dan `raw` tak disimpan, bila `res.Ok==false` hanya `DictSay(error)` (`Dictate.cs:263-295`).
- **Masalah**: dikte panjang yang gagal karena timeout/rate limit harus diulang total; tidak ada retry untuk gangguan jaringan sebentar.
- **Dampak**: friksi besar pada fitur yang justru dipakai di jaringan pas-pasan.
- **Perbaikan**: retry 2× backoff untuk status 0/429/5xx; simpan WAV sementara + tombol "Coba lagi" (pola `SuruhChat` sudah punya).
- **Usaha**: S. **Quick win**: ya.

### [FUN-08][P2] 109 catch kosong — beberapa menelan kegagalan aksi yang terlihat pengguna
- **Area**: Feedback / Error handling.
- **Bukti**: hitung ulang: **448 blok catch, 109 kosong** (sesuai brief). Mayoritas cleanup wajar, tetapi ada yang menelan aksi pengguna: peluncuran app dari Dock gagal hanya `Log.Write` (`DockShell.cs:456-462`); model list AI gagal diparse hilang senyap (`Ai.cs:150-167`); OCR "Salin teks" saat clipboard sibuk `return` tanpa toast (`Shots.cs:241-245`); aksi tombol hanya log (`Island.cs:1508`).
- **Masalah**: pengguna menekan tombol, tidak terjadi apa-apa, tidak tahu kenapa — berulang, fitur tampak "random rusak".
- **Dampak**: kepercayaan turun; laporan bug tidak akurat.
- **Perbaikan**: audit 109 catch, sisakan kosong hanya untuk cleanup; aksi pengguna wajib `ShowInfo`/`DictSay` bermakna; helper `Log.UserFail(what)`.
- **Usaha**: S. **Quick win**: ya.

### [FUN-09][P2] Bridge HP mendengarkan di semua antarmuka jaringan
- **Area**: Privasi / HP.
- **Bukti**: `new TcpListener(IPAddress.Any, port)` (`Phone.cs:70-85`), padahal dokumen menjanjikan "hanya jaringan lokal". Kriptografi baik: PBKDF2-SHA256 60.000 putaran → AES-256-CBC + HMAC-SHA256, nonce + timestamp ±60 dtk, maks 5 salah kode (`Phone.cs:94-115,312-390,433-467`).
- **Masalah**: saat aktif di Wi-Fi publik/kantor, siapa pun yang menjangkau port bisa mencoba pairing (peluang kecil, 59-bit, 5 percobaan) dan mengamati lalu lintas; tanpa TLS, tanpa batas subnet/privat.
- **Dampak**: risiko rendah-menengah, tetapi bertentangan dengan klaim docs dan persona IT kantor/kafe.
- **Perbaikan**: tolak start bila profil jaringan Public; bind alamat privat; rate-limit per IP; tampilkan percobaan salah.
- **Usaha**: S. **Quick win**: ya.

### [FUN-10][P2] Update tanpa tanda tangan; digest dipercaya dari GitHub API
- **Area**: Update / Keamanan.
- **Bukti**: `Swap` memverifikasi SHA-256, HTTPS, `AssetPrefix` (`Update.cs:22-38,85-110`), tetapi `Signature.Signer(exe)` hanya memaksa tanda tangan **jika exe berjalan sudah bertanda tangan** — rilis sekarang unsigned, jadi dilewati (`Update.cs:114-120`); digest dari API GitHub yang sama.
- **Masalah**: integritas bergantung penuh pada keamanan repo/rilis GitHub; tak ada rantai kepercayaan lokal; tak ada changelog wajib sebelum install.
- **Dampak**: persona IT/office tetap melihat SmartScreen dan tak bisa membedakan build resmi; risiko supply-chain bila akun rilis disusupi.
- **Perbaikan**: mulai Authenticode (EV ideal), atau pin public key untuk minisign; tampilkan digest + changelog sebelum tombol Perbarui aktif.
- **Usaha**: M/L. **Quick win**: tidak.

## Celah fitur fungsional (bukti belum ada)

| ID | Celah | Bukti | Dampak |
|---|---|---|---|
| FUN-11 | Tidak bisa **membuat acara kalender** | `Source.Create` default "Tidak bisa dibuat dari Tepi" (`Sources.cs:177-180`); hanya Notion/Todoist override; `IcsFeed` tidak | Acara baru harus dibuat di web kalender |
| FUN-12 | Tidak ada **jadwal Senyap/DND otomatis** | Hanya setelan `dnd` + `dnd.follow` (`Prefs.cs:1350`); tak ada kode jadwal di `Reminders.cs`/`Control.cs` | DND manual tiap rapat/kuliah |
| FUN-13 | **Island hanya di satu monitor** | `monitor` satu device; `UpdateMonitor` satu `monitorHandle` (`Island.cs:356-395`); Dock ikut monitor itu | Monitor kedua tak pernah punya island |
| FUN-14 | **Tidak ada sinkron antar-laptop** | Hanya ekspor/impor manual whitelist preferensi (`SettingsIO.cs:14-34`); tak ada kode sinkron | Laptop kantor+rumah diatur ulang |
| FUN-15 | **Manajemen kuota AI** hanya tampilan | `Quota.cs` membaca & memperingatkan 80/95%; tak ada batas biaya/auto-pindah | Kuota/uang habis tanpa peringatan dini |
| FUN-16 | **Tidak ada plugin/extension API** | `Plugin.cs` (85 baris) hanya jembatan `--notify`/`--run`; tak ada pemuatan ekstensi | Ekosistem tak bisa tumbuh |
| FUN-17 | **Pencarian universal terbatas** | Dock Start: aplikasi + Pengaturan + `search-ms` (`DockStart.cs:353-390,589`); tak lintas pesan/tugas/catatan/transkrip | Tugas "laporan" dicari tab satu-satu |
| FUN-18 | **Tugas dan catatan lokal tak terdokumentasi** | `Work.cs`+`WorkWindow.cs` 47 KB; ada di `docs/pengaturan.md:35-38`, tak ada di `docs/fitur.md` | Fitur tak ditemukan pengguna baru |

## Temuan ringkas lanjutan

| ID | Sev | Temuan | Bukti | Usaha |
|---|---|---|---|---|
| FUN-19 | P3 | `agent.token` 48 karakter plaintext di `settings.ini`, ditulis juga ke config Claude/Codex | `Life.cs:450-462`, `HookSetup.cs:87-101`; bandingkan key AI DPAPI `Base.cs:477-507` | S |
| FUN-20 | P3 | Log memuat judul lagu+artis dan 300 karakter body error AI | `Lyrics.cs:145`, `Ai.cs:124-135`; rotasi 512 KB `Base.cs:36-41` | S |
| FUN-21 | P3 | Ekspor setelan kehilangan model AI kustom (`ai.<provider>.model` tak di whitelist) | `SettingsIO.cs:14-29` | S |
| FUN-22 | P3 | Kegagalan cuaca/lirik hanya log; kartu menampilkan data basi tanpa penanda | `Weather.cs:48-55`, `Lyrics.cs:163-168` | S |
| FUN-23 | P3 | Status sumber hanya di Pengaturan; panel Tugas cuma satu baris kaki | `Sources.cs:590-600,905-908,947-948` | S |
| FUN-24 | P3 | Bridge HP tanpa TLS; metadata (ukuran/berkas) terlihat | `Phone.cs:408-523` | M |
| FUN-25 | P3 | Sesi Kulia habis = email/OTP diisi ulang manual | `Kulia.cs:133-150` | S |
| FUN-26 | P3 | Hook `agent.quota` mengubah `settings.json` agent tanpa ringkasan perubahan | `HookSetup.cs:179-194`, `Quota.cs:1050-1130` | S |
| FUN-27 | P3 | Tak ada diagnostik dalam-app (unduh log/versi/cache) | `Prefs.cs:900` | S |

## Pertanyaan terbuka / perlu diverifikasi

1. **Penyebab timeout notifikasi** (FUN-01): build Windows 28120, antrean besar, atau listener tanpa izin? Uji mesin bersih + `GetAccessStatus`.
2. **Sumber kebocoran handle/thread** (FUN-03): perlu 1–2 jam sampling per tipe handle (ETW/`handle.exe`) agar bukan hanya warm-up dock/start.
3. **Apakah 151–175 MB terulang** dengan Dock aktif setelah 4–8 jam? Ukur private WS per jam.
4. **Update saat folder exe read-only**: kode membuka halaman rilis (`Update.cs:79-80`), belum diuji langsung.
5. **Fitur yang tak bisa diukur tanpa interaksi UI**: Suruh Tepi, Dikte, Word, rapat nyata, Dock — status berbasis kode/log, bukan uji fungsional; sesi >24 jam dan pairing HP di Wi-Fi publik juga belum.

## Lintas area

- `docs/fitur.md` tidak memuat "Tugas dan catatan" (`Work.cs`), sedangkan `docs/pengaturan.md` memuatnya — drift dokumen untuk tim 04. Also: proses berjalan memakai `agent.port=47725` dan `dockbar.capture=1` (bukan default), memengaruhi perbandingan performa.
