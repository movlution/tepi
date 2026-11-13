using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;

namespace Tepi
{
    // Overview: the user's cards, live ones first
    partial class Island
    {
        const float HomeCardH = 92, HomeMusicH = 76, HomeGap = 10;

        class Sender
        {
            public NotifItem Latest;
            public int Count;
        }

        enum HomeCard { Quota, Media, Agents, Timer, Class, Messages, Shelf, Weather, Battery, Clips, Pray, Combo, Priorities, Focus }

        // Enum order: settings ids, names, settings notes
        static readonly string[] HomeIds = { "quota", "media", "agents", "timer", "class", "messages", "shelf", "weather", "battery", "clips", "pray", "combo", "priorities", "focus" };
        static readonly string[] HomeNames = { "Kuota AI", "Musik", "Agen", "Timer", "Kuliah", "Pesan", "Rak", "Cuaca", "Baterai", "Clipboard", "Sholat", "Combo Ketikan", "3 Prioritas Hari Ini", "Fokus & Progres" };
        static readonly string[] HomeNotes =
        {
            "Saat pemakaian 70% ke atas", "Saat musik diputar", "Sesi agen dan izin yang menunggu", "Saat timer berjalan", "Kelas dan tenggat terdekat",
            "Pesan yang belum dibuka", "Berkas di Rak", "Suhu dan peringatan hujan", "Laptop dan perangkat Bluetooth", "Teks terakhir yang disalin", "Waktu sholat berikutnya",
            "Statistik ketikan, level XP, dan Sprint 30 detik", "Checklist 3 target utama hari ini di Ringkasan", "Menit fokus, streak harian, dan grafik 7 hari"
        };
        static readonly char[] HomeGlyphs = { '', '', '', '', '', '', '', '', '', '', '', '\uE7FC', '\uE73A', '\uE916' };
        const string DefaultHome = "quota,media,agents,timer,class,messages,shelf,priorities,focus,combo";

        HomeCard[] homeCards = new HomeCard[0];
        readonly Spring homeScroll = new Spring(0, 300, 34, 0.2f);
        readonly List<HomeCard> homeShown = new List<HomeCard>();
        readonly List<KeyValuePair<HomeCard, RectangleF>> homeSlots = new List<KeyValuePair<HomeCard, RectangleF>>();
        float homeContentH;
        // Visible list area; hits stay inside
        RectangleF homeClip;
        Action[] homeMenus;
        static readonly Action noAct = delegate { };

        bool HomeHasMedia { get { return mediaInfo.Present && mediaInfo.Title.Length > 0; } }

        // Auto: running things rise; list: as ordered
        bool HomeAuto { get { return settings.Get("home.sort", "auto") != "list"; } }

        void LoadHome()
        {
            var list = new List<HomeCard>();
            foreach (var part in settings.Get("home.cards", DefaultHome).Split(','))
            {
                int v = Array.IndexOf(HomeIds, part.Trim());
                if (v >= 0 && !list.Contains((HomeCard)v)) list.Add((HomeCard)v);
            }
            homeCards = list.ToArray();
        }

        void SetHomeCards(List<HomeCard> cards)
        {
            var ids = new List<string>();
            foreach (var c in cards) ids.Add(HomeIds[(int)c]);
            settings.Set("home.cards", string.Join(",", ids.ToArray()));
            settings.Save();
            LoadHome();
            Kick();
        }

        void HideHomeCard(HomeCard c)
        {
            var list = new List<HomeCard>(homeCards);
            list.Remove(c);
            SetHomeCards(list);
            if (prefs != null && !prefs.IsDisposed) prefs.Relayout();
        }

        // Warm JIT and fonts offscreen
        void WarmUp()
        {
            if (g == null || current == View.Panel) return;
            var keepG = g;
            int keepPage = page;
            bool keepHits = hitsOn;
            var keepT = p.T;
            var now = DateTime.UtcNow;
            try
            {
                using (var bmp = new Bitmap(canvasW, canvasH, System.Drawing.Imaging.PixelFormat.Format32bppPArgb))
                using (var wg = Graphics.FromImage(bmp))
                {
                    wg.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                    wg.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
                    wg.ScaleTransform(scale, scale);
                    g = wg;
                    p.G = wg;
                    hitsOn = false;
                    p.T = Ink.Base;
                    for (int pg = 0; pg < PageNames.Length; pg++)
                    {
                        page = pg;
                        DrawPage(pg, PanelW, 340, now);
                    }
                    DrawAlbumLayout(PanelW, 340, now, 0);
                    DrawLyricsLayout(PanelW, 340, now, 0);
                    // Warm every font size used
                    const string sample = "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789 .,:;·…%+-'\"!?()";
                    foreach (var px in new[] { 12f, 12.5f, 13f, 13.5f, 14f, 14.5f, 15f, 15.5f, 17f, 18f, 20f, 22f, 26f, 34f }) p.Text(sample, Ink.Display(px), p.T.Text, 0, 20);
                    foreach (var px in new[] { 10.5f, 11f, 11.5f, 12f, 12.5f, 13f, 13.5f, 14f, 14.5f, 15f }) p.Text(sample, Ink.Semi(px), p.T.Text, 0, 20);
                    foreach (var px in new[] { 9.5f, 10.5f, 11f, 11.5f, 12f }) p.Text(sample, Ink.Small(px), p.T.Text, 0, 20);
                    foreach (var px in new[] { 11.5f, 12f, 12.5f, 13f, 13.5f, 14f, 15f }) p.Text(sample, Ink.Text(px), p.T.Text, 0, 20);
                    foreach (var px in new[] { 11.5f, 12f }) p.Text(sample, Ink.Mono(px), p.T.Text, 0, 20);
                    char[] glyphs = { Ink.IcoVol0, Ink.IcoVol1, Ink.IcoVol2, Ink.IcoVol3, Ink.IcoMute, Ink.IcoBolt, Ink.IcoWifi, Ink.IcoGlobe, Ink.IcoCam, Ink.IcoMic,
                                      Ink.IcoTerminal, Ink.IcoCalendar, Ink.IcoRefresh, Ink.IcoLock, Ink.IcoBell, IcoMicOff, '', '', '', '', '' };
                    foreach (var px in new[] { 10f, 12f, 13f, 14f, 15f, 16f, 20f })
                        foreach (var c in glyphs) p.Icon(c, px, p.T.Text, 20, 20);
                }
                SliceShadow(30, 1f);
            }
            catch (Exception ex) { Log.Write("warmup: " + ex.Message); }
            finally
            {
                g = keepG;
                p.G = keepG;
                page = keepPage;
                hitsOn = keepHits;
                p.T = keepT;
                tabSnap = true;
            }
        }

