using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Xml;
using Windows.ApplicationModel;
using Windows.Storage.Streams;
using Windows.UI.Notifications;
using Windows.UI.Notifications.Management;

namespace Tepi
{
    class NotifItem
    {
        public uint Id;
        public string AppId = "", AppName = "", Title = "", Body = "";
        // Toast identifier inside its app; needed to drop it from Action Center
        public string Tag = "", Group = "";
        public DateTime Time;
        public bool Chat, Held;
        public Bitmap Logo;
    }

    // Notification centre; change key gates re-listing
    static class NotifSource
    {
        static readonly string[] ChatApps = { "whatsapp", "telegram", "teams", "discord", "slack", "signal", "messenger", "instagram",
                                              "yourphone", "phone link", "outlook", "windowscommunicationsapps", "thunderbird", "zoom", "line" };
        static readonly string[] Browsers = { "chrome", "msedge", "firefox", "brave", "opera", "vivaldi" };
        static readonly string[] ChatSites = { "whatsapp", "telegram", "discord", "slack", "messenger", "instagram", "mail.google", "outlook" };
        static readonly Dictionary<string, Bitmap> logos = new Dictionary<string, Bitmap>();
        public static readonly string Dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Windows\Notifications");

        // WinRT only serves a process with package identity; Tepi ships as a loose exe
        static bool? packaged;
        public static bool Packaged
        {
            get
            {
                if (packaged == null)
                {
                    try { var _ = Package.Current.Id.FamilyName; packaged = true; }
                    catch (Exception) { packaged = false; }
                }
                return packaged.Value;
            }
        }

        public static UserNotificationListenerAccessStatus Access()
        {
            // Unpackaged: the listener cannot be consulted at all, and the database
            // needs no permission, so there is nothing for the panel to report
            if (!Packaged) return UserNotificationListenerAccessStatus.Allowed;
            return UserNotificationListener.Current.GetAccessStatus();
        }

        public static void RequestAccess(Action done)
        {
            if (!Packaged) { if (done != null) done(); return; }
            var op = UserNotificationListener.Current.RequestAccessAsync();
            op.Completed = delegate { done(); };
        }

        // Packaged builds talk to the listener; loose builds read the database
        public static List<NotifItem> Read()
        {
            var list = Packaged ? ReadWinRt() : ReadDb();
            SkipClearing(list);
            // A cleared toast stays cleared even while the database still holds it
            return list.FindAll(n => !IsDismissed(n.Id, n.AppId, n.Tag));
        }

        public static List<NotifItem> ReadWinRt()
        {
            var list = new List<NotifItem>();
            foreach (var n in MediaService.Await(UserNotificationListener.Current.GetNotificationsAsync(NotificationKinds.Toast)))
            {
                var item = new NotifItem { Id = n.Id, Time = n.CreationTime.UtcDateTime };
                try
                {
                    item.AppId = n.AppInfo.AppUserModelId ?? "";
                    item.AppName = n.AppInfo.DisplayInfo.DisplayName ?? "";
                }
                catch (Exception) { }
                if (item.AppName.Length == 0) item.AppName = item.AppId;
                var texts = new List<string>();
                try
                {
                    var binding = n.Notification.Visual.GetBinding(KnownNotificationBindings.ToastGeneric);
                    if (binding != null)
                        foreach (var t in binding.GetTextElements())
                        {
                            string s = Fmt.OneLine(t.Text, 300);
                            if (s.Length > 0) texts.Add(s);
                        }
                }
                catch (Exception ex) { Log.Write("notif text: " + ex.Message); }
                if (texts.Count > 0) item.Title = texts[0];
                if (texts.Count > 1) item.Body = string.Join(" · ", texts.GetRange(1, texts.Count - 1));
                item.Chat = IsChat(item.AppId + " " + item.AppName, string.Join(" ", texts));
                item.Logo = LogoFor(item.AppId, n.AppInfo);
                list.Add(item);
            }
            list.Sort((a, b) => b.Time.CompareTo(a.Time));
            return list;
        }

        // Clearing works on Tepi's own list for any build: the listener can only drop
        // toasts for a packaged process, and this is the only path that always works
        public static bool CanRemove { get { return true; } }

        static readonly object dismissedGate = new object();
        static HashSet<string> dismissed;

        static string DismissFile { get { return Path.Combine(Settings.Dir, "notif-dismissed.txt"); } }

