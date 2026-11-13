using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Tepi
{
    // Gamified typing combo: arcade hit counter, rank tiers, particles, and drain meter
    partial class Island
    {
        const int WH_KEYBOARD_LL = 13;
        const int WM_KEYDOWN = 0x0100, WM_KEYUP = 0x0101, WM_SYSKEYDOWN = 0x0104, WM_SYSKEYUP = 0x0105;
        const int ComboMinHits = 3;
        const float ComboWarmupWindowSec = 0.95f;
        const float ComboHoldSec = 2.2f;
        const float ComboFinishHoldSec = 1.35f;

        [StructLayout(LayoutKind.Sequential)]
        struct ComboKbdHook
        {
            public int Vk, Scan, Flags, Time;
            public IntPtr Extra;
        }

        sealed class ComboSpark
        {
            public float X, Y, Vx, Vy, Size, Life, MaxLife, Spin, Angle;
            public Color Color;
            public int Kind; // 0 = circle, 1 = 4-point star, 2 = diamond
        }

        sealed class ComboCallout
        {
            public string Text;
            public float X, Y, Vy, Life, MaxLife;
            public Color Color;
        }

        IntPtr comboHook = IntPtr.Zero;
        KeyHookProc comboHookProc;
        readonly bool[] comboKeyDown = new bool[256];
        readonly List<double> comboKeyTimes = new List<double>();
        readonly List<ComboSpark> comboSparks = new List<ComboSpark>();
        readonly List<ComboCallout> comboCallouts = new List<ComboCallout>();
        readonly Random comboRng = new Random();
        sealed class ComboShard
        {
            public float X, Y, Vx, Vy, W, H, Angle, Spin, Life, MaxLife;
            public Color Color;
        }

        readonly Spring comboPop = new Spring(0, 720, 28f, 0.002f);
        readonly Spring comboRing = new Spring(0, 260, 28f, 0.002f);
        readonly Spring comboShake = new Spring(0, 900, 27f, 0.002f);
        readonly List<ComboShard> comboShards = new List<ComboShard>();
        sealed class ComboConfettiPiece
        {
            public float X, Y, Vx, Vy, W, H, Angle, Spin, Flutter, FlutterSpd, Life, MaxLife;
            public Color Color;
            public bool Round;
        }
        readonly List<ComboConfettiPiece> comboConfetti = new List<ComboConfettiPiece>();

        int comboCount;
        int comboBest;
        int comboLastRun;
        int comboLastTier;
        int comboWpm;
        int comboPeakWpm;
        float comboTimeLeft;
        float comboFinishLeft;
        float comboBrokenLeft;
        float comboRankFlash;
        float comboGoldFlash;
        float comboShieldCrack;
        float comboEnterSmash;
        float comboRing2;
        double comboLastHitSec = -100;
        double comboLastEnterSec = -100;
        string comboLastKey = "";
        string comboCalloutWord = "";
        bool comboActive;
        int comboShields;
        int comboBackStreak;
        int comboCleanStreak;
        int comboRunXp;
        int comboLastRunXp;
        bool comboPbPlayedThisRun;
        bool combo100xCountedThisRun;
        int comboInitialBestThisRun;
        ToolStripMenuItem trayComboItem;

        // Persistent RPG, quest, badges & sprint state
        bool comboStatsLoaded;
        bool comboStatsDirty;
        int comboXp;
        int comboAllTimeBest;
        int comboAllTimePeakWpm;
        int comboTotalChars;
        string comboDailyDate = "";
        int comboDailyChars;
        int comboDaily100x;
        bool comboDailyQuestDone;
        readonly HashSet<string> comboBadges = new HashSet<string>();
        int comboSprintBestWpm;

        // 30-second Typing Sprint state
        bool sprintActive;
        float sprintLeft;
        float sprintDoneLeft;
        int sprintChars;
        int sprintRunCombo;
        int sprintFinalWpm;

        static readonly string[] ComboBadgeOrder =
        {
            "first_blood", "speed_demon", "unstoppable",
            "no_bs_ninja", "critical_finisher", "sprint_pro",
            "deep_focus", "priority_sweep"
        };

        public bool ComboOn
        {
            get { return settings != null && settings.GetBool("keys.combo", false); }
        }

        public bool ComboSoundOn
        {
            get { return settings != null && settings.GetBool("keys.combo.sound", false); }
        }

        public string ComboSoundProfile
        {
            get { return settings != null ? (settings.Get("keys.combo.sound.profile", "arcade") ?? "arcade") : "arcade"; }
        }

        public bool ComboFeverOn
        {
            get { return settings == null || settings.GetBool("keys.combo.fever", true); }
        }

        public bool ComboFeverActive
        {
            get { return comboActive && ComboFeverOn && ComboTierFor(comboCount) >= 5; }
        }

        public string ComboPenaltyMode
        {
            get { return settings != null ? (settings.Get("keys.combo.penalty", "shield") ?? "shield") : "shield"; }
        }

        public bool ComboEnterOn
        {
            get { return settings == null || settings.GetBool("keys.combo.enter", true); }
        }

        public bool ComboRpgOn
        {
            get { return settings == null || settings.GetBool("keys.combo.rpg", true); }
        }

        public int ComboQuestCharsGoal
        {
            get { return settings != null ? Math.Max(100, settings.GetInt("keys.combo.quest.chars", 5000)) : 5000; }
        }

        public int ComboQuest100xGoal
        {
            get { return settings != null ? Math.Max(1, settings.GetInt("keys.combo.quest.combos", 3)) : 3; }
        }

        public int ComboCount { get { return comboCount; } }
        public int ComboBest { get { return comboBest; } }
        public int ComboTier { get { return ComboTierFor(comboActive ? comboCount : comboLastRun); } }
        public int ComboWpm { get { return comboWpm; } }

        public int ComboXp { get { EnsureComboStatsLoaded(); return comboXp; } }
        public int ComboLevel { get { EnsureComboStatsLoaded(); return ComboLevelFor(comboXp); } }
        public string ComboLevelTitle { get { return ComboLevelTitleFor(ComboLevel); } }
        public float ComboLevelProgress { get { EnsureComboStatsLoaded(); return ComboLevelProgressFor(comboXp); } }
        public int ComboAllTimeBest { get { EnsureComboStatsLoaded(); return comboAllTimeBest; } }
        public int ComboAllTimePeakWpm { get { EnsureComboStatsLoaded(); return comboAllTimePeakWpm; } }
        public int ComboTotalChars { get { EnsureComboStatsLoaded(); return comboTotalChars; } }
        public int ComboDailyChars { get { EnsureComboStatsLoaded(); return comboDailyChars; } }
        public int ComboDaily100x { get { EnsureComboStatsLoaded(); return comboDaily100x; } }
        public bool ComboDailyQuestDone { get { EnsureComboStatsLoaded(); return comboDailyQuestDone; } }
        public int ComboBadgesCount { get { EnsureComboStatsLoaded(); return comboBadges.Count; } }
        public int ComboBadgesTotal { get { return ComboBadgeOrder.Length; } }
        public int ComboSprintBestWpm { get { EnsureComboStatsLoaded(); return comboSprintBestWpm; } }
        public bool TypingSprintActive { get { return sprintActive; } }
        public float TypingSprintLeft { get { return sprintLeft; } }

        public bool HasComboBadge(string id)
        {
            EnsureComboStatsLoaded();
            return !string.IsNullOrEmpty(id) && comboBadges.Contains(id);
        }

        public string ComboUnlockedBadgesSummary()
        {
            EnsureComboStatsLoaded();
            if (comboBadges.Count == 0) return Lang.T("Belum ada lencana");
            var list = new List<string>();
            for (int i = 0; i < ComboBadgeOrder.Length; i++)
            {
                if (comboBadges.Contains(ComboBadgeOrder[i]))
                    list.Add(ComboBadgeTitle(ComboBadgeOrder[i]));
            }
            return string.Join(", ", list.ToArray());
        }

        public bool ComboShowing
        {
            get { return (ComboOn && (comboActive || comboFinishLeft > 0.01f || comboBrokenLeft > 0.01f)) || sprintActive || sprintDoneLeft > 0.01f; }
        }
        void StartCombo()
        {
            EnsureComboStatsLoaded();
            SyncComboHook();
        }

        public void ReloadComboSettings()
        {
            EnsureComboStatsLoaded();
            CheckDailyQuest();
            SyncComboHook();
            Kick();
        }

        public void SyncComboHook()
        {
            if (ComboOn || sprintActive)
            {
                if (comboHook == IntPtr.Zero && !IsDisposed)
                {
                    comboHookProc = ComboHookCallback;
                    comboHook = SetWindowsHookEx(WH_KEYBOARD_LL, comboHookProc, GetModuleHandle(null), 0);
                }
                if (ComboSoundOn && !IsDisposed)
                {
                    EnsureComboAudio();
                    EnsureMixerStarted();
                }
            }
            else
            {
                StopComboHook();
                ResetCombo();
            }
            if (trayComboItem != null && !trayComboItem.IsDisposed)
                trayComboItem.Checked = ComboOn;
            Kick();
        }

        void StopComboHook()
        {
            if (comboHook != IntPtr.Zero)
            {
                UnhookWindowsHookEx(comboHook);
                comboHook = IntPtr.Zero;
            }
            comboHookProc = null;
            Array.Clear(comboKeyDown, 0, comboKeyDown.Length);
        }

        public void ResetCombo()
        {
            comboCount = 0;
            comboLastRun = 0;
            comboLastTier = 0;
            comboWpm = 0;
            comboTimeLeft = 0;
            comboFinishLeft = 0;
            comboBrokenLeft = 0;
            comboRankFlash = 0;
            comboGoldFlash = 0;
            comboShieldCrack = 0;
            comboEnterSmash = 0;
            comboRing2 = 0;
            comboActive = false;
            comboShields = 0;
            comboBackStreak = 0;
            comboCleanStreak = 0;
            comboRunXp = 0;
            comboPbPlayedThisRun = false;
            combo100xCountedThisRun = false;
            comboInitialBestThisRun = 0;
            comboLastKey = "";
            comboCalloutWord = "";
            comboKeyTimes.Clear();
            comboSparks.Clear();
            comboShards.Clear();
            comboCallouts.Clear();
            comboConfetti.Clear();
            Array.Clear(comboKeyDown, 0, comboKeyDown.Length);
            comboPop.Snap(0);
            comboRing.Snap(0);
            comboShake.Snap(0);
        }

        void EnsureComboStatsLoaded()
        {
            if (comboStatsLoaded) return;
            comboStatsLoaded = true;
            if (settings == null) return;
            comboXp = Math.Max(0, settings.GetInt("combo.xp", 0));
            comboAllTimeBest = Math.Max(0, settings.GetInt("combo.best", 0));
            comboAllTimePeakWpm = Math.Max(0, settings.GetInt("combo.peak_wpm", 0));
            comboTotalChars = Math.Max(0, settings.GetInt("combo.total_chars", 0));
            comboSprintBestWpm = Math.Max(0, settings.GetInt("combo.sprint.best_wpm", 0));
            string today = DateTime.Now.ToString("yyyy-MM-dd");
            comboDailyDate = settings.Get("combo.daily.date", today) ?? today;
            if (comboDailyDate != today)
            {
                comboDailyDate = today;
                comboDailyChars = 0;
                comboDaily100x = 0;
                comboDailyQuestDone = false;
                comboStatsDirty = true;
            }
            else
            {
                comboDailyChars = Math.Max(0, settings.GetInt("combo.daily.chars", 0));
                comboDaily100x = Math.Max(0, settings.GetInt("combo.daily.100x", 0));
                comboDailyQuestDone = settings.GetBool("combo.daily.done", false);
            }
            comboBadges.Clear();
            string rawBadges = settings.Get("combo.badges", "") ?? "";
            if (rawBadges.Length > 0)
            {
                string[] parts = rawBadges.Split(',');
                for (int i = 0; i < parts.Length; i++)
                {
                    string b = parts[i].Trim();
                    if (b.Length > 0) comboBadges.Add(b);
                }
            }
        }

        public void FlushComboStats()
        {
            if (!comboStatsDirty || settings == null) return;
            comboStatsDirty = false;
            settings.Set("combo.xp", comboXp.ToString());
            settings.Set("combo.best", comboAllTimeBest.ToString());
            settings.Set("combo.peak_wpm", comboAllTimePeakWpm.ToString());
            settings.Set("combo.total_chars", comboTotalChars.ToString());
            settings.Set("combo.daily.date", comboDailyDate ?? DateTime.Now.ToString("yyyy-MM-dd"));
            settings.Set("combo.daily.chars", comboDailyChars.ToString());
            settings.Set("combo.daily.100x", comboDaily100x.ToString());
            settings.Set("combo.daily.done", comboDailyQuestDone ? "1" : "0");
            settings.Set("combo.sprint.best_wpm", comboSprintBestWpm.ToString());
            var list = new List<string>(comboBadges);
            settings.Set("combo.badges", string.Join(",", list.ToArray()));
            settings.Save();
        }

        public void ResetComboStats()
        {
            StopTypingSprint();
            ResetCombo();
            EnsureComboStatsLoaded();
            comboXp = 0;
            comboBest = 0;
            comboAllTimeBest = 0;
            comboLastRunXp = 0;
            comboPeakWpm = 0;
            comboAllTimePeakWpm = 0;
            comboTotalChars = 0;
            comboDailyDate = DateTime.Now.ToString("yyyy-MM-dd");
            comboDailyChars = 0;
            comboDaily100x = 0;
            comboDailyQuestDone = false;
            comboBadges.Clear();
            comboSprintBestWpm = 0;
            comboStatsDirty = true;
            FlushComboStats();
            Kick();
        }

        public static int ComboLevelFor(int xp)
        {
            if (xp <= 0) return 1;
            int lv = 1;
            int rem = xp;
            while (true)
            {
                int need = 100 + (lv - 1) * 60;
                if (rem < need) break;
                rem -= need;
                lv++;
            }
            return lv;
        }

        public static float ComboLevelProgressFor(int xp)
        {
            if (xp <= 0) return 0f;
            int lv = 1;
            int rem = xp;
            while (true)
            {
                int need = 100 + (lv - 1) * 60;
                if (rem < need) return (float)rem / need;
                rem -= need;
                lv++;
            }
        }

        public static string ComboLevelTitleFor(int level)
        {
            if (level >= 25) return Lang.T("Dewa Keyboard");
            if (level >= 15) return Lang.T("Master Ketik");
            if (level >= 10) return Lang.T("Cyber Typist");
            if (level >= 6) return Lang.T("Arcade Striker");
            if (level >= 3) return Lang.T("Pengetik Gesit");
            return Lang.T("Pemula");
        }

        static string ComboBadgeTitle(string id)
        {
            switch (id)
            {
                case "first_blood": return Lang.T("First Blood (10x)");
                case "speed_demon": return Lang.T("Speed Demon (100 WPM)");
                case "unstoppable": return Lang.T("Unstoppable (250x)");
                case "no_bs_ninja": return Lang.T("No-Backspace Ninja");
                case "critical_finisher": return Lang.T("Critical Finisher");
                case "sprint_pro": return Lang.T("Sprint Pro (80+ WPM)");
                case "deep_focus": return Lang.T("Deep Worker (Fokus)");
                case "priority_sweep": return Lang.T("3/3 Prioritas Tuntas");
                default: return id;
            }
        }

        void UnlockComboBadge(string id)
        {
            if (!ComboRpgOn) return;
            EnsureComboStatsLoaded();
            if (comboBadges.Contains(id)) return;
            comboBadges.Add(id);
            comboStatsDirty = true;
            var t = ShowToast(View.Info, 3.0, 2, false, true);
            if (t != null)
            {
                t.Glyph = '\uE734';
                t.Title = Lang.T("Lencana Terbuka!");
                t.Detail = ComboBadgeTitle(id);
            }
            FlushComboStats();
        }

        void AddComboXp(int amount)
        {
            if (!ComboRpgOn || amount <= 0) return;
            EnsureComboStatsLoaded();
            int prevLv = ComboLevelFor(comboXp);
            comboXp += amount;
            comboRunXp += amount;
            comboStatsDirty = true;
            int newLv = ComboLevelFor(comboXp);
            if (newLv > prevLv)
            {
                var t = ShowToast(View.Info, 2.8, 2, false, true);
                if (t != null)
                {
                    t.Glyph = '\uE7FC';
                    t.Title = Lang.F("Naik Level! Lv.{0}", newLv);
                    t.Detail = ComboLevelTitleFor(newLv);
                }
            }
        }

        internal void GrantProductivityXp(int amount)
        {
            if (!ComboRpgOn || amount <= 0) return;
            AddComboXp(amount);
            FlushComboStats();
        }

        void CheckDailyQuest()
        {
            if (!ComboRpgOn || comboDailyQuestDone) return;
            if (comboDailyChars >= ComboQuestCharsGoal && comboDaily100x >= ComboQuest100xGoal)
            {
                comboDailyQuestDone = true;
                comboStatsDirty = true;
                celebrateUtc = DateTime.UtcNow;
                AddComboXp(150);
                var t = ShowToast(View.Info, 3.4, 2, false, true);
                if (t != null)
                {
                    t.Glyph = '\uE73E';
                    t.Title = Lang.T("Target Harian Tercapai!");
                    t.Detail = "+150 XP";
                }
                FlushComboStats();
            }
        }

        public void StartTypingSprint()
        {
            EnsureComboStatsLoaded();
            sprintLeft = 30f;
            sprintActive = true;
            sprintDoneLeft = 0f;
            sprintChars = 0;
            sprintRunCombo = 0;
            sprintFinalWpm = 0;
            expanded = false;
            SyncComboHook();
            Kick();
        }

        public void StopTypingSprint()
        {
            if (!sprintActive && sprintDoneLeft <= 0f) return;
            sprintActive = false;
            sprintDoneLeft = 0f;
            sprintLeft = 0f;
            SyncComboHook();
            Kick();
        }

        public void ToggleCombo()
        {
            bool next = !ComboOn;
            settings.Set("keys.combo", next ? "1" : "0");
            settings.Save();
            SyncComboHook();
            if (prefs != null && !prefs.IsDisposed) prefs.Relayout();
            var t = ShowToast(View.Info, 2.8, 2, false, true);
            if (t != null)
            {
                t.Glyph = '\uE7FC';
                t.Title = Lang.T(next ? "Combo Ketikan aktif" : "Combo Ketikan mati");
                t.Detail = Lang.T(next ? "Ketik cepat untuk memicu combo & efek seru!" : "Gamifikasi ketikan dinonaktifkan");
            }
            Kick();
        }

        IntPtr ComboHookCallback(int code, IntPtr msg, IntPtr info)
        {
            if (code >= 0 && (ComboOn || sprintActive))
            {
                try
                {
                    var k = (ComboKbdHook)Marshal.PtrToStructure(info, typeof(ComboKbdHook));
                    // Ignore synthetic/injected events (LLKHF_INJECTED = 0x10)
                    if ((k.Flags & 0x10) == 0)
                    {
                        int m = msg.ToInt32();
                        int vk = k.Vk;
                        if (m == WM_KEYUP || m == WM_SYSKEYUP)
                        {
                            if (vk >= 0 && vk < 256) comboKeyDown[vk] = false;
                        }
                        else if (m == WM_KEYDOWN || m == WM_SYSKEYDOWN)
                        {
                            if (vk >= 0 && vk < 256 && !comboKeyDown[vk])
                            {
                                comboKeyDown[vk] = true;
                                bool sysAlt = m == WM_SYSKEYDOWN && !(comboKeyDown[0x11] || comboKeyDown[0xA2] || comboKeyDown[0xA3]);
                                if (!sysAlt && !IsComboShortcutHeld() && IsTypingKey(vk))
                                {
                                    int capturedVk = vk;
                                    Post(delegate { OnComboKeystroke(capturedVk); });
                                }
                            }
                        }
                    }
                }
                catch (Exception) { }
            }
            return CallNextHookEx(comboHook, code, msg, info);
        }

        bool IsComboShortcutHeld()
        {
            // Win key (LWin 0x5B, RWin 0x5C)
            if (comboKeyDown[0x5B] || comboKeyDown[0x5C]) return true;
            bool ctrl = comboKeyDown[0x11] || comboKeyDown[0xA2] || comboKeyDown[0xA3];
            bool alt = comboKeyDown[0x12] || comboKeyDown[0xA4] || comboKeyDown[0xA5];
            // Allow Ctrl+Alt (AltGr on international layouts), block standalone Ctrl or Alt shortcuts
            return ctrl != alt;
        }

        public static bool IsTypingKey(int vk)
        {
            if (vk <= 0 || vk >= 256) return false;
            // Letters A-Z and digits 0-9
            if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)) return true;
            // Numpad 0-9 and operators
            if (vk >= 0x60 && vk <= 0x6F) return true;
            // Space, Enter, Backspace, Tab, Delete
            if (vk == 0x20 || vk == 0x0D || vk == 0x08 || vk == 0x09 || vk == 0x2E) return true;
            // OEM punctuation keys (; = , - . / ` [ \ ] ') and VK_PACKET (IME/Unicode)
            if (vk >= 0xBA && vk <= 0xC0) return true;
            if (vk >= 0xDB && vk <= 0xDF) return true;
            if (vk == 0xE2 || vk == 0xE7) return true;
            return false;
        }

        public static string KeyCapLabel(int vk)
        {
            if (vk >= 0x41 && vk <= 0x5A) return ((char)vk).ToString();
            if (vk >= 0x30 && vk <= 0x39) return ((char)vk).ToString();
            if (vk >= 0x60 && vk <= 0x69) return ((char)('0' + (vk - 0x60))).ToString();
            switch (vk)
            {
                case 0x20: return "SPC";
                case 0x0D: return "⏎";
                case 0x08: return "⌫";
                case 0x09: return "TAB";
                case 0x2E: return "DEL";
                case 0x6A: return "*";
                case 0x6B: return "+";
                case 0x6C: return "⏎";
                case 0x6D: return "-";
                case 0x6E: return ".";
                case 0x6F: return "/";
                case 0xBA: return ";";
                case 0xBB: return "=";
                case 0xBC: return ",";
                case 0xBD: return "-";
                case 0xBE: return ".";
                case 0xBF: return "/";
                case 0xC0: return "`";
                case 0xDB: return "[";
                case 0xDC:
                case 0xE2: return "\\";
                case 0xDD: return "]";
                case 0xDE: return "'";
                case 0xE7: return "IME";
                default: return "KEY";
            }
        }

        public bool RegisterComboKeystroke(int vk)
        {
            if (!ComboOn && !sprintActive) return false;
            if (vk < 0 || vk >= 256) return false;
            if (comboKeyDown[vk]) return false;
            comboKeyDown[vk] = true;
            if (IsComboShortcutHeld() || !IsTypingKey(vk)) return false;
            OnComboKeystroke(vk);
            return true;
        }

        public void ReleaseComboKey(int vk)
        {
            if (vk >= 0 && vk < 256) comboKeyDown[vk] = false;
        }

        void OnComboKeystroke(int vk)
        {
            if ((!ComboOn && !sprintActive) || dormant || hiddenByUser || keyboardMode) return;
            EnsureComboStatsLoaded();
            double now = clock.Elapsed.TotalSeconds;
            double dtSinceLast = now - comboLastHitSec;

            bool isPenaltyKey = (vk == 0x08 || vk == 0x2E);
            if (isPenaltyKey)
            {
                comboCleanStreak = 0;
                if (!comboActive) return;
                comboLastKey = KeyCapLabel(vk);
                if (ComboPenaltyMode == "off")
                {
                    PlayComboKeySound(comboCount, false);
                    return;
                }
                comboLastKey = KeyCapLabel(vk);
                if (ComboPenaltyMode == "shield" && comboShields > 0)
                {
                    comboShields--;
                    comboShieldCrack = 1f;
                    comboBackStreak++;
                    comboShake.Snap((comboBackStreak & 1) == 0 ? 4.2f : -4.2f);
                    comboShake.Target = 0;
                    SpawnComboCallout(Lang.T("SHIELD RETAK!"), Color.FromArgb(255, 255, 190, 60));
                    PlayComboShieldCrackSound();
                    Kick();
                    return;
                }
                comboBackStreak++;
                comboTimeLeft -= (0.55f + Math.Min(0.4f, (comboBackStreak - 1) * 0.1f));
                comboShake.Snap((comboBackStreak & 1) == 0 ? 5.2f : -5.2f);
                comboShake.Target = 0;
                SpawnComboCallout("-DRAIN", Color.FromArgb(255, 255, 80, 90));
                if (comboTimeLeft <= 0f)
                {
                    BreakCombo();
                    return;
                }
                Kick();
                return;
            }

            // If not yet active and gap was too slow, start fresh warmup and clear any stale key states
            if (!comboActive && dtSinceLast > ComboWarmupWindowSec)
            {
                comboCount = 0;
                comboKeyTimes.Clear();
                Array.Clear(comboKeyDown, 0, comboKeyDown.Length);
                if (vk >= 0 && vk < 256) comboKeyDown[vk] = true;
            }
            if (!comboActive && comboCount == 0)
            {
                comboWpm = 0;
                comboPeakWpm = 0;
            }

            comboLastHitSec = now;
            comboCount++;
            if (comboCount > comboBest) comboBest = comboCount;
            comboLastKey = KeyCapLabel(vk);

            if (!isPenaltyKey)
            {
                comboCleanStreak++;
                comboTotalChars++;
                comboDailyChars++;
                comboStatsDirty = true;
                if (sprintActive)
                {
                    sprintChars++;
                }
            }
            else
            {
                comboCleanStreak = 0;
            }

            // Rolling 3.5-second window for live WPM calculation (5 chars = 1 word)
            comboKeyTimes.Add(now);
            double cutoff = now - 3.5;
            while (comboKeyTimes.Count > 0 && comboKeyTimes[0] < cutoff)
                comboKeyTimes.RemoveAt(0);
            double span = comboKeyTimes.Count > 1 ? Math.Max(0.45, now - comboKeyTimes[0]) : 0.6;
            double cps = comboKeyTimes.Count / span;
            int rawWpm = (int)Math.Round((cps * 60.0) / 5.0);
            comboWpm = Math.Max(15, Math.Min(320, comboWpm == 0 ? rawWpm : (int)Math.Round(comboWpm * 0.6 + rawWpm * 0.4)));

            if (comboCount < ComboMinHits && !comboActive)
            {
                PlayComboKeySound(comboCount, false);
                return;
            }

            bool justActivated = !comboActive;
            comboActive = true;
            comboFinishLeft = 0;
            comboBrokenLeft = 0;
            comboLastRun = comboCount;
            if (comboWpm > comboPeakWpm) comboPeakWpm = comboWpm;
            if (comboWpm > comboAllTimePeakWpm) { comboAllTimePeakWpm = comboWpm; comboStatsDirty = true; }
            if (justActivated)
            {
                comboShields = ComboPenaltyMode == "shield" ? 1 : 0;
                comboBackStreak = 0;
                comboRunXp = 0;
                comboPbPlayedThisRun = false;
                combo100xCountedThisRun = false;
                comboInitialBestThisRun = comboAllTimeBest;
            }
            int tier = ComboTierFor(comboCount);
            int mult = ComboFeverOn ? (tier >= 6 ? 4 : tier >= 5 ? 2 : 1) : 1;
            // Slightly tighter drain window at extreme tiers for arcade excitement
            float hold = tier >= 5 ? 1.85f : tier >= 3 ? 2.0f : ComboHoldSec;
            comboTimeLeft = hold;

            // Persistent all-time best & PB fanfare
            if (comboCount > comboAllTimeBest)
            {
                if (!comboPbPlayedThisRun && comboInitialBestThisRun >= 10 && comboCount > comboInitialBestThisRun)
                {
                    comboPbPlayedThisRun = true;
                    PlayComboPbFanfare();
                    SpawnComboCallout("NEW RECORD!", Color.FromArgb(255, 255, 220, 70));
                    float cw = OnSide ? SideW : ComboWidth();
                    float ch = OnSide ? 84f : ComboHeight();
                    SpawnComboConfetti(36, cw * 0.4f, ch * 0.5f, 340f, true, true);
                    if (!Anim.Reduced) celebrateUtc = DateTime.UtcNow;
                }
                comboAllTimeBest = comboCount;
                comboStatsDirty = true;
            }

            // XP & Badges & Daily Quest
            AddComboXp(1 * mult);
            if (comboCount >= 10) UnlockComboBadge("first_blood");
            if (comboWpm >= 100) UnlockComboBadge("speed_demon");
            if (comboCount >= 250) UnlockComboBadge("unstoppable");
            if (comboCleanStreak >= 50) UnlockComboBadge("no_bs_ninja");
            if (comboCount >= 100 && !combo100xCountedThisRun)
            {
                combo100xCountedThisRun = true;
                comboDaily100x++;
                comboStatsDirty = true;
            }
            CheckDailyQuest();

            // Per-keystroke in-memory audio
            PlayComboKeySound(comboCount, false);
            // Spring pop & island recoil on every hit
            comboPop.Snap(Math.Min(1.35f, 0.72f + tier * 0.1f));
            comboPop.Target = 0;
            comboPop.Velocity = 4.5f + tier * 1.2f;

            float dir = (comboCount & 1) == 0 ? 1f : -1f;
            comboShake.Snap(dir * Math.Min(4.5f, 1.2f + tier * 0.55f));
            comboShake.Target = 0;

            if (!Anim.Reduced && current == View.Combo)
            {
                float alongV = Math.Min(110f, 32f + tier * 12f);
                float acrossV = Math.Min(48f, 14f + tier * 5f);
                sw.Velocity += OnSide ? acrossV : alongV;
                sh.Velocity += OnSide ? alongV : acrossV;
            }

            Color tc = ComboTierColor(tier, now);
            int sparkCount = justActivated ? 8 : (2 + Math.Min(5, tier));
            SpawnComboSparks(sparkCount, false, tc);

            // Check for rank-up or milestone burst
            if (tier > comboLastTier)
            {
                comboLastTier = tier;
                comboRankFlash = 1f;
                comboRing.Snap(0.05f);
                comboRing.Target = 1f;
                comboCalloutWord = tier >= 6 ? "GODLIKE!!!" : tier == 5 ? "ULTRA!!" : tier == 4 ? "AWESOME!" : tier == 3 ? "GREAT!!" : tier == 2 ? "NICE!" : "COMBO!";
                SpawnComboCallout(comboCalloutWord, tc);
                SpawnComboSparks(14 + tier * 3, true, tc);
                if (tier >= 2)
                {
                    float cw = OnSide ? SideW : ComboWidth();
                    float ch = OnSide ? 84f : ComboHeight();
                    SpawnComboConfetti(12 + tier * 5, cw * 0.5f, ch * 0.5f, 320f, false, tier >= 4);
                }

                if (!Anim.Reduced)
                {
                    float alongV = 180f + tier * 25f;
                    float acrossV = 75f + tier * 10f;
                    sw.Velocity += OnSide ? acrossV : alongV;
                    sh.Velocity += OnSide ? alongV : acrossV;
                    topGap.Velocity += 55f;
                    if (tier >= 3) celebrateUtc = DateTime.UtcNow;
                }

                EyesReact(tier >= 4 ? EyeMood.Surprised : EyeMood.Happy, 0);
                PlayComboTierUpSound(tier);
            }
            else if (comboCount % 25 == 0)
            {
                comboRankFlash = 0.75f;
                comboRing.Snap(0.1f);
                comboRing.Target = 1f;
                SpawnComboCallout(comboCount + " HIT STREAK!", tc);
                SpawnComboSparks(12, true, tc);
                float cw = OnSide ? SideW : ComboWidth();
                float ch = OnSide ? 84f : ComboHeight();
                SpawnComboConfetti(22, cw * 0.5f, ch * 0.5f, 300f, false, false);
            }
            else if (comboCount % 5 == 0)
            {
                string[] words = { "FAST!", "CRIT!", "FIRE!", "CLEAN!", "SHARP!" };
                SpawnComboCallout(words[(comboCount / 5) % words.Length], tc);
            }

            // Clean streak 25x milestone: PERFECT CHAIN!
            if (!isPenaltyKey && comboCleanStreak > 0 && comboCleanStreak % 25 == 0)
            {
                comboGoldFlash = 1f;
                AddComboXp(20 * mult);
                if (ComboPenaltyMode == "shield" && comboShields < 2) comboShields++;
                SpawnComboCallout("PERFECT CHAIN!", Color.FromArgb(255, 255, 214, 10));
                float cw = OnSide ? SideW : ComboWidth();
                float ch = OnSide ? 84f : ComboHeight();
                SpawnComboConfetti(22, cw * 0.45f, ch * 0.5f, 280f, true, false);
            }

            // Enter finisher move: CRITICAL FINISH!
            if (vk == 0x0D && ComboEnterOn && comboActive && comboCount >= 25 && (now - comboLastEnterSec) >= 1.2)
            {
                comboLastEnterSec = now;
                comboEnterSmash = 1f;
                comboRankFlash = 0.85f;
                comboRing.Snap(0.04f);
                comboRing.Target = 1f;
                comboRing2 = 0.01f;
                comboTimeLeft = Math.Min(hold, comboTimeLeft + 0.35f);
                AddComboXp(25 * mult);
                UnlockComboBadge("critical_finisher");
                SpawnComboCallout("CRITICAL FINISH!", Color.FromArgb(255, 255, 140, 40));
                SpawnComboConfetti(28, OnSide ? SideW * 0.5f : ComboWidth() - 34f, OnSide ? 42f : ComboHeight() * 0.5f, 300f, false, true);
                if (!Anim.Reduced) celebrateUtc = DateTime.UtcNow;
                if (!Anim.Reduced)
                {
                    float kx = (OnSide ? SideW * 0.5f : ComboWidth() - 34f);
                    float ky = (OnSide ? 42f : ComboHeight() * 0.5f);
                    for (int i = 0; i < 16; i++)
                    {
                        if (comboSparks.Count >= 64) comboSparks.RemoveAt(0);
                        float vx = ((i & 1) == 0 ? 1f : -1f) * (35f + (float)comboRng.NextDouble() * 85f);
                        float vy = -(45f + (float)comboRng.NextDouble() * 95f);
                        comboSparks.Add(new ComboSpark
                        {
                            X = kx, Y = ky, Vx = vx, Vy = vy,
                            Size = 2.6f + (float)comboRng.NextDouble() * 2.4f,
                            Life = 0f, MaxLife = 0.5f + (float)comboRng.NextDouble() * 0.25f,
                            Spin = ((float)comboRng.NextDouble() - 0.5f) * 12f,
                            Angle = (float)(comboRng.NextDouble() * Math.PI),
                            Color = (i % 2 == 0) ? Color.FromArgb(255, 255, 200, 70) : Color.FromArgb(255, 255, 110, 40),
                            Kind = i % 3
                        });
                    }
                }
                PlayComboCriticalSound();
            }

            Kick();
        }

        void BreakCombo()
        {
            comboTimeLeft = 0f;
            comboActive = false;
            comboLastRun = comboCount;
            comboBrokenLeft = 1.15f;
            comboLastRunXp = comboRunXp;
            SpawnComboShards(ComboTierColor(ComboTierFor(comboCount), clock.Elapsed.TotalSeconds));
            comboCount = 0;
            comboLastTier = 0;
            comboWpm = 0;
            comboPeakWpm = 0;
            comboKeyTimes.Clear();
            Array.Clear(comboKeyDown, 0, comboKeyDown.Length);
            PlayComboBrokenSound();
            FlushComboStats();
            Kick();
        }

        void SpawnComboShards(Color c)
        {
            if (Anim.Reduced) return;
            comboShards.Clear();
            for (int i = 0; i < 16; i++)
            {
                double ang = (i / 16.0) * Math.PI * 2.0 + comboRng.NextDouble() * 0.35;
                float spd = 55f + (float)comboRng.NextDouble() * 95f;
                comboShards.Add(new ComboShard
                {
                    X = 48f + ((float)comboRng.NextDouble() - 0.5f) * 32f,
                    Y = 24f + ((float)comboRng.NextDouble() - 0.5f) * 14f,
                    Vx = (float)Math.Cos(ang) * spd,
                    Vy = (float)Math.Sin(ang) * spd - 35f,
                    W = 4f + (float)comboRng.NextDouble() * 4f,
                    H = 3f + (float)comboRng.NextDouble() * 3f,
                    Angle = (float)(comboRng.NextDouble() * Math.PI),
                    Spin = ((float)comboRng.NextDouble() - 0.5f) * 14f,
                    Life = 0f,
                    MaxLife = 0.7f + (float)comboRng.NextDouble() * 0.35f,
                    Color = (i % 3 == 0) ? Color.FromArgb(255, 255, 90, 95) : c
                });
            }
        }

        void SpawnComboSparks(int count, bool burst, Color baseCol)
        {
            if (Anim.Reduced) return;
            bool side = OnSide;
            float w = side ? SideW : ComboWidth(), h = side ? 84f : ComboHeight();
            for (int i = 0; i < count; i++)
            {
                if (comboSparks.Count >= 64) comboSparks.RemoveAt(0);
                double ang = comboRng.NextDouble() * Math.PI * 2.0;
                float spd = (burst ? 58f : 28f) + (float)comboRng.NextDouble() * (burst ? 95f : 52f);
                float ox = side
                    ? (w * 0.5f + ((float)comboRng.NextDouble() - 0.5f) * 18f)
                    : (burst ? (w * 0.35f + (float)comboRng.NextDouble() * (w * 0.3f)) : (54f + (float)comboRng.NextDouble() * 44f));
                float oy = h * 0.5f + ((float)comboRng.NextDouble() - 0.5f) * (side ? 28f : 16f);
                Color c = (i % 3 == 0) ? Color.FromArgb(255, 255, 245, 200) : baseCol;
                comboSparks.Add(new ComboSpark
                {
                    X = ox,
                    Y = oy,
                    Vx = (float)Math.Cos(ang) * spd,
                    Vy = (float)Math.Sin(ang) * spd - (burst ? 18f : 8f),
                    Size = (burst ? 3.2f : 2.2f) + (float)comboRng.NextDouble() * 2.4f,
                    Life = 0f,
                    MaxLife = (burst ? 0.55f : 0.38f) + (float)comboRng.NextDouble() * 0.25f,
                    Spin = ((float)comboRng.NextDouble() - 0.5f) * 10f,
                    Angle = (float)(comboRng.NextDouble() * Math.PI),
                    Color = c,
                    Kind = i % 3
                });
            }
        }

        static readonly Color[] ComboConfettiPalette =
        {
            Color.FromArgb(255, 50, 173, 230),  // cyan
            Color.FromArgb(255, 48, 209, 88),   // arcade green
            Color.FromArgb(255, 255, 214, 10),  // electric gold
            Color.FromArgb(255, 255, 159, 10),  // blaze orange
            Color.FromArgb(255, 255, 55, 95),   // crimson pink
            Color.FromArgb(255, 175, 82, 222),  // violet
            Color.FromArgb(255, 255, 248, 220)  // warm white
        };

        static readonly Color[] ComboConfettiGoldPalette =
        {
            Color.FromArgb(255, 255, 214, 10),  // electric gold
            Color.FromArgb(255, 255, 248, 220), // warm white
            Color.FromArgb(255, 255, 185, 40),  // rich gold
            Color.FromArgb(255, 255, 159, 10),  // blaze orange
            Color.FromArgb(255, 255, 235, 130)  // soft gold
        };

        void SpawnComboConfetti(int count, float ox, float oy, float spreadX, bool goldTheme, bool tierBoost)
        {
            if (Anim.Reduced || count <= 0) return;
            Color[] pal = goldTheme ? ComboConfettiGoldPalette : ComboConfettiPalette;
            float boost = tierBoost ? 1.15f : 1.0f;
            bool side = OnSide;
            float effSpreadX = side ? Math.Min(spreadX, SideW * 1.35f) : spreadX;
            for (int i = 0; i < count; i++)
            {
                if (comboConfetti.Count >= 96) comboConfetti.RemoveAt(0);
                bool round = (i % 5 == 0);
                float w = round ? (3.2f + (float)comboRng.NextDouble() * 2.0f) : (4.2f + (float)comboRng.NextDouble() * 3.4f);
                float h = round ? w : (2.4f + (float)comboRng.NextDouble() * 2.0f);
                float scatterY = ((float)comboRng.NextDouble() - 0.5f) * 20f;
                comboConfetti.Add(new ComboConfettiPiece
                {
                    X = ox + ((float)comboRng.NextDouble() - 0.5f) * (side ? 12f : 24f),
                    Y = side ? Math.Max(8f, Math.Min(76f, oy + scatterY)) : Math.Max(6f, Math.Min(38f, oy + scatterY)),
                    Vx = ((float)comboRng.NextDouble() - 0.5f) * effSpreadX * boost,
                    Vy = (side ? (-35f - (float)comboRng.NextDouble() * 75f) : (-20f - (float)comboRng.NextDouble() * 55f)) * boost,
                    W = w,
                    H = h,
                    Angle = (float)(comboRng.NextDouble() * Math.PI * 2.0),
                    Spin = ((float)comboRng.NextDouble() - 0.5f) * 14f,
                    Flutter = (float)(comboRng.NextDouble() * Math.PI * 2.0),
                    FlutterSpd = 9f + (float)comboRng.NextDouble() * 7f,
                    Life = 0f,
                    MaxLife = 0.85f + (float)comboRng.NextDouble() * 0.45f,
                    Color = pal[comboRng.Next(pal.Length)],
                    Round = round
                });
            }
        }

        void DrawComboConfetti()
        {
            if (Anim.Reduced || comboConfetti.Count == 0) return;
            for (int i = 0; i < comboConfetti.Count; i++)
            {
                var cf = comboConfetti[i];
                float t = Ease.Clamp01(cf.Life / Math.Max(0.01f, cf.MaxLife));
                float a = (1f - t * t) * 0.92f * p.Alpha;
                if (a <= 0.02f) continue;
                float flipScale = 0.25f + 0.75f * Math.Abs((float)Math.Cos(cf.Flutter));
                var st = g.Save();
                g.TranslateTransform(cf.X, cf.Y);
                g.RotateTransform(cf.Angle * 57.29578f);
                using (var b = new SolidBrush(Ink.A(cf.Color, a)))
                {
                    if (cf.Round)
                        g.FillEllipse(b, -cf.W * 0.5f, -cf.H * 0.5f, cf.W, cf.H);
                    else
                    {
                        float rh = cf.H * flipScale;
                        g.FillRectangle(b, -cf.W * 0.5f, -rh * 0.5f, cf.W, rh);
                    }
                }
                g.Restore(st);
            }
        }

        void SpawnComboCallout(string text, Color c)
        {
            if (Anim.Reduced || string.IsNullOrEmpty(text)) return;
            if (comboCallouts.Count >= 4) comboCallouts.RemoveAt(0);
            float w = ComboWidth();
            float chosenY = 39f;
            float bestMinDist = -1f;
            for (int slot = 0; slot < 4; slot++)
            {
                float candY = 9f + slot * 10f;
                float minDist = 1e6f;
                bool clash = false;
                for (int j = 0; j < comboCallouts.Count; j++)
                {
                    float d = Math.Abs(comboCallouts[j].Y - candY);
                    if (d < minDist) minDist = d;
                    if (d < 8.5f) clash = true;
                }
                if (!clash)
                {
                    chosenY = candY;
                    break;
                }
                if (minDist > bestMinDist)
                {
                    bestMinDist = minDist;
                    chosenY = candY;
                }
            }
            comboCallouts.Add(new ComboCallout
            {
                Text = text,
                X = w - 108f + ((float)comboRng.NextDouble() - 0.5f) * 16f,
                Y = chosenY,
                Vy = -22f,
                Life = 0f,
                MaxLife = 0.65f,
                Color = c
            });
        }

        public static int ComboTierFor(int hits)
        {
            if (hits >= 200) return 6;
            if (hits >= 100) return 5;
            if (hits >= 50) return 4;
            if (hits >= 25) return 3;
            if (hits >= 10) return 2;
            if (hits >= ComboMinHits) return 1;
            return 0;
        }

        public static string ComboRankLabel(int tier)
        {
            switch (tier)
            {
                case 6: return "GODLIKE!!!";
                case 5: return "ULTRA!!";
                case 4: return "AWESOME!";
                case 3: return "GREAT!!";
                case 2: return "NICE!";
                default: return "COMBO";
            }
        }

        public static string ComboRankSubtitle(int tier)
        {
            switch (tier)
            {
                case 6: return Lang.T("Dewa Ketik!");
                case 5: return Lang.T("Tak terhentikan!");
                case 4: return Lang.T("Kecepatan kilat!");
                case 3: return Lang.T("Jari menari!");
                case 2: return Lang.T("Ketikan cepat!");
                default: return Lang.T("Mulai panas!");
            }
        }

        public static Color ComboTierColor(int tier, double animSec)
        {
            switch (tier)
            {
                case 6: return ComboRainbow(animSec * 1.8);
                case 5: return Color.FromArgb(255, 255, 55, 95);   // Hyper Crimson/Pink
                case 4: return Color.FromArgb(255, 255, 159, 10);  // Blaze Orange
                case 3: return Color.FromArgb(255, 255, 214, 10);  // Electric Gold
                case 2: return Color.FromArgb(255, 48, 209, 88);   // Arcade Green
                default: return Color.FromArgb(255, 50, 173, 230); // Electric Cyan
            }
        }

        static Color ComboRainbow(double t)
        {
            double h = (t - Math.Floor(t)) * 6.0;
            int seg = (int)h;
            double f = h - seg;
            int q = (int)Math.Round(255 * (1.0 - f * 0.75));
            int u = (int)Math.Round(255 * (0.25 + f * 0.75));
            switch (seg % 6)
            {
                case 0: return Color.FromArgb(255, 255, u, 70);
                case 1: return Color.FromArgb(255, q, 255, 70);
                case 2: return Color.FromArgb(255, 70, 255, u);
                case 3: return Color.FromArgb(255, 70, q, 255);
                case 4: return Color.FromArgb(255, u, 70, 255);
                default: return Color.FromArgb(255, 255, 70, q);
            }
        }

        float ComboDrainFraction()
        {
            if (!comboActive) return 0f;
            int tier = ComboTierFor(comboCount);
            float hold = tier >= 5 ? 1.85f : tier >= 3 ? 2.0f : ComboHoldSec;
            return Ease.Clamp01(comboTimeLeft / hold);
        }

        void StepCombo(float dt)
        {
            comboPop.Step(dt);
            comboRing.Step(dt);
            comboShake.Step(dt);

            if (comboRankFlash > 0f)
                comboRankFlash = Math.Max(0f, comboRankFlash - dt * 2.4f);
            if (comboGoldFlash > 0f)
                comboGoldFlash = Math.Max(0f, comboGoldFlash - dt * 2.2f);
            if (comboShieldCrack > 0f)
                comboShieldCrack = Math.Max(0f, comboShieldCrack - dt * 2.8f);
            if (comboEnterSmash > 0f)
                comboEnterSmash = Math.Max(0f, comboEnterSmash - dt * 3.0f);
            if (comboRing2 > 0f)
            {
                comboRing2 += dt * 1.9f;
                if (comboRing2 >= 1f) comboRing2 = 0f;
            }
            if (comboBrokenLeft > 0f)
            {
                comboBrokenLeft = Math.Max(0f, comboBrokenLeft - dt);
                if (comboBrokenLeft <= 0.01f)
                {
                    comboBrokenLeft = 0f;
                    comboWpm = 0;
                    comboPeakWpm = 0;
                }
            }

            for (int i = comboShards.Count - 1; i >= 0; i--)
            {
                var sh = comboShards[i];
                sh.Life += dt;
                if (sh.Life >= sh.MaxLife) { comboShards.RemoveAt(i); continue; }
                sh.X += sh.Vx * dt;
                sh.Y += sh.Vy * dt;
                sh.Vy += 190f * dt;
                sh.Angle += sh.Spin * dt;
            }
            for (int i = comboSparks.Count - 1; i >= 0; i--)
            {
                var s = comboSparks[i];
                s.Life += dt;
                if (s.Life >= s.MaxLife)
                {
                    comboSparks.RemoveAt(i);
                    continue;
                }
                s.X += s.Vx * dt;
                s.Y += s.Vy * dt;
                s.Vy += 110f * dt; // subtle gravity
                s.Vx *= (float)Math.Pow(0.25, dt);
                s.Angle += s.Spin * dt;
            }
            for (int i = comboConfetti.Count - 1; i >= 0; i--)
            {
                var cf = comboConfetti[i];
                cf.Life += dt;
                if (cf.Life >= cf.MaxLife)
                {
                    comboConfetti.RemoveAt(i);
                    continue;
                }
                cf.X += cf.Vx * dt;
                cf.Y += cf.Vy * dt;
                cf.Vx *= (float)Math.Pow(0.28, dt);
                cf.Vy += 58f * dt;
                cf.Vy *= (float)Math.Pow(0.45, dt);
                cf.Angle += cf.Spin * dt;
                cf.Flutter += cf.FlutterSpd * dt;
            }

            for (int i = comboCallouts.Count - 1; i >= 0; i--)
            {
                var c = comboCallouts[i];
                c.Life += dt;
                if (c.Life >= c.MaxLife)
                {
                    comboCallouts.RemoveAt(i);
                    continue;
                }
                c.Y += c.Vy * dt;
            }

            if (comboActive)
            {
                comboTimeLeft -= dt;
                if (comboTimeLeft <= 0f)
                {
                    comboTimeLeft = 0f;
                    comboActive = false;
                    comboLastRun = comboCount;
                    comboLastRunXp = comboRunXp;
                    // Show a brief finisher summary if the user reached at least Tier 2 (10+ hits)
                    if (comboCount >= 10)
                    {
                        comboFinishLeft = ComboFinishHoldSec;
                        comboPop.Snap(0.65f);
                        comboPop.Target = 0f;
                    }
                    comboCount = 0;
                    comboLastTier = 0;
                    comboKeyTimes.Clear();
                    Array.Clear(comboKeyDown, 0, comboKeyDown.Length);
                    FlushComboStats();
                    Kick();
                }
            }
            else if (comboFinishLeft > 0f)
            {
                comboFinishLeft = Math.Max(0f, comboFinishLeft - dt);
                if (comboFinishLeft <= 0.01f)
                {
                    comboFinishLeft = 0f;
                    comboWpm = 0;
                    comboPeakWpm = 0;
                }
            }

            if (sprintActive)
            {
                sprintLeft -= dt;
                if (sprintLeft <= 0f)
                {
                    sprintLeft = 0f;
                    sprintActive = false;
                    sprintDoneLeft = 3.2f;
                    sprintFinalWpm = (int)Math.Round((sprintChars / 5.0) / 0.5);
                    bool newRec = sprintFinalWpm > comboSprintBestWpm && sprintFinalWpm > 0;
                    if (newRec)
                    {
                        comboSprintBestWpm = sprintFinalWpm;
                        comboStatsDirty = true;
                        PlayComboPbFanfare();
                    }
                    if (newRec || sprintFinalWpm >= 40)
                    {
                        SpawnComboConfetti(30, OnSide ? SideW * 0.5f : 176f, OnSide ? 42f : 24f, OnSide ? 54f : 320f, newRec, true);
                        if (!Anim.Reduced) celebrateUtc = DateTime.UtcNow;
                    }
                    AddComboXp(Math.Max(20, sprintFinalWpm));
                    if (sprintFinalWpm >= 80) UnlockComboBadge("sprint_pro");
                    SyncComboHook();
                    FlushComboStats();
                    Kick();
                }
            }
            else if (sprintDoneLeft > 0f)
            {
                sprintDoneLeft = Math.Max(0f, sprintDoneLeft - dt);
            }
        }

        bool ComboAnimating()
        {
            return comboActive || comboFinishLeft > 0.01f || comboBrokenLeft > 0.01f || comboSparks.Count > 0 || comboConfetti.Count > 0 || comboShards.Count > 0 || comboCallouts.Count > 0 || comboGoldFlash > 0.01f || comboShieldCrack > 0.01f || comboEnterSmash > 0.01f || sprintActive || sprintDoneLeft > 0.01f || !comboPop.Settled;
        }

        float ComboWidth()
        {
            if (sprintActive || sprintDoneLeft > 0.01f) return 352f;
            int shown = comboActive ? comboCount : comboLastRun;
            int tier = ComboTierFor(shown);
            bool broken = comboBrokenLeft > 0.01f;
            string rank = comboActive ? ComboRankLabel(tier) : (broken ? "BROKEN!" : "MAX COMBO");
            string sub = comboActive
                ? ComboRankSubtitle(tier) + " · " + comboWpm + " WPM"
                : (broken
                    ? Lang.T("COMBO BROKEN!")
                    : (ComboRpgOn ? Lang.F("Lv.{0} · {1} (+{2} XP)", ComboLevel, ComboLevelTitle, comboLastRunXp) : Lang.F("Selesai! · Puncak {0} WPM", Math.Max(comboWpm, comboPeakWpm))));
            float rankW = (p != null && p.G != null ? p.Measure(rank, Ink.Semi(10.5f)) : rank.Length * 7.2f) + 20f;
            float subW = p != null && p.G != null ? p.Measure(sub, Ink.Small(11f)) : sub.Length * 6.2f;
            float midW = Math.Max(rankW + 46f, subW + 8f);
            float numW = shown >= 1000 ? 96f : shown >= 100 ? 86f : 74f;
            return Math.Max(326f, Math.Min(416f, numW + midW + 78f));
        }

        float ComboHeight()
        {
            return 48f;
        }

        string DescribeCombo()
        {
            int shown = comboActive ? comboCount : comboLastRun;
            int tier = ComboTierFor(shown);
            return ComboRankLabel(tier) + " " + shown + "x, " + comboWpm + " WPM";
        }

        void DrawCombo(float w, float h, DateTime now)
        {
            if (sprintActive || sprintDoneLeft > 0.01f)
            {
                DrawTypingSprint(w, h);
                return;
            }
            int shown = comboActive ? comboCount : comboLastRun;
            int tier = ComboTierFor(shown);
            Color tc = comboBrokenLeft > 0.01f ? Color.FromArgb(255, 255, 70, 85) : ComboTierColor(tier, clock.Elapsed.TotalSeconds);
            Color tcInk = p.T.IsDark ? tc : EnforceContrast(tc, p.T.Bg, 3.5);
            float pop = Math.Max(0f, comboPop.Value);
            float shakeX = Anim.Reduced ? 0f : comboShake.Value;
            float cy = h / 2f - 1f;

            // 1. Ambient arcade glow on left & right wings
            float glowAlpha = Math.Min(0.42f, 0.14f + tier * 0.04f + comboRankFlash * 0.22f) * p.Alpha;
            float gw = Math.Max(4f, w - 4f), gh = Math.Max(4f, h - 4f);
            var glowRect = new RectangleF(2, 2, gw, gh);
            using (var lg = new LinearGradientBrush(
                new PointF(0, 0), new PointF(Math.Max(8f, w), 0),
                Ink.A(tc, glowAlpha),
                Ink.A(tc, glowAlpha * 0.35f)))
            {
                p.FillRound(glowRect, gh / 2f, lg);
            }

            // 2. Expanding shockwave ring on rank-up / milestone
            if (!Anim.Reduced && comboRing.Value > 0.01f && comboRing.Value < 0.99f)
            {
                float rt = Ease.Clamp01(comboRing.Value);
                float rw = Math.Max(12f, 48f + rt * (w - 56f));
                float rh = Math.Max(8f, 24f + rt * (h - 26f));
                var rr = new RectangleF(48f - rw * 0.25f, cy - rh / 2f, rw, rh);
                p.StrokeRound(rr, rh / 2f, Ink.A(tc, (1f - rt) * 0.55f), 1.8f);
            }

            // 3. Particle sparks (circles, 4-point stars, diamonds)
            if (!Anim.Reduced && comboRing2 > 0.01f && comboRing2 < 0.99f)
            {
                float rt2 = Ease.Clamp01(comboRing2);
                float rw2 = Math.Max(16f, 56f + rt2 * (w - 40f));
                float rh2 = Math.Max(10f, 26f + rt2 * (h - 18f));
                var rr2 = new RectangleF(48f - rw2 * 0.25f, cy - rh2 / 2f, rw2, rh2);
                p.StrokeRound(rr2, rh2 / 2f, Ink.A(Color.FromArgb(255, 255, 200, 70), (1f - rt2) * 0.65f), 2.2f);
            }
            if (!Anim.Reduced && comboShards.Count > 0)
            {
                for (int i = 0; i < comboShards.Count; i++)
                {
                    var sh = comboShards[i];
                    float st = Ease.Clamp01(sh.Life / Math.Max(0.01f, sh.MaxLife));
                    float sa = (1f - st * st) * 0.9f;
                    if (sa <= 0.02f) continue;
                    p.FillRound(new RectangleF(sh.X - sh.W * 0.5f, sh.Y - sh.H * 0.5f, sh.W, sh.H), 1f, Ink.A(sh.Color, sa));
                }
            }
            DrawComboConfetti();
            if (!Anim.Reduced && comboSparks.Count > 0)
            {
                for (int i = 0; i < comboSparks.Count; i++)
                {
                    var s = comboSparks[i];
                    float t = Ease.Clamp01(s.Life / Math.Max(0.01f, s.MaxLife));
                    float a = (1f - t * t) * 0.9f;
                    float r = s.Size * (1f - t * 0.4f);
                    if (r <= 0.3f || a <= 0.02f) continue;
                    Color sc = Ink.A(s.Color, a);
                    if (s.Kind == 1)
                        DrawComboStar(s.X, s.Y, r * 1.45f, s.Angle, sc);
                    else if (s.Kind == 2)
                        DrawComboDiamond(s.X, s.Y, r * 1.25f, sc);
                    else
                        p.Circle(s.X, s.Y, r, sc);
                }
            }

            // 4. Left Section: Combo Hit Counter ("42x")
            float leftW = shown >= 1000 ? 94f : shown >= 100 ? 84f : 74f;
            float numCx = 14f + leftW * 0.5f + shakeX;
            float fontPt = Math.Min(21f, (shown >= 100 ? 15.5f : 17f) + pop * 3.2f);
            string numText = shown + "x";

            // Subtle pill capsule behind the combo counter
            float pillH = Math.Max(8f, h - 16f);
            var numPill = new RectangleF(10f, Math.Max(2f, (h - pillH) * 0.5f - 1f), leftW, pillH);
            p.FillRound(numPill, pillH / 2f, Ink.A(tc, 0.16f + Math.Min(0.18f, pop * 0.15f)));
            p.StrokeRound(numPill, pillH / 2f, Ink.A(tc, 0.38f + Math.Min(0.35f, pop * 0.3f)), 1f);

            // Glow shadow + crisp number
            if (tier >= 2)
                p.TextCenter(numText, Ink.Semi(fontPt), Ink.A(tcInk, 0.35f), numCx + 0.8f, cy + 0.8f);
            Color numColor = tier >= 3 ? Ink.Mix(p.T.Text, tcInk, 0.35f) : p.T.Text;
            p.TextCenter(numText, Ink.Semi(fontPt), numColor, numCx, cy - 0.5f);
            if (ComboFeverActive)
            {
                double sec = clock.Elapsed.TotalSeconds;
                for (int f = 0; f < 3; f++)
                {
                    float pulse = Anim.Reduced ? 0.5f : (0.5f + 0.5f * (float)Math.Sin(sec * 9.0 + f * 2.1));
                    float fw = 4f + pulse * 4f;
                    float fh = 8f + pulse * 7f;
                    float fy = numPill.Y + 4f + f * 7f - fh * 0.3f;
                    Color fc = Ink.A(tc, 0.35f + pulse * 0.35f);
                    p.FillRound(new RectangleF(numPill.X - fw * 0.6f, fy, fw, fh), fw * 0.5f, fc);
                    p.FillRound(new RectangleF(numPill.Right - fw * 0.4f, fy, fw, fh), fw * 0.5f, fc);
                }
            }
            if (comboGoldFlash > 0.01f)
                p.FillRound(numPill, pillH / 2f, Ink.A(Color.FromArgb(255, 255, 214, 10), comboGoldFlash * 0.35f));
            if (comboShieldCrack > 0.01f)
                p.FillRound(numPill, pillH / 2f, Ink.A(Color.FromArgb(255, 255, 80, 90), comboShieldCrack * 0.35f));
            if (ComboPenaltyMode == "shield" && comboActive)
            {
                for (int s = 0; s < 2; s++)
                {
                    Color sc = s < comboShields ? Color.FromArgb(255, 90, 220, 255) : Ink.A(p.T.Text, 0.16f);
                    p.Circle(numPill.Right - 6f - s * 7f, numPill.Y + 5f, 2.2f, sc);
                }
            }

            // 5. Center Section: Rank Badge Pill + Subtitle & WPM
            float midX = 16f + leftW;
            float rightReserve = 66f;
            float availMid = Math.Max(80f, w - midX - rightReserve);

            string rankText = comboActive ? ComboRankLabel(tier) : (comboBrokenLeft > 0.01f ? "BROKEN!" : "MAX COMBO");
            var rankFont = Ink.Semi(9.5f);
            float badgeW = p.Measure(rankText, rankFont) + 14f;
            var badgeRect = new RectangleF(midX, 7.5f, badgeW, 16.5f);
            p.FillRound(badgeRect, 8.2f, tc);
            Color onBadge = Contrast(tc, Color.Black) >= Contrast(tc, Color.White) ? Color.FromArgb(255, 16, 18, 22) : Color.White;
            p.TextCenter(rankText, rankFont, onBadge, badgeRect.X + badgeRect.Width / 2f, badgeRect.Y + badgeRect.Height / 2f);

            // Secondary flame/streak tag next to the rank badge
            if (ComboFeverActive)
            {
                string multTag = tier >= 6 ? "🔥 ×4" : "🔥 ×2";
                p.Text(multTag, Ink.Semi(9f), tcInk, badgeRect.Right + 6f, badgeRect.Y + badgeRect.Height / 2f, Math.Max(20f, availMid - badgeW - 6f), StringAlignment.Near);
            }
            else if (comboActive && comboBest > shown && comboBest >= 10)
            {
                string bestTag = Lang.F("TERBAIK {0}x", comboBest);
                p.Text(bestTag, Ink.Semi(8.5f), p.T.Sub, badgeRect.Right + 6f, badgeRect.Y + badgeRect.Height / 2f, Math.Max(20f, availMid - badgeW - 6f), StringAlignment.Near);
            }
            else if (comboActive && tier >= 3)
            {
                p.Text("🔥 STREAK", Ink.Semi(9f), tcInk, badgeRect.Right + 6f, badgeRect.Y + badgeRect.Height / 2f, Math.Max(20f, availMid - badgeW - 6f), StringAlignment.Near);
            }

            string subText = comboBrokenLeft > 0.01f
                ? Lang.T("COMBO BROKEN!")
                : comboActive
                    ? ComboRankSubtitle(tier) + " · " + comboWpm + " WPM"
                    : (ComboRpgOn ? Lang.F("Lv.{0} · {1} (+{2} XP)", ComboLevel, ComboLevelTitle, comboLastRunXp) : Lang.F("Selesai! · Puncak {0} WPM", Math.Max(comboWpm, comboPeakWpm)));
            p.Text(subText, Ink.Small(11f), comboBrokenLeft > 0.01f ? Color.FromArgb(255, 255, 90, 95) : p.T.Sub, midX, h - 14.5f, availMid, StringAlignment.Near);

            // 6. Floating Callouts ("NICE!", "FAST!", "CRIT!")
            if (!Anim.Reduced && comboCallouts.Count > 0)
            {
                for (int i = 0; i < comboCallouts.Count; i++)
                {
                    var co = comboCallouts[i];
                    float ct = Ease.Clamp01(co.Life / Math.Max(0.01f, co.MaxLife));
                    float ca = 1f - ct * ct;
                    Color coInk = p.T.IsDark ? co.Color : EnforceContrast(co.Color, p.T.Bg, 3.5);
                    p.TextCenter(co.Text, Ink.Semi(9f), Ink.A(coInk, ca), co.X, co.Y);
                }
            }

            // 7. Right Section: Tactile Keycap Hit Indicator
            float capW = 44f;
            float capH = 26f;
            float capPop = pop * 2.2f + comboEnterSmash * 4.5f;
            var capRect = new RectangleF(w - capW - 12f - capPop * 0.5f, cy - capH / 2f - capPop * 0.5f, capW + capPop, capH + capPop);
            p.FillRound(capRect, 8f, Ink.A(tc, comboActive ? 0.22f : 0.12f));
            p.StrokeRound(capRect, 8f, Ink.A(tc, comboActive ? 0.65f : 0.3f), 1.2f);
            string keyText = comboActive && comboLastKey.Length > 0 ? comboLastKey : "⚡";
            p.TextCenter(keyText, Ink.Semi(10.5f), p.T.Text, capRect.X + capRect.Width / 2f, capRect.Y + capRect.Height / 2f);

            // 8. Bottom Combo Timer Drain Bar
            float frac = comboActive ? ComboDrainFraction() : (comboFinishLeft > 0.01f ? (comboFinishLeft / ComboFinishHoldSec) : 0f);
            if (!comboActive && comboFinishLeft > 0.01f && ComboRpgOn)
            {
                float xpBarX = 16f, xpBarW = Math.Max(8f, w - 32f), xpBarY = h - 4.2f;
                p.FillRound(new RectangleF(xpBarX, xpBarY, xpBarW, 2.4f), 1.2f, Ink.A(p.T.Text, 0.12f));
                float xpFill = Math.Max(4f, xpBarW * Ease.Clamp01(ComboLevelProgress));
                p.FillRound(new RectangleF(xpBarX, xpBarY, xpFill, 2.4f), 1.2f, Color.FromArgb(255, 255, 214, 10));
            }
            else if (frac > 0.005f)
            {
                float barX = 16f, barW = Math.Max(8f, w - 32f), barY = h - 4.2f;
                p.FillRound(new RectangleF(barX, barY, barW, 2.4f), 1.2f, Ink.A(p.T.Text, 0.12f));
                float fillW = Math.Max(4f, barW * Ease.Clamp01(frac));
                p.FillRound(new RectangleF(barX, barY, fillW, 2.4f), 1.2f, tc);
                if (comboActive && !Anim.Reduced)
                    p.Circle(barX + fillW, barY + 1.2f, 2.6f, p.T.Text);
            }
        }

        void DrawTypingSprint(float w, float h)
        {
            Color sc = Color.FromArgb(255, 50, 173, 230);
            Color scInk = p.T.IsDark ? sc : EnforceContrast(sc, p.T.Bg, 3.5);
            float cy = h / 2f - 1f;
            if (sprintActive)
            {
                double elapsed = Math.Max(1.0, 30.0 - sprintLeft);
                int liveWpm = (int)Math.Round((sprintChars / 5.0) / (elapsed / 60.0));
                var pill = new RectangleF(10f, 8f, 74f, h - 18f);
                p.FillRound(pill, pill.Height / 2f, Ink.A(sc, 0.18f));
                p.StrokeRound(pill, pill.Height / 2f, Ink.A(sc, 0.5f), 1f);
                p.TextCenter(sprintLeft.ToString("0.0") + "s", Ink.Semi(15f), scInk, pill.X + pill.Width / 2f, cy - 0.5f);
                p.Text(Lang.T("SPRINT 30s"), Ink.Semi(9.5f), scInk, 94f, 14f, 120f, StringAlignment.Near);
                p.Text(liveWpm + " WPM · " + sprintChars + " " + Lang.T("huruf"), Ink.Small(11f), p.T.Sub, 94f, h - 15f, 165f, StringAlignment.Near);
                var stopRect = new RectangleF(w - 58f, cy - 12f, 46f, 24f);
                p.FillRound(stopRect, 12f, Ink.A(Color.FromArgb(255, 255, 80, 90), 0.18f));
                p.StrokeRound(stopRect, 12f, Ink.A(Color.FromArgb(255, 255, 80, 90), 0.55f), 1f);
                p.TextCenter(Lang.T("Stop"), Ink.Semi(9.5f), p.T.Text, stopRect.X + stopRect.Width / 2f, stopRect.Y + stopRect.Height / 2f);
                AddHit(stopRect, "comboSprintStop", StopTypingSprint);
                float frac = Ease.Clamp01(sprintLeft / 30f);
                p.FillRound(new RectangleF(16f, h - 4.2f, Math.Max(8f, w - 32f), 2.4f), 1.2f, Ink.A(p.T.Text, 0.12f));
                p.FillRound(new RectangleF(16f, h - 4.2f, Math.Max(4f, (w - 32f) * frac), 2.4f), 1.2f, sc);
            }
            else
            {
                p.TextCenter(sprintFinalWpm + " WPM", Ink.Semi(16f), scInk, 60f, cy);
                p.Text(Lang.F("Sprint Selesai! · Rekor {0} WPM", comboSprintBestWpm), Ink.Small(11f), p.T.Text, 114f, cy, w - 126f, StringAlignment.Near);
            }
                DrawComboConfetti();
        }

        // Upright rendering when the island sits on the left or right screen edge
        void SideCombo(float w, float h, DateTime now)
        {
            if (sprintActive || sprintDoneLeft > 0.01f)
            {
                float scx = w / 2f;
                p.Circle(scx, 18f, 11f, Ink.A(Color.FromArgb(255, 50, 173, 230), 0.24f));
                p.Icon('\uE916', 11f, Color.FromArgb(255, 50, 173, 230), scx, 18f);
                p.TextCenter(sprintActive ? sprintLeft.ToString("0.0") + "s" : (sprintFinalWpm + ""), Ink.Semi(11f), p.T.Text, scx, 42f);
                p.TextCenter(sprintActive ? "SPRINT" : "WPM", Ink.Semi(7.5f), p.T.Sub, scx, 58f);
                if (sprintActive)
                {
                    AddHit(new RectangleF(0, 0, w, h), "comboSprintStop", StopTypingSprint);
                    float barW = Math.Max(6f, w - 12f);
                    p.FillRound(new RectangleF(6f, h - 8f, barW, 3f), 1.5f, Ink.A(p.T.Text, 0.14f));
                    p.FillRound(new RectangleF(6f, h - 8f, Math.Max(3f, barW * Ease.Clamp01(sprintLeft / 30f)), 3f), 1.5f, Color.FromArgb(255, 50, 173, 230));
                }
                DrawComboConfetti();
                return;
            }
            int shown = comboActive ? comboCount : comboLastRun;
            int tier = ComboTierFor(shown);
            Color tc = comboBrokenLeft > 0.01f ? Color.FromArgb(255, 255, 70, 85) : ComboTierColor(tier, clock.Elapsed.TotalSeconds);
            Color tcInk = p.T.IsDark ? tc : EnforceContrast(tc, p.T.Bg, 3.5);
            if (ComboFeverActive)
            {
                float pulse = Anim.Reduced ? 0.4f : (0.35f + 0.35f * (float)Math.Sin(clock.Elapsed.TotalSeconds * 8.0));
                p.StrokeRound(new RectangleF(2f, 2f, w - 4f, h - 4f), 10f, Ink.A(tc, pulse), 2.0f);
            }
            float pop = Math.Max(0f, comboPop.Value);
            float cx = w / 2f;

            if (!Anim.Reduced && comboShards.Count > 0)
            {
                for (int i = 0; i < comboShards.Count; i++)
                {
                    var sh = comboShards[i];
                    float st = Ease.Clamp01(sh.Life / Math.Max(0.01f, sh.MaxLife));
                    float sa = (1f - st * st) * 0.9f;
                    if (sa <= 0.02f) continue;
                    p.FillRound(new RectangleF(sh.X - sh.W * 0.5f, sh.Y - sh.H * 0.5f, sh.W, sh.H), 1f, Ink.A(sh.Color, sa));
                }
            }
            DrawComboConfetti();
            if (!Anim.Reduced && comboSparks.Count > 0)
            {
                for (int i = 0; i < comboSparks.Count; i++)
                {
                    var s = comboSparks[i];
                    float t = Ease.Clamp01(s.Life / Math.Max(0.01f, s.MaxLife));
                    float a = (1f - t * t) * 0.85f;
                    float r = s.Size * (1f - t * 0.4f);
                    if (r <= 0.3f || a <= 0.02f) continue;
                    p.Circle(s.X, s.Y, r, Ink.A(s.Color, a));
                }
            }

            p.Circle(cx, 18f, 11f + pop * 1.4f, Ink.A(tc, 0.22f));
            p.Icon('\uE945', 11f, tcInk, cx, 18f);
            p.TextCenter(shown + "x", Ink.Semi(Math.Min(13f, 11f + pop * 1.6f)), p.T.Text, cx, 42f);
            if (comboBrokenLeft > 0.01f)
            {
                p.TextCenter("BROKEN", Ink.Semi(7.5f), tcInk, cx, 64f);
            }
            else
            {
                int wpmShown = comboActive ? comboWpm : Math.Max(comboWpm, comboPeakWpm);
                p.TextCenter(wpmShown + "", Ink.Small(9.5f), p.T.Sub, cx, 58f);
                p.TextCenter("WPM", Ink.Semi(7.5f), tcInk, cx, 70f);
            }

            float frac = comboActive ? ComboDrainFraction() : (comboFinishLeft / ComboFinishHoldSec);
            if (frac > 0.01f)
            {
                float barW = Math.Max(6f, w - 12f);
                p.FillRound(new RectangleF(6f, h - 8f, barW, 3f), 1.5f, Ink.A(p.T.Text, 0.14f));
                p.FillRound(new RectangleF(6f, h - 8f, Math.Max(3f, barW * Ease.Clamp01(frac)), 3f), 1.5f, tc);
            }
        }

        void DrawComboStar(float cx, float cy, float r, float angle, Color c)
        {
            var pts = new PointF[8];
            for (int i = 0; i < 8; i++)
            {
                double a = angle + i * Math.PI / 4.0;
                float rad = (i & 1) == 0 ? r : r * 0.36f;
                pts[i] = new PointF(cx + (float)Math.Cos(a) * rad, cy + (float)Math.Sin(a) * rad);
            }
            g.FillPolygon(p.B(c), pts);
        }

        void DrawComboDiamond(float cx, float cy, float r, Color c)
        {
            var pts = new[]
            {
                new PointF(cx, cy - r),
                new PointF(cx + r * 0.75f, cy),
                new PointF(cx, cy + r),
                new PointF(cx - r * 0.75f, cy)
            };
            g.FillPolygon(p.B(c), pts);
        }
    }
}