        // Messages grouped by sender, newest first
        List<Sender> Senders()
        {
            var list = new List<Sender>();
            var index = new Dictionary<string, Sender>();
            foreach (var n in notifs)
            {
                string key = n.AppId + "|" + (n.Title.Length > 0 ? n.Title : n.AppName);
                Sender s;
                if (!index.TryGetValue(key, out s))
                {
                    s = new Sender { Latest = n };
                    index[key] = s;
                    list.Add(s);
                }
                s.Count++;
            }
            return list;
        }

        // Something to show, or a setup step the user asked for
        bool HomeHas(HomeCard c)
        {
            switch (c)
            {
                case HomeCard.Quota: return QuotaCount(true) > 0;
                case HomeCard.Media: return HomeHasMedia;
                case HomeCard.Agents: return approvals.Count > 0 || sessions.Count > 0;
                case HomeCard.Timer: return TimerOn;
                case HomeCard.Class: return ClassCardOn();
                case HomeCard.Messages: return notifs.Count > 0 && NotifOn;
                case HomeCard.Shelf: return shelf.Count > 0;
                case HomeCard.Battery: return hasBattery || btBattery.Count > 0;
                case HomeCard.Clips: return !ClipsOn || clips.Count > 0;
                case HomeCard.Combo: return ComboOn || ComboXp > 0 || ComboAllTimeBest > 0 || TypingSprintActive;
                case HomeCard.Priorities: return PriorityCount > 0;
                case HomeCard.Focus: return FocusTotalMin > 0 || FocusMinToday > 0 || FocusStreakDays > 0 || TimerOn || PriorityCount > 0 || ComboOn;
            }
            return true;
        }

        // 0 pinned, 1 running now, 2 the rest, 3 quiet leftovers
        int HomeRank(HomeCard c)
        {
            switch (c)
            {
                case HomeCard.Quota:
                case HomeCard.Media: return 0;
                case HomeCard.Agents: return approvals.Count > 0 || BusyCount() > 0 ? 1 : 3;
                case HomeCard.Timer: return 1;
                case HomeCard.Combo: return TypingSprintActive ? 1 : 2;
                case HomeCard.Priorities: return PriorityCount > 0 && !PrioritiesAllDone ? 1 : 2;
                case HomeCard.Focus: return TimerOn ? 1 : 2;
            }
            return 2;
        }

        bool ClassCardOn()
        {
            var next = NextClass();
            return (next != null && (next.Start - DateTime.Now).TotalHours < 24) || (tasks != null && tasks.Count > 0);
        }

        static bool WideCard(HomeCard c) { return c == HomeCard.Quota || c == HomeCard.Media || c == HomeCard.Priorities; }

        float CardHeight(HomeCard c)
        {
            if (c == HomeCard.Quota) return QuotaGlanceH() - HomeGap;
            if (c == HomeCard.Priorities) return 114f;
            return c == HomeCard.Media ? HomeMusicH : HomeCardH;
        }

        // Wide cards fill a row; halves pair up, a lone one widens
        void HomeLayout(float full)
        {
            homeShown.Clear();
            foreach (var c in homeCards) if (HomeHas(c)) homeShown.Add(c);
            // Stable by rank: insertion keeps user order
            if (HomeAuto)
                for (int i = 1; i < homeShown.Count; i++)
                {
                    var c = homeShown[i];
                    int rank = HomeRank(c), j = i - 1;
                    while (j >= 0 && HomeRank(homeShown[j]) > rank) { homeShown[j + 1] = homeShown[j]; j--; }
                    homeShown[j + 1] = c;
                }
            homeSlots.Clear();
            // Wide panels fit three to a row
            int cols = full >= 540 ? 3 : 2, open = -1;
            float y = 0;
            foreach (var c in homeShown)
            {
                if (!WideCard(c))
                {
                    if (open < 0) open = homeSlots.Count;
                    homeSlots.Add(new KeyValuePair<HomeCard, RectangleF>(c, new RectangleF(0, y, 0, HomeCardH)));
                    if (homeSlots.Count - open == cols) { CloseRow(open, full); open = -1; y += HomeCardH + HomeGap; }
                    continue;
                }
                if (open >= 0) { CloseRow(open, full); open = -1; y += HomeCardH + HomeGap; }
                float h = CardHeight(c);
                homeSlots.Add(new KeyValuePair<HomeCard, RectangleF>(c, new RectangleF(0, y, full, h)));
                y += h + HomeGap;
            }
            if (open >= 0) { CloseRow(open, full); y += HomeCardH + HomeGap; }
            homeContentH = Math.Max(0, y - HomeGap);
        }

        // Cards in a row share its width
        void CloseRow(int from, float full)
        {
            int n = homeSlots.Count - from;
            float w = (full - (n - 1) * HomeGap) / n;
            for (int i = 0; i < n; i++)
            {
                var s = homeSlots[from + i];
                homeSlots[from + i] = new KeyValuePair<HomeCard, RectangleF>(s.Key, new RectangleF(i * (w + HomeGap), s.Value.Y, w, s.Value.Height));
            }
        }