        // One line per cleared toast, so it stays gone after the DB still holds it
        static HashSet<string> Dismissed
        {
            get
            {
                lock (dismissedGate)
                {
                    if (dismissed != null) return dismissed;
                    dismissed = new HashSet<string>(StringComparer.Ordinal);
                    try
                    {
                        if (File.Exists(DismissFile))
                            foreach (var line in File.ReadAllLines(DismissFile))
                                if (line.Length > 0) dismissed.Add(line);
                    }
                    catch (Exception ex) { Log.Write("notif dismissed read: " + ex.Message); }
                    return dismissed;
                }
            }
        }

        public static string Sign(uint id, string appId, string tag) { return id + "\t" + appId + "\t" + tag; }

        public static bool IsDismissed(uint id, string appId, string tag)
        {
            lock (dismissedGate) return Dismissed.Contains(Sign(id, appId, tag));
        }

        public static void Dismiss(IEnumerable<NotifItem> items)
        {
            bool changed = false;
            lock (dismissedGate)
            {
                var set = Dismissed;
                foreach (var n in items) if (set.Add(Sign(n.Id, n.AppId, n.Tag))) changed = true;
                if (!changed) return;
                try
                {
                    // Ids are cheap and every one of them can come back, so keep them all
                    Directory.CreateDirectory(Settings.Dir);
                    var lines = new List<string>(set);
                    lines.Sort(StringComparer.Ordinal);
                    File.WriteAllLines(DismissFile, lines.ToArray());
                }
                catch (Exception ex) { Log.Write("notif dismissed write: " + ex.Message); }
            }
            // Action Center is best effort; the local list already dropped it
            ThreadPool.QueueUserWorkItem(delegate
            {
                foreach (var n in items) DropFromHistory(n);
            });
        }

        // Everything the database holds, not just what a page happens to show
        static readonly List<NotifItem> clearing = new List<NotifItem>();
        static bool clearingAll;

        public static void ClearAll()
        {
            if (clearingAll) return;
            clearingAll = true;
            ThreadPool.QueueUserWorkItem(delegate
            {
                var all = new List<NotifItem>();
                try
                {
                    // Unfiltered: this must reach past the page limit and the chat filter
                    all = ReadDb();
                    lock (clearing) { clearing.Clear(); clearing.AddRange(all); }
                    Dismiss(all);
                }
                catch (Exception ex) { Log.Write("notif clear all: " + ex.Message); }
                finally { clearingAll = false; }
            });
        }

        // Read() runs on the notif thread and drops what ClearAll just covered
        static void SkipClearing(List<NotifItem> list)
        {
            if (!clearingAll) return;
            lock (clearing)
            {
                if (clearing.Count == 0) return;
                var done = new HashSet<uint>();
                foreach (var n in clearing) done.Add(n.Id);
                list.RemoveAll(n => done.Contains(n.Id));
            }
        }

        // Packaged only: the listener refuses to touch toasts without package identity
        public static void Remove(uint id)
        {
            if (!Packaged) return;
            UserNotificationListener.Current.RemoveNotification(id);
        }

        // Same-package rule means this usually fails for other apps; never report it
        static void DropFromHistory(NotifItem n)
        {
            if (n.AppId.Length == 0) return;
            try
            {
                if (n.Tag.Length > 0)
                    ToastNotificationManager.History.Remove(n.Tag, n.Group.Length > 0 ? n.Group : "", n.AppId);
                else
                    ToastNotificationManager.History.Clear(n.AppId);
            }
            catch (Exception ex) { Log.Write("notif history drop: " + ex.GetType().Name); }
        }

        // Direct read of wpndatabase.db: no permission, no WinRT, no hang
        public static List<NotifItem> ReadDb()
        {
            var list = new List<NotifItem>();
            IntPtr h;
            if (sqlite3_open_v2(Encoding.UTF8.GetBytes(Path.Combine(Dir, "wpndatabase.db") + "\0"), out h, 2, IntPtr.Zero) != 0)
            {
                if (h != IntPtr.Zero) sqlite3_close(h);
                return list;
            }
            sqlite3_busy_timeout(h, 300);
            try
            {
                IntPtr stmt;
                // Handler row turns the toast's HandlerId into an app id
                const string sql = "select n.Id, n.Payload, n.ArrivalTime, coalesce(hh.PrimaryId, ''), n.Tag, n.[Group] from Notification n " +
                                   "left join NotificationHandler hh on hh.RecordId = n.HandlerId " +
                                   "where n.Type = 'toast' order by n.Id desc limit 60";
                if (sqlite3_prepare16_v2(h, sql, -1, out stmt, IntPtr.Zero) != 0) return list;
                try
                {
                    while (sqlite3_step(stmt) == 100)
                    {
                        var item = new NotifItem { Id = (uint)sqlite3_column_int64(stmt, 0) };
                        string payload = Column16(stmt, 1);
                        long arrival = sqlite3_column_int64(stmt, 2);
                        item.AppId = Column16(stmt, 3) ?? "";
                        // ArrivalTime is a FILETIME, so it is already UTC like the rest of Tepi
                        try { item.Time = DateTime.FromFileTimeUtc(arrival); }
                        catch (Exception) { item.Time = DateTime.UtcNow; }
                        ParseToast(payload, item);
                        if (item.Title.Length == 0 && item.Body.Length == 0) continue;
                        if (item.AppName.Length == 0) item.AppName = NiceAppId(item.AppId);
                        item.Tag = Column16(stmt, 4) ?? "";
                        item.Group = Column16(stmt, 5) ?? "";
                        item.Chat = IsChat(item.AppId + " " + item.AppName, item.Title + " " + item.Body);
                        item.Logo = LogoForId(item.AppId);
                        list.Add(item);
                    }
                }
                finally { sqlite3_finalize(stmt); }
            }
            finally { sqlite3_close(h); }
            list.Sort((a, b) => b.Time.CompareTo(a.Time));
            return list;
        }

        // Text straight from the toast XML; first line is the title
        static void ParseToast(string xml, NotifItem item)
        {
            if (string.IsNullOrEmpty(xml)) return;
            try
            {
                var doc = new XmlDocument { XmlResolver = null };
                doc.LoadXml(xml);
                var nodes = doc.GetElementsByTagName("text");
                var texts = new List<string>();
                for (int i = 0; i < nodes.Count && texts.Count < 6; i++)
                {
                    var n = nodes[i];
                    if (n == null) continue;
                    string s = Fmt.OneLine(n.InnerText, 300);
                    if (s.Length > 0) texts.Add(s);
                }
                if (texts.Count > 0) item.Title = texts[0];
                if (texts.Count > 1) item.Body = string.Join(" · ", texts.GetRange(1, texts.Count - 1));
            }
            catch (Exception ex) { Log.Write("notif payload: " + ex.Message); }
        }

        // com.squirrel.Discord.Discord -> Discord, Microsoft.ScreenSketch_x!App -> ScreenSketch
        static string NiceAppId(string id)
        {
            if (string.IsNullOrEmpty(id)) return "";
            int bang = id.IndexOf('!');
            string s = bang > 0 ? id.Substring(0, bang) : id;
            int us = s.IndexOf('_');
            if (us > 0) s = s.Substring(0, us);
            int dot = s.LastIndexOf('.');
            if (dot >= 0 && dot + 1 < s.Length) s = s.Substring(dot + 1);
            if (s.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) s = s.Substring(0, s.Length - 4);
            return s;
        }

        static string Column16(IntPtr stmt, int col)
        {
            IntPtr p = sqlite3_column_text16(stmt, col);
            int bytes = sqlite3_column_bytes16(stmt, col);
            if (p == IntPtr.Zero || bytes <= 0) return "";
            return Marshal.PtrToStringUni(p, bytes / 2) ?? "";
        }