        // Only the quota line: the resting scene below it
        bool HomeQuiet { get { return homeSlots.Count == 0 || (homeSlots.Count == 1 && homeSlots[0].Key == HomeCard.Quota); } }

        float HomeHeroH { get { return EyesOn ? 194 : 162; } }

        float HomeHeight()
        {
            HomeLayout(PanelW - 28);
            if (HomeQuiet) return PanelTop + HomeHeroH + (homeSlots.Count > 0 ? homeContentH + HomeGap : 0);
            return Math.Min(MaxH, PanelTop + 4 + homeContentH + 14);
        }

        float HomeView() { return PanelHeight() - PanelTop - 18; }

        void DrawHome(float w, float h, DateTime now)
        {
            float x0 = 14, full = w - 28, top = PanelTop + 4;
            HomeLayout(full);
            if (HomeQuiet)
            {
                float shift = 0;
                if (homeSlots.Count > 0)
                {
                    var q = homeSlots[0].Value;
                    DrawQuotaGlance(x0, top + q.Y, full);
                    shift = homeContentH + HomeGap;
                }
                DrawHomeHero(w, PanelTop + shift, now);
                return;
            }
            float max = Math.Max(0, homeContentH - (h - PanelTop - 18));
            if (homeScroll.Target > max) homeScroll.Target = max;
            homeClip = new RectangleF(0, PanelTop - 2, w, h - PanelTop - 4);
            var st = g.Save();
            g.IntersectClip(homeClip);
            float off = top - homeScroll.Value;
            for (int i = 0; i < homeSlots.Count; i++)
            {
                var r = homeSlots[i].Value;
                r.Offset(x0, off);
                if (r.Bottom < homeClip.Top || r.Top > homeClip.Bottom) continue;
                float dy, a = RowIn(i, now, out dy), keep = p.Alpha;
                p.Alpha = keep * a;
                r.Offset(0, dy);
                if (homeSlots[i].Key == HomeCard.Quota) DrawQuotaGlance(r.X, r.Y, r.Width);
                else DrawHomeCard(homeSlots[i].Key, r, now);
                p.Alpha = keep;
            }
            g.Restore(st);
            homeClip = RectangleF.Empty;
        }

        // Nothing going on: the eyes, the time, today
        void DrawHomeHero(float w, float top, DateTime now)
        {
            var local = DateTime.Now;
            float cy = top + 52;
            if (EyesOn)
            {
                DrawEyes(w / 2, top + 30, 1.9f);
                cy += 32;
            }
            p.TextCenter(Fmt.Clock(local), Ink.Display(34f), p.T.Text, w / 2, cy);
            string wl = WeatherLine(), day = local.ToString("dddd, d MMMM", Fmt.Id);
            p.TextCenter(wl == null ? day : day + "  ·  " + wl, Ink.Text(13f), p.T.Sub, w / 2, cy + 34);
            p.TextCenter(Lang.T("Tidak ada yang menunggu"), Ink.Small(11.5f), p.T.Faint, w / 2, cy + 56);
            if (Array.IndexOf(homeCards, HomeCard.Priorities) >= 0)
            {
                string label = "+ " + Lang.T("3 Prioritas Hari Ini");
                var bf = Ink.Small(11f);
                float bw = p.Measure(label, bf) + 22f;
                float bh = 22f;
                var btn = new RectangleF(w / 2f - bw / 2f, cy + 78f - bh / 2f, bw, bh);
                AddHit(btn, "heroPrioAdd", delegate { BeginInvoke(new Action(PromptAddPriority)); });
                p.FillRound(btn, bh / 2f, Ink.A(p.T.Text, Hover("heroPrioAdd") ? 0.12f : 0.06f));
                p.TextCenter(label, bf, p.T.Sub, w / 2f, cy + 78f);
            }
        }

        // Right click: hide it, or tune the list
        Action HomeMenuAct(HomeCard c)
        {
            if (homeMenus == null) homeMenus = new Action[HomeIds.Length];
            int i = (int)c;
            if (homeMenus[i] == null) homeMenus[i] = delegate { HomeMenu(c); };
            return homeMenus[i];
        }

        void HomeMenu(HomeCard c)
        {
            var m = new ContextMenuStrip();
            m.Items.Add(new ToolStripMenuItem(Lang.T(HomeNames[(int)c])) { Enabled = false });
            m.Items.Add(new ToolStripSeparator());
            m.Items.Add(Lang.T("Sembunyikan dari Ringkasan"), null, delegate { HideHomeCard(c); });
            m.Items.Add(Lang.T("Atur Ringkasan…"), null, delegate { BeginInvoke(new Action(delegate { OpenPrefs("home"); })); });
            StyleMenu(m);
            m.Closed += delegate { BeginInvoke(new Action(m.Dispose)); };
            m.Show(Control.MousePosition);
        }

        // Card shell: hover lifts, press sinks; null act means look only
        void CardBase(RectangleF r, string id, HomeCard card, Action act)
        {
            var hit = homeClip.IsEmpty ? r : RectangleF.Intersect(r, homeClip);
            if (hit.Height > 6) AddHit(hit, id, act ?? noAct, null, HomeMenuAct(card));
            bool live = act != null, down = live && Pressed(id);
            if (down) r.Inflate(-1.5f, -1.5f);
            p.FillRound(r, 20, down ? p.T.FillHover : live && Hover(id) ? Ink.Mix(p.T.Fill, p.T.FillHover, 0.6f) : p.T.Fill);
        }