        // Off: Windows drops it after ~6 s
        public static bool Kept(string appId)
        {
            try
            {
                using (var k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\" + appId))
                    return k == null || Convert.ToInt32(k.GetValue("ShowInActionCenter", 1)) != 0;
            }
            catch (Exception) { return true; }
        }

        // notif.apps, lowercased
        public static volatile string[] ExtraApps = new string[0];

        // Chat app by id alone; browsers carry more than chat
        public static bool ChatAppId(string appId)
        {
            string low = appId.ToLowerInvariant();
            foreach (var b in Browsers) if (low.Contains(b)) return false;
            return IsChat(appId, "");
        }

        static bool IsChat(string app, string text)
        {
            app = app.ToLowerInvariant();
            // Short names match whole words: "line" not "online"
            var words = app.Split(new[] { ' ', '.', '_', '!', '-', '\\', '/' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var c in ChatApps)
                if (c.Length <= 4 ? Array.IndexOf(words, c) >= 0 : app.Contains(c)) return true;
            foreach (var c in ExtraApps) if (app.Contains(c)) return true;
            bool browser = false;
            foreach (var b in Browsers) if (app.Contains(b)) browser = true;
            if (!browser) return false;
            text = text.ToLowerInvariant();
            foreach (var s in ChatSites) if (text.Contains(s)) return true;
            return false;
        }

        // App icon by app id alone: the shell knows both packaged and packed-in apps
        static Bitmap LogoForId(string appId)
        {
            if (string.IsNullOrEmpty(appId)) return null;
            lock (logos)
            {
                Bitmap cached;
                if (logos.TryGetValue(appId, out cached)) return cached;
            }
            Bitmap logo = null;
            try
            {
                // shell:AppsFolder resolves an AUMID; a plain path resolves a file
                string item = appId.IndexOf(':') >= 0 ? appId : ShellApp.AppsFolderOf(appId);
                logo = ShellApp.Icon(item, 48);
                if (logo == null) logo = ShellApp.Icon(appId, 48);
                if (logo != null) logo = Ink.Grayscale(logo, 48);
            }
            catch (Exception ex) { Log.Write("notif logo: " + ex.Message); logo = null; }
            lock (logos) logos[appId] = logo;
            return logo;
        }

        static Bitmap LogoFor(string appId, AppInfo info)
        {
            lock (logos)
            {
                Bitmap cached;
                if (logos.TryGetValue(appId, out cached)) return cached;
            }
            Bitmap logo = null;
            try
            {
                var reference = info.DisplayInfo.GetLogo(new Windows.Foundation.Size(64, 64));
                using (var stream = MediaService.Await(reference.OpenReadAsync()))
                {
                    ulong size = stream.Size;
                    if (size > 0 && size < 2 * 1024 * 1024)
                        using (var reader = new DataReader(stream.GetInputStreamAt(0)))
                        {
                            uint n = MediaService.Await(reader.LoadAsync((uint)size));
                            var bytes = new byte[n];
                            reader.ReadBytes(bytes);
                            using (var ms = new MemoryStream(bytes))
                            using (var src = Image.FromStream(ms))
                                logo = Ink.Grayscale(src, 48);
                        }
                }
            }
            catch (Exception) { logo = null; }
            lock (logos) logos[appId] = logo;
            return logo;
        }

        [DllImport("winsqlite3.dll")] static extern int sqlite3_open_v2(byte[] filename, out IntPtr db, int flags, IntPtr vfs);
        [DllImport("winsqlite3.dll")] static extern int sqlite3_close(IntPtr db);
        [DllImport("winsqlite3.dll")] static extern int sqlite3_busy_timeout(IntPtr db, int ms);
        [DllImport("winsqlite3.dll", CharSet = CharSet.Unicode)] static extern int sqlite3_prepare16_v2(IntPtr db, string sql, int bytes, out IntPtr stmt, IntPtr tail);
        [DllImport("winsqlite3.dll")] static extern int sqlite3_step(IntPtr stmt);
        [DllImport("winsqlite3.dll")] static extern long sqlite3_column_int64(IntPtr stmt, int col);
        [DllImport("winsqlite3.dll")] static extern IntPtr sqlite3_column_text16(IntPtr stmt, int col);
        [DllImport("winsqlite3.dll")] static extern int sqlite3_column_bytes16(IntPtr stmt, int col);
        [DllImport("winsqlite3.dll")] static extern int sqlite3_finalize(IntPtr stmt);
        static IntPtr db;

        // Changes on toast add/remove; null if unreadable
        public static string ChangeKey()
        {
            try
            {
                if (db == IntPtr.Zero)
                {
                    IntPtr h;
                    if (sqlite3_open_v2(Encoding.UTF8.GetBytes(Path.Combine(Dir, "wpndatabase.db") + "\0"), out h, 1, IntPtr.Zero) != 0)
                    {
                        if (h != IntPtr.Zero) sqlite3_close(h);
                        return null;
                    }
                    sqlite3_busy_timeout(h, 300);
                    db = h;
                }
                IntPtr stmt;
                if (sqlite3_prepare16_v2(db, "select count(*), coalesce(max(Id), 0) from Notification where Type = 'toast'", -1, out stmt, IntPtr.Zero) != 0)
                {
                    sqlite3_close(db);
                    db = IntPtr.Zero;
                    return null;
                }
                try
                {
                    if (sqlite3_step(stmt) != 100) return null;
                    return sqlite3_column_int64(stmt, 0) + ":" + sqlite3_column_int64(stmt, 1);
                }
                finally { sqlite3_finalize(stmt); }
            }
            catch (Exception ex) { Log.Write("notif key: " + ex.Message); return null; }
        }
    }

    // DB key polled each second (~8 µs)
    class NotifWatcher
    {
        public event Action<UserNotificationListenerAccessStatus, List<NotifItem>> Updated;
        // Fires once per failure streak, not once per retry
        public event Action<string> Failed;

        readonly AutoResetEvent wake = new AutoResetEvent(true);
        readonly object state = new object();
        FileSystemWatcher watcher;
        string lastKey;
        volatile bool force = true, enabled = true;
        int failures;
        string failure;
        DateTime retryUtc = DateTime.MinValue;

        // The panel shows an error state instead of "no messages"
        public bool Failing { get { lock (state) return failures > 0; } }
        public string Error { get { lock (state) return failure; } }

        public void Start()
        {
            try
            {
                if (NotifSource.Access() == UserNotificationListenerAccessStatus.Unspecified)
                    NotifSource.RequestAccess(delegate { Refresh(); });
            }
            catch (Exception ex) { Log.Write("notif access: " + ex.Message); }
            if (Directory.Exists(NotifSource.Dir))
            {
                try
                {
                    watcher = new FileSystemWatcher(NotifSource.Dir, "wpndatabase.db*") { NotifyFilter = NotifyFilters.LastWrite | NotifyFilters.Size };
                    FileSystemEventHandler h = delegate { wake.Set(); };
                    watcher.Changed += h;
                    watcher.Created += h;
                    watcher.EnableRaisingEvents = true;
                }
                catch (Exception ex) { Log.Write("notif watch: " + ex.Message); }
            }
            var t = new Thread(Prof.Wrap(Run)) { IsBackground = true, Name = "notif" };
            t.SetApartmentState(ApartmentState.MTA);
            t.Start();
        }

        public bool Enabled { set { enabled = value; if (value) Refresh(); } }

        // User tapped "Coba lagi": drop the backoff and try at once
        public void Refresh() { lock (state) retryUtc = DateTime.MinValue; force = true; wake.Set(); }

        void Run()
        {
            DateTime nextFull = DateTime.MinValue;
            while (true)
            {
                // The watcher is a hint, not a guarantee: rollups and settings writes
                // touch other files, so poll the database too. A read costs ~20 ms.
                int wait = enabled ? 1000 : 10000;
                DateTime retry;
                lock (state) retry = retryUtc;
                if (enabled && retry != DateTime.MinValue)
                {
                    // A failing read retries slower each time instead of every 20 s
                    double ms = (retry - DateTime.UtcNow).TotalMilliseconds;
                    wait = (int)Math.Max(250, Math.Min(wait, ms));
                }
                if (wake.WaitOne(wait)) Thread.Sleep(350);
                if (!enabled) continue;
                lock (state) retry = retryUtc;
                if (retry != DateTime.MinValue && DateTime.UtcNow < retry) continue;
                // A pending backoff means "try again even if the DB key looks unchanged"
                bool retryDue = retry != DateTime.MinValue;
                try
                {
                    string key = NotifSource.ChangeKey();
                    bool changed = key == null ? DateTime.UtcNow >= nextFull : key != lastKey;
                    if (!force && !changed && !retryDue) continue;
                    force = false;
                    var access = NotifSource.Access();
                    List<NotifItem> list = access == UserNotificationListenerAccessStatus.Allowed ? NotifSource.Read() : null;
                    // Listing rewrites the DB; keep prior key
                    lastKey = key;
                    nextFull = DateTime.UtcNow.AddSeconds(20);
                    bool wasFailing;
                    lock (state)
                    {
                        wasFailing = failures > 0;
                        failures = 0;
                        failure = null;
                        retryUtc = DateTime.MinValue;
                    }
                    if (wasFailing) Log.Write("notif read: recovered");
                    var h = Updated;
                    if (h != null) h(access, list);
                }
                catch (Exception ex)
                {
                    int n;
                    lock (state)
                    {
                        failures++;
                        n = failures;
                        failure = ex.Message;
                        // 10 s, 20 s, 40 s, 80 s, then 120 s
                        retryUtc = DateTime.UtcNow.AddSeconds(Math.Min(120, 10 << Math.Min(4, n - 1)));
                    }
                    Log.Write("notif read: " + ex.Message);
                    if (n == 1)
                    {
                        var f = Failed;
                        if (f != null) f(ex.Message);
                    }
                }
            }
        }
    }
}