        void DrawHomeMusic(RectangleF r, DateTime now)
        {
            CardBase(r, "homeMusic", HomeCard.Media, delegate { SetPage(PageMusic, false); });
            DrawCover(new RectangleF(r.X + 12, r.Y + 12, 52, 52), 12);
            float tx = r.X + 76, right = r.Right - 128;
            p.Text(mediaInfo.Title, Ink.Semi(14f), p.T.Text, tx, r.Y + 28, right - tx, StringAlignment.Near);
            p.Text(mediaInfo.Artist.Length > 0 ? mediaInfo.Artist : mediaInfo.App, Ink.Text(12f), p.T.Sub, tx, r.Y + 48, right - tx, StringAlignment.Near);
            // Transport on the right
            float cy = r.Y + 38, bx = r.Right - 112;
            var prev = new RectangleF(bx, cy - 15, 30, 30);
            var play = new RectangleF(bx + 36, cy - 18, 36, 36);
            var next = new RectangleF(bx + 78, cy - 15, 30, 30);
            DrawControl(prev, "homePrev", delegate { media.Previous(); }, (b, c) => p.Skip(b.X + b.Width / 2, b.Y + b.Height / 2, 11, c, false));
            AddHit(play, "homePlay", delegate { media.TogglePlay(); });
            bool down = Pressed("homePlay");
            p.Circle(play.X + 18, play.Y + 18, down ? 15.5f : Hover("homePlay") ? 18 : 17, p.T.Text);
            if (mediaInfo.Playing) p.Pause(play.X + 18, play.Y + 18, 11.5f, p.T.Bg);
            else p.Play(play.X + 18, play.Y + 18, 12, p.T.Bg);
            DrawControl(next, "homeNext", delegate { media.Next(); }, (b, c) => p.Skip(b.X + b.Width / 2, b.Y + b.Height / 2, 11, c, true));
            // Thin progress along the bottom
            if (mediaInfo.DurationMs > 0)
            {
                var track = new RectangleF(tx, r.Bottom - 12, r.Right - 16 - tx, 3);
                LiveRect(track, ProgressFps(track.Width), t =>
                {
                    float f = Ease.Clamp01((float)(mediaInfo.Position(t) / mediaInfo.DurationMs));
                    p.FillRound(track, 1.5f, p.T.Line);
                    p.FillRound(new RectangleF(track.X, track.Y, Math.Max(3, track.Width * f), 3), 1.5f, p.T.Progress);
                });
            }
        }

        void DrawHomeCard(HomeCard kind, RectangleF r, DateTime now)
        {
            switch (kind)
            {
                case HomeCard.Media: DrawHomeMusic(r, now); break;
                case HomeCard.Agents: DrawAgentsCard(r, now); break;
                case HomeCard.Class: DrawClassCard(r); break;
                case HomeCard.Messages: DrawMessagesCard(r); break;
                case HomeCard.Timer: DrawTimerCard(r, now); break;
                case HomeCard.Shelf: DrawShelfCard(r); break;
                case HomeCard.Weather: DrawWeatherCard(r); break;
                case HomeCard.Battery: DrawBatteryCard(r); break;
                case HomeCard.Clips: DrawClipsCard(r); break;
                case HomeCard.Pray: DrawHomePray(r); break;
                case HomeCard.Combo: DrawComboCard(r); break;
                case HomeCard.Priorities: DrawPrioritiesCard(r); break;
                case HomeCard.Focus: DrawFocusCard(r); break;
            }
        }

        // Small caption at the card's top
        void CardCaption(RectangleF r, char glyph, string caption)
        {
            p.Icon(glyph, 12f, p.T.Sub, r.X + 22, r.Y + 22);
            p.Text(caption, Ink.Semi(11.5f), p.T.Sub, r.X + 34, r.Y + 22, r.Width - 48, StringAlignment.Near);
        }

        // Feature off: what to do, one line each
        void CardSetup(RectangleF r, string title, string detail)
        {
            p.Text(title, Ink.Semi(14f), p.T.Text, r.X + 16, r.Y + 50, r.Width - 30, StringAlignment.Near);
            p.Text(detail, Ink.Small(11.5f), p.T.Sub, r.X + 16, r.Y + 72, r.Width - 30, StringAlignment.Near);
        }

        void DrawAgentsCard(RectangleF r, DateTime now)
        {
            CardBase(r, "homeAgents", HomeCard.Agents, delegate { SetPage(PageAgents, false); });
            var s = BusySession();
            if (s == null) { var list = SortedSessions(); s = list.Count > 0 ? list[0] : null; }
            int busy = BusyCount();
            CardCaption(r, Ink.IcoTerminal, approvals.Count > 0 ? Lang.T("Menunggu izin") : busy > 1 ? Lang.F("{0} agen bekerja", busy) : Lang.T("Agen"));
            if (s == null) return;
            DrawStateMark(s, r.X + 26, r.Y + 56);
            float tx = r.X + 46;
            p.Text(s.Project, Ink.Semi(13.5f), p.T.Text, tx, r.Y + 47, r.Right - tx - 14, StringAlignment.Near);
            string line = s.State == AgentState.Done && s.LastMessage.Length > 0 ? s.LastMessage : AgentLine(s);
            p.Text(line, Ink.Small(11.5f), p.T.Sub, tx, r.Y + 66, r.Right - tx - 14, StringAlignment.Near);
            DrawPlanBar(s, new RectangleF(tx, r.Bottom - 12, r.Right - tx - 14, 3));
        }

        void DrawClassCard(RectangleF r)
        {
            var next = NextClass();
            var task = tasks != null && tasks.Count > 0 ? tasks[0] : null;
            var now = DateTime.Now;
            bool classFirst = next != null && (task == null || ((next.Start - now).TotalHours < 12 && next.Start.ToUniversalTime() < task.DeadlineUtc));
            if (classFirst)
            {
                CardBase(r, "homeClass", HomeCard.Class, delegate { ShowSchedule(); });
                bool running = now >= next.Start;
                bool kuliaClass = next.Source == "kulia";
                CardCaption(r, Ink.IcoCalendar, running ? (kuliaClass ? Lang.T("Kelas berjalan") : Lang.T("Acara berjalan")) : kuliaClass ? Lang.T("Kelas berikutnya") : Lang.T("Acara berikutnya"));
                string big = running ? Lang.F("sampai {0}", Fmt.Hm(next.End)) : Fmt.Left(next.Start - now);
                // Starting within the hour: the accent
                bool soon = !running && (next.Start - now).TotalMinutes <= 60;
                p.Text(big, Ink.Display(20f), soon ? p.T.Accent : p.T.Text, r.X + 16, r.Y + 50, r.Width - 30, StringAlignment.Near);
                p.Text(next.Title + (next.Room.Length > 0 ? " · " + next.Room : ""), Ink.Small(11.5f), p.T.Sub, r.X + 16, r.Y + 72, r.Width - 30, StringAlignment.Near);
                return;
            }
            CardBase(r, "homeTask", HomeCard.Class, delegate { ShowTasks(); });
            CardCaption(r, '', task.Kind == "ujian" ? Lang.T("Ujian terdekat") : Lang.T("Tenggat terdekat"));
            bool urgent = (task.DeadlineUtc - DateTime.UtcNow).TotalHours < 24;
            p.Text(Relative(task, DateTime.UtcNow), Ink.Display(20f), urgent ? p.T.Accent : p.T.Text, r.X + 16, r.Y + 50, r.Width - 30, StringAlignment.Near);
            p.Text(task.Title, Ink.Small(11.5f), p.T.Sub, r.X + 16, r.Y + 72, r.Width - 30, StringAlignment.Near);
        }

        // Latest sender up front; the rest as a count
        void DrawMessagesCard(RectangleF r)
        {
            CardBase(r, "homeMsgs", HomeCard.Messages, delegate { SetPage(PageMessages, false); });
            var senders = Senders();
            CardCaption(r, Ink.IcoBell, Lang.F("{0} pesan", notifs.Count));
            if (senders.Count == 0) return;
            var latest = senders[0].Latest;
            var badge = new RectangleF(r.X + 14, r.Y + 38, 26, 26);
            DrawAppBadge(latest, badge);
            float tx = badge.Right + 10, right = r.Right - 14, cy = r.Y + 51;
            if (senders.Count > 1)
            {
                string more = Lang.F("+{0} lainnya", senders.Count - 1);
                var mf = Ink.Small(11f);
                p.TextRight(more, mf, p.T.Sub, right, cy);
                right -= p.Measure(more, mf) + 8;
            }
            p.Text(NotifTitle(latest), Ink.Semi(12.5f), p.T.Text, tx, cy, right - tx, StringAlignment.Near);
            p.Text(NotifBody(latest), Ink.Small(11.5f), p.T.Sub, r.X + 16, r.Y + 75, r.Width - 30, StringAlignment.Near);
        }

        void DrawTimerCard(RectangleF r, DateTime now)
        {
            CardBase(r, "homeTimer", HomeCard.Timer, delegate { SetPage(PageControl, false); });
            string timerCap = !string.IsNullOrEmpty(FocusTaskTitle) && (timerKind == TimerKind.Focus || timerKind == TimerKind.Break)
                ? TimerLabel() + " · " + FocusTaskTitle
                : TimerLabel();
            CardCaption(r, '', timerPaused ? timerCap + Lang.T(" · dijeda") : timerCap);
            LiveRect(new RectangleF(r.X + 15, r.Y + 47, 26, 26), timerPaused ? 0 : TickFps, t => DrawTimerRing(r.X + 28, r.Y + 60, 11f));
            LiveTimer(Ink.Display(22f), timerPaused ? p.T.Sub : p.T.Text, r.X + 48, r.Y + 60, StringAlignment.Near, r.Right - r.X - 58);
        }

        void DrawShelfCard(RectangleF r)
        {
            CardBase(r, "homeShelf", HomeCard.Shelf, delegate { shelfSeg = 0; shelfSegX.Snap(0); SetPage(PageShelf, false); });
            CardCaption(r, '', Lang.F("{0} berkas di rak", shelf.Count));
            int show = Math.Min(Math.Max(1, (int)((r.Width - 24) / 40)), shelf.Count);
            for (int i = 0; i < show; i++) DrawShelfThumb(shelf[i], new RectangleF(r.X + 14 + i * 40, r.Y + 40, 34, 34), 9);
        }

        // Temperature big, rain below
        void DrawWeatherCard(RectangleF r)
        {
            if (!WeatherOn)
            {
                CardBase(r, "homeWeather", HomeCard.Weather, delegate { BeginInvoke(new Action(delegate { OpenPrefs("system"); })); });
                CardCaption(r, '', Lang.T("Cuaca"));
                CardSetup(r, Lang.T("Pilih kota"), Lang.T("Untuk cuaca dan peringatan hujan"));
                return;
            }
            CardBase(r, "homeWeather", HomeCard.Weather, null);
            var city = PrayCity();
            CardCaption(r, '', city != null ? (string)city[0] : Lang.T("Cuaca"));
            var w = weather;
            if (w == null || (DateTime.UtcNow - w.Utc).TotalHours > 3)
            {
                p.Orbit(r.X + 23, r.Y + 58, 6.5f, orbitPhase, p.T.Sub);
                p.Text(Lang.T("Memuat cuaca…"), Ink.Text(12.5f), p.T.Sub, r.X + 38, r.Y + 58, r.Width - 52, StringAlignment.Near);
                return;
            }
            string temp = w.Temp + "°";
            var big = Ink.Display(26f);
            p.Text(temp, big, p.T.Text, r.X + 16, r.Y + 53, r.Width - 30, StringAlignment.Near);
            float tw = p.Measure(temp, big);
            p.Text(WeatherWord(w.Code), Ink.Semi(12.5f), p.T.Sub, r.X + 22 + tw, r.Y + 55, r.Width - tw - 36, StringAlignment.Near);
            string rain = w.Raining ? Lang.T("Sedang hujan") : w.RainIn < 0 ? Lang.T("Belum ada tanda hujan")
                        : w.RainIn < 15 ? Lang.T("Sebentar lagi hujan") : Lang.F("Hujan sekitar {0} menit lagi", (w.RainIn + 7) / 15 * 15);
            p.Text(rain, Ink.Small(11.5f), w.Raining || w.RainIn >= 0 ? p.T.Accent : p.T.Sub, r.X + 16, r.Y + 76, r.Width - 30, StringAlignment.Near);
        }

        // Laptop first, Bluetooth devices after
        void DrawBatteryCard(RectangleF r)
        {
            CardBase(r, "homeBattery", HomeCard.Battery, null);
            CardCaption(r, onAc && hasBattery ? Ink.IcoPlug : '', Lang.T("Baterai"));
            var tail = new System.Text.StringBuilder();
            int shownBt = 0;
            string lead = null;
            int leadPct = -1;
            foreach (var kv in btBattery)
            {
                if (!hasBattery && lead == null) { lead = kv.Key; leadPct = kv.Value; continue; }
                if (shownBt == 2) break;
                if (tail.Length > 0) tail.Append("  ·  ");
                tail.Append(kv.Key).Append(' ').Append(Ink.Percent(kv.Value));
                shownBt++;
            }
            int pct = hasBattery ? battery : leadPct;
            if (pct < 0) return;
            string big = Ink.Percent(pct);
            var bf = Ink.Display(22f);
            p.Text(big, bf, p.T.Text, r.X + 16, r.Y + 52, r.Width - 30, StringAlignment.Near);
            string state = hasBattery ? (onAc ? (pct >= 100 ? Lang.T("penuh") : Lang.T("mengisi daya")) : BatteryLeftText()) : lead;
            float bw = p.Measure(big, bf);
            if (!string.IsNullOrEmpty(state)) p.Text(state, Ink.Small(11.5f), p.T.Sub, r.X + 24 + bw, r.Y + 54, r.Width - bw - 38, StringAlignment.Near);
            if (tail.Length > 0) p.Text(tail.ToString(), Ink.Small(11f), p.T.Sub, r.X + 16, r.Y + 73, r.Width - 30, StringAlignment.Near);
            // Level along the bottom; low and unplugged turns red
            var bar = new RectangleF(r.X + 16, r.Bottom - 11, r.Width - 32, 3);
            p.FillRound(bar, 1.5f, p.T.Line);
            bool low = hasBattery && !onAc && pct <= 20;
            p.FillRound(new RectangleF(bar.X, bar.Y, Math.Max(3, bar.Width * pct / 100f), 3), 1.5f, low ? p.T.Negative : p.T.Progress);
        }

        // Windows' own estimate, when it has one
        string BatteryLeftText()
        {
            Native.SYSTEM_POWER_STATUS ps;
            if (!Native.GetSystemPowerStatus(out ps) || ps.BatteryLifeTime <= 0) return "";
            return Lang.F("sisa {0}", Fmt.Left(TimeSpan.FromSeconds(ps.BatteryLifeTime)));
        }

        void DrawClipsCard(RectangleF r)
        {
            if (!ClipsOn)
            {
                CardBase(r, "homeClips", HomeCard.Clips, delegate { SetFlag("clipboard", true); });
                CardCaption(r, '', Lang.T("Clipboard"));
                CardSetup(r, Lang.T("Riwayat clipboard mati"), Lang.T("Klik untuk menyalakan"));
                return;
            }
            CardBase(r, "homeClips", HomeCard.Clips, delegate { ShowClips(); });
            CardCaption(r, '', Lang.T("Clipboard"));
            var c = clips[0];
            p.TextBox(Preview(c.Text, 160), Ink.Text(12.5f), p.T.Text, new RectangleF(r.X + 16, r.Y + 36, r.Width - 30, 36), StringAlignment.Near);
            p.Text(Lang.F("{0} karakter", c.Text.Length) + " · " + Fmt.Ago(c.Utc), Ink.Small(11f), p.T.Faint, r.X + 16, r.Y + 78, r.Width - 30, StringAlignment.Near);
        }

        void DrawHomePray(RectangleF r)
        {
            if (PrayCity() == null)
            {
                CardBase(r, "homePray", HomeCard.Pray, delegate { BeginInvoke(new Action(delegate { OpenPrefs("remind"); })); });
                CardCaption(r, IcoPray, Lang.T("Sholat"));
                CardSetup(r, Lang.T("Pilih kota"), Lang.T("Untuk waktu sholat hari ini"));
                return;
            }
            CardBase(r, "homePray", HomeCard.Pray, delegate { SetPage(PageRemind, false); });
            CardCaption(r, IcoPray, Lang.T("Sholat berikutnya"));
            DateTime at;
            int i = NextPrayer(out at);
            if (i < 0) return;
            p.Text(Lang.T(PrayTimes.Names[i]) + " " + Fmt.Hm(at), Ink.Display(20f), p.T.Text, r.X + 16, r.Y + 50, r.Width - 30, StringAlignment.Near);
            p.Text(Lang.F("{0} lagi", Fmt.Left(at - DateTime.Now)), Ink.Small(11.5f), p.T.Sub, r.X + 16, r.Y + 72, r.Width - 30, StringAlignment.Near);
        }

        void DrawComboCard(RectangleF r)
        {
            CardBase(r, "homeCombo", HomeCard.Combo, delegate { BeginInvoke(new Action(delegate { OpenPrefs("combo"); })); });
            if (!ComboOn && ComboXp == 0 && ComboAllTimeBest == 0 && !TypingSprintActive)
            {
                CardCaption(r, '\uE7FC', Lang.T("Combo Ketikan"));
                CardSetup(r, Lang.T("Combo Ketikan mati"), Lang.T("Klik untuk atur & nyalakan"));
                return;
            }
            string sprintLabel = TypingSprintActive ? TypingSprintLeft.ToString("0") + "s" : Lang.T("30s Sprint");
            var sf = Ink.Semi(10.5f);
            float bw = Math.Max(68f, p.Measure(sprintLabel, sf) + 16f);
            float bh = 22f;
            var btnRect = new RectangleF(r.Right - bw - 12f, r.Y + 11f, bw, bh);
            string capText = ComboRpgOn ? Lang.F("Lv.{0} · {1}", ComboLevel, ComboLevelTitle) : Lang.T("Combo Ketikan");
            p.Icon('\uE7FC', 12f, p.T.Sub, r.X + 22f, r.Y + 22f);
            p.Text(capText, Ink.Semi(11.5f), p.T.Sub, r.X + 34f, r.Y + 22f, Math.Max(30f, btnRect.Left - (r.X + 34f) - 6f), StringAlignment.Near);
            AddHit(btnRect, "homeSprint", delegate
            {
                BeginInvoke(new Action(delegate
                {
                    if (TypingSprintActive) StopTypingSprint();
                    else StartTypingSprint();
                }));
            });
            bool spDown = Pressed("homeSprint");
            bool spHover = Hover("homeSprint");
            Color spBg = TypingSprintActive
                ? (spDown ? Ink.Mix(p.T.Accent, Color.Black, 0.2f) : spHover ? Ink.Mix(p.T.Accent, Color.White, 0.15f) : p.T.Accent)
                : (spDown ? p.T.FillHover : spHover ? Ink.Mix(p.T.Fill, p.T.FillHover, 0.8f) : Ink.Mix(p.T.Fill, p.T.Text, 0.08f));
            Color spFg = TypingSprintActive ? Color.White : p.T.Text;
            p.FillRound(btnRect, bh / 2f, spBg);
            p.TextCenter(sprintLabel, sf, spFg, btnRect.X + btnRect.Width / 2f, btnRect.Y + btnRect.Height / 2f);

            float maxTextW = r.Width - 32f;
            string mainText = ComboAllTimeBest + "x · " + ComboAllTimePeakWpm + " WPM";
            p.Text(mainText, Ink.Semi(13.5f), TypingSprintActive ? p.T.Accent : p.T.Text, r.X + 16f, r.Y + 48f, maxTextW, StringAlignment.Near);
            string subText = Lang.F("Hari ini {0}", ComboDailyChars);
            if (ComboRpgOn) subText += " · " + ComboBadgesCount + "/" + ComboBadgesTotal + " " + Lang.T("lencana");
            p.Text(subText, Ink.Small(11f), p.T.Sub, r.X + 16f, r.Y + 69f, maxTextW, StringAlignment.Near);
            if (ComboRpgOn)
            {
                var bar = new RectangleF(r.X + 16f, r.Bottom - 10f, r.Width - 32f, 3f);
                p.FillRound(bar, 1.5f, p.T.Line);
                float prog = Math.Max(0f, Math.Min(1f, ComboLevelProgress));
                if (prog > 0f)
                    p.FillRound(new RectangleF(bar.X, bar.Y, Math.Max(3f, bar.Width * prog), 3f), 1.5f, p.T.Accent);
            }
        }

        void DrawPrioritiesCard(RectangleF r)
        {
            CardBase(r, "homePriorities", HomeCard.Priorities, delegate { BeginInvoke(new Action(delegate { PromptAddPriority(); })); });
            string cap = PriorityCount > 0 ? Lang.F("3 Prioritas · {0}/{1}", PriorityDoneCount, PriorityCount) : Lang.T("3 Prioritas Hari Ini");
            if (PriorityCount < 3)
            {
                string addLabel = "+ " + Lang.T("Tambah");
                var af = Ink.Semi(10.5f);
                float bw = Math.Max(64f, p.Measure(addLabel, af) + 16f);
                float bh = 22f;
                var addBtn = new RectangleF(r.Right - bw - 12f, r.Y + 11f, bw, bh);
                p.Icon('\uE73A', 12f, p.T.Sub, r.X + 22f, r.Y + 22f);
                p.Text(cap, Ink.Semi(11.5f), p.T.Sub, r.X + 34f, r.Y + 22f, Math.Max(30f, addBtn.Left - (r.X + 34f) - 6f), StringAlignment.Near);
                AddHit(addBtn, "prioAdd", delegate { BeginInvoke(new Action(PromptAddPriority)); });
                bool addDown = Pressed("prioAdd");
                bool addHover = Hover("prioAdd");
                Color addBg = addDown ? p.T.FillHover : addHover ? Ink.Mix(p.T.Fill, p.T.FillHover, 0.8f) : Ink.Mix(p.T.Fill, p.T.Text, 0.08f);
                p.FillRound(addBtn, bh / 2f, addBg);
                p.TextCenter(addLabel, af, p.T.Text, addBtn.X + addBtn.Width / 2f, addBtn.Y + addBtn.Height / 2f);
            }
            else
            {
                CardCaption(r, '\uE73A', cap);
            }

            if (PriorityCount == 0)
            {
                CardSetup(r, Lang.T("Tetapkan maks. 3 target utama hari ini"), Lang.T("Klik + Tambah atau pilih dari tugas"));
                return;
            }

            int count = Math.Min(3, PriorityCount);
            for (int i = 0; i < count; i++)
            {
                int idx = i;
                string title;
                bool done;
                if (!GetPriority(i, out title, out done)) continue;
                float ry = r.Y + 36f + i * 24f;
                float rh = 22f;
                var rowRect = new RectangleF(r.X + 12f, ry, r.Width - 24f, rh);
                bool rowHover = Hover("prioRow" + i) || Hover("prioChk" + i) || Hover("prioFoc" + i) || Hover("prioDel" + i);
                if (rowHover) p.FillRound(rowRect, 6f, Ink.A(p.T.Text, 0.05f));
                AddHit(rowRect, "prioRow" + i, delegate { TogglePriority(idx); });

                float chkX = r.X + 16f;
                float chkY = ry + (rh - 14f) / 2f;
                var chkRect = new RectangleF(chkX, chkY, 14f, 14f);
                AddHit(chkRect, "prioChk" + i, delegate { TogglePriority(idx); });
                bool chkHover = Hover("prioChk" + i);
                if (done)
                {
                    p.Circle(chkX + 7f, chkY + 7f, 7f, p.T.Accent);
                    p.Check(chkX + 7f, chkY + 7f, 8f, Color.White, 1f);
                }
                else
                {
                    p.StrokeRound(chkRect, 7f, chkHover ? p.T.Accent : p.T.Sub, 1.4f);
                }

                var delRect = new RectangleF(r.Right - 32f, ry + 1f, 20f, 20f);
                AddHit(delRect, "prioDel" + i, delegate { RemovePriority(idx); });
                if (rowHover)
                {
                    bool delHover = Hover("prioDel" + i);
                    if (delHover) p.FillRound(delRect, 5f, Ink.A(p.T.Text, 0.08f));
                    p.Cross(delRect.X + 10f, delRect.Y + 10f, 8f, delHover ? p.T.Text : p.T.Sub);
                }

                float textRight = delRect.Left - 4f;
                if (!done)
                {
                    var focRect = new RectangleF(delRect.Left - 24f, ry + 1f, 20f, 20f);
                    AddHit(focRect, "prioFoc" + i, delegate { StartFocusOnPriority(idx); });
                    bool focHover = Hover("prioFoc" + i);
                    if (focHover) p.FillRound(focRect, 5f, Ink.A(p.T.Accent, 0.14f));
                    p.Icon('\uE916', 11f, focHover ? p.T.Accent : (rowHover ? p.T.Text : p.T.Sub), focRect.X + 10f, focRect.Y + 10f);
                    textRight = focRect.Left - 4f;
                }

                float tx = chkRect.Right + 8f;
                float maxW = Math.Max(20f, textRight - tx);
                float cy = ry + rh / 2f;
                Font tf = Ink.Text(12f);
                p.Text(title, tf, done ? p.T.Faint : p.T.Text, tx, cy, maxW, StringAlignment.Near);
                if (done)
                {
                    float strikeW = Math.Min(maxW, p.Measure(title, tf));
                    if (strikeW > 2f) p.G.DrawLine(p.P(p.T.Faint, 1f), tx, cy, tx + strikeW, cy);
                }
            }
        }

        void DrawFocusCard(RectangleF r)
        {
            CardBase(r, "homeFocus", HomeCard.Focus, delegate { SetPage(PageControl, false); });
            string btnLabel = TimerOn ? Lang.T("Aktif") : Lang.T("Fokus 25m");
            var sf = Ink.Semi(10.5f);
            float bw = Math.Max(52f, p.Measure(btnLabel, sf) + 16f);
            float bh = 22f;
            var btnRect = new RectangleF(r.Right - bw - 12f, r.Y + 11f, bw, bh);
            string capText = Lang.T("Fokus") + (FocusStreakDays > 0 ? " · " + FocusStreakDays + Lang.T("h") : "");
            p.Icon('\uE916', 12f, p.T.Sub, r.X + 22f, r.Y + 22f);
            p.Text(capText, Ink.Semi(11.5f), p.T.Sub, r.X + 34f, r.Y + 22f, Math.Max(30f, btnRect.Left - (r.X + 34f) - 6f), StringAlignment.Near);
            AddHit(btnRect, "homeFocus25", delegate
            {
                if (!TimerOn) StartFocus(25);
                else SetPage(PageControl, false);
            });
            bool down = Pressed("homeFocus25");
            bool hover = Hover("homeFocus25");
            Color bg = TimerOn
                ? (down ? Ink.Mix(p.T.Accent, Color.Black, 0.2f) : hover ? Ink.Mix(p.T.Accent, Color.White, 0.15f) : p.T.Accent)
                : (down ? p.T.FillHover : hover ? Ink.Mix(p.T.Fill, p.T.FillHover, 0.8f) : Ink.Mix(p.T.Fill, p.T.Text, 0.08f));
            Color fg = TimerOn ? Color.White : p.T.Text;
            p.FillRound(btnRect, bh / 2f, bg);
            p.TextCenter(btnLabel, sf, fg, btnRect.X + btnRect.Width / 2f, btnRect.Y + btnRect.Height / 2f);

            float maxTextW = r.Width - 32f;
            string mainText = TimerOn && FocusTaskTitle.Length > 0
                ? FocusTaskTitle
                : FocusMinToday + " " + Lang.T("mnt") + " · " + FocusSessionsToday + " " + Lang.T("sesi");
            p.Text(mainText, Ink.Semi(13.5f), TimerOn ? p.T.Accent : p.T.Text, r.X + 16f, r.Y + 48f, maxTextW, StringAlignment.Near);

            string subText = Lang.F("Minggu ini {0} mnt · {1} tugas", FocusWeekTotalMin, FocusTasksDone);
            float barsTotalW = 7f * 5f + 6f * 3f;
            p.Text(subText, Ink.Small(11f), p.T.Sub, r.X + 16f, r.Y + 69f, Math.Max(30f, maxTextW - barsTotalW - 8f), StringAlignment.Near);

            int[] bars = FocusWeekBars();
            int maxBar = 1;
            if (bars != null)
                for (int i = 0; i < bars.Length; i++)
                    if (bars[i] > maxBar) maxBar = bars[i];
            float baseBottom = r.Bottom - 8f;
            for (int i = 0; i < 7; i++)
            {
                int val = bars != null && i < bars.Length ? bars[i] : 0;
                float barH = val > 0 ? Math.Max(2.5f, 10f * val / maxBar) : 2f;
                float bx = r.Right - 16f - (7 - i) * 5f - (6 - i) * 3f;
                Color bc = val <= 0 ? p.T.Line : (i == 6 ? p.T.Accent : Ink.A(p.T.Accent, 0.45f));
                p.FillRound(new RectangleF(bx, baseBottom - barH, 5f, barH), 1.5f, bc);
            }
        }
    }
}
