using System;
using System.Collections.Generic;
using System.Drawing;
using System.Text;
using System.Windows.Forms;

namespace Tepi
{
    public sealed class PriorityItem
    {
        public string Title;
        public bool Done;
    }

    partial class Island
    {
        readonly List<PriorityItem> priorities = new List<PriorityItem>();
        string prioritiesDate = "";
        bool prioritiesLoaded;

        static string SanitizePriorityTitle(string title)
        {
            if (string.IsNullOrEmpty(title)) return "";
            return title.Replace('\r', ' ').Replace('\n', ' ').Replace('\t', ' ').Trim();
        }

        static string EscapePriorityField(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            return s.Replace("\\", "\\\\").Replace("|", "\\|").Replace(";", "\\;");
        }

        static List<string> SplitEscaped(string input, char sep)
        {
            var result = new List<string>();
            if (string.IsNullOrEmpty(input)) return result;
            var sb = new StringBuilder();
            bool esc = false;
            for (int i = 0; i < input.Length; i++)
            {
                char c = input[i];
                if (esc)
                {
                    sb.Append(c);
                    esc = false;
                }
                else if (c == '\\')
                {
                    sb.Append(c);
                    esc = true;
                }
                else if (c == sep)
                {
                    result.Add(sb.ToString());
                    sb.Length = 0;
                }
                else
                {
                    sb.Append(c);
                }
            }
            result.Add(sb.ToString());
            return result;
        }

        static string UnescapePriorityField(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length);
            bool esc = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (esc)
                {
                    sb.Append(c);
                    esc = false;
                }
                else if (c == '\\')
                {
                    esc = true;
                }
                else
                {
                    sb.Append(c);
                }
            }
            if (esc) sb.Append('\\');
            return sb.ToString();
        }

        void EnsurePrioritiesLoaded()
        {
            if (prioritiesLoaded) return;
            prioritiesLoaded = true;
            priorities.Clear();
            if (settings == null) return;

            prioritiesDate = settings.Get("priorities.date", "") ?? "";
            string raw = settings.Get("priorities.items", "") ?? "";
            if (raw.Length > 0)
            {
                var entries = SplitEscaped(raw, ';');
                for (int i = 0; i < entries.Count && priorities.Count < 3; i++)
                {
                    string entry = entries[i];
                    if (string.IsNullOrEmpty(entry)) continue;
                    var parts = SplitEscaped(entry, '|');
                    if (parts.Count < 2) continue;
                    bool done = parts[0] == "1";
                    string title = SanitizePriorityTitle(UnescapePriorityField(parts[1]));
                    if (title.Length > 0)
                        priorities.Add(new PriorityItem { Title = title, Done = done });
                }
            }

            string today = DateTime.Now.ToString("yyyy-MM-dd");
            if (prioritiesDate != today)
            {
                var carried = new List<PriorityItem>();
                for (int i = 0; i < priorities.Count && carried.Count < 3; i++)
                {
                    if (!priorities[i].Done)
                        carried.Add(priorities[i]);
                }
                priorities.Clear();
                priorities.AddRange(carried);
                prioritiesDate = today;
                SavePriorities();
            }
        }

        void SavePriorities()
        {
            if (settings == null) return;
            var encoded = new List<string>(priorities.Count);
            for (int i = 0; i < priorities.Count; i++)
            {
                var item = priorities[i];
                string t = EscapePriorityField(SanitizePriorityTitle(item.Title));
                if (t.Length == 0) continue;
                encoded.Add((item.Done ? "1" : "0") + "|" + t);
            }
            settings.Set("priorities.date", prioritiesDate ?? DateTime.Now.ToString("yyyy-MM-dd"));
            settings.Set("priorities.items", string.Join(";", encoded.ToArray()));
            settings.Save();
        }

        public int PriorityCount
        {
            get { EnsurePrioritiesLoaded(); return priorities.Count; }
        }

        public int PriorityDoneCount
        {
            get
            {
                EnsurePrioritiesLoaded();
                int c = 0;
                for (int i = 0; i < priorities.Count; i++)
                    if (priorities[i].Done) c++;
                return c;
            }
        }

        public bool PrioritiesAllDone
        {
            get { return PriorityCount > 0 && PriorityDoneCount == PriorityCount; }
        }

        public bool GetPriority(int index, out string title, out bool done)
        {
            EnsurePrioritiesLoaded();
            if (index < 0 || index >= priorities.Count)
            {
                title = "";
                done = false;
                return false;
            }
            title = priorities[index].Title;
            done = priorities[index].Done;
            return true;
        }

        public bool AddPriority(string title)
        {
            EnsurePrioritiesLoaded();
            string clean = SanitizePriorityTitle(title);
            if (clean.Length == 0 || priorities.Count >= 3) return false;
            priorities.Add(new PriorityItem { Title = clean, Done = false });
            SavePriorities();
            Kick();
            return true;
        }

        public bool TogglePriority(int index)
        {
            EnsurePrioritiesLoaded();
            if (index < 0 || index >= priorities.Count) return false;
            bool wasDone = priorities[index].Done;
            priorities[index].Done = !wasDone;
            if (!wasDone && priorities[index].Done)
            {
                RecordTaskDoneXp(35);
                if (PrioritiesAllDone)
                {
                    if (!Anim.Reduced) celebrateUtc = DateTime.UtcNow;
                    GrantProductivityXp(50);
                    UnlockComboBadge("priority_sweep");
                    ShowInfo('\uE73E', Lang.T("Prioritas hari ini tuntas!"), "+50 XP", true);
                }
            }
            SavePriorities();
            Kick();
            return true;
        }

        public void RemovePriority(int index)
        {
            EnsurePrioritiesLoaded();
            if (index < 0 || index >= priorities.Count) return;
            priorities.RemoveAt(index);
            SavePriorities();
            Kick();
        }

        public void StartFocusOnPriority(int index)
        {
            EnsurePrioritiesLoaded();
            if (index < 0 || index >= priorities.Count) return;
            SetFocusTask(priorities[index].Title);
            StartFocus(25);
        }

        public void PromptAddPriority()
        {
            EnsurePrioritiesLoaded();
            if (priorities.Count >= 3)
            {
                ShowInfo('\0', Lang.T("Maksimal 3 prioritas aktif"), "", true);
                return;
            }

            if (todos == null) todos = TodoFile.Load();
            var suggestions = new List<string>();
            if (todos != null)
            {
                for (int i = 0; i < todos.Count && suggestions.Count < 4; i++)
                {
                    if (!todos[i].Done && !string.IsNullOrEmpty(todos[i].Title))
                        suggestions.Add(todos[i].Title);
                }
            }
            if (tasks != null && suggestions.Count < 4)
            {
                for (int i = 0; i < tasks.Count && suggestions.Count < 4; i++)
                {
                    if (!string.IsNullOrEmpty(tasks[i].Title) && !suggestions.Contains(tasks[i].Title))
                        suggestions.Add(tasks[i].Title);
                }
            }

            using (var dlg = new PriorityPromptDialog(suggestions))
            {
                if (dlg.ShowDialog() == DialogResult.OK)
                {
                    AddPriority(dlg.EnteredTitle);
                }
            }
        }

        public void PickFocusTaskMenu()
        {
            EnsurePrioritiesLoaded();
            if (todos == null) todos = TodoFile.Load();

            var menu = new ContextMenuStrip();
            bool any = false;

            for (int i = 0; i < priorities.Count; i++)
            {
                if (priorities[i].Done) continue;
                string title = priorities[i].Title;
                var item = new ToolStripMenuItem(title);
                item.Click += delegate { SetFocusTask(title); };
                menu.Items.Add(item);
                any = true;
            }

            if (todos != null)
            {
                for (int i = 0; i < todos.Count; i++)
                {
                    if (todos[i].Done || string.IsNullOrEmpty(todos[i].Title)) continue;
                    string title = todos[i].Title;
                    var item = new ToolStripMenuItem(title);
                    item.Click += delegate { SetFocusTask(title); };
                    menu.Items.Add(item);
                    any = true;
                }
            }

            if (tasks != null)
            {
                for (int i = 0; i < tasks.Count; i++)
                {
                    if (string.IsNullOrEmpty(tasks[i].Title)) continue;
                    string title = tasks[i].Title;
                    var item = new ToolStripMenuItem(title);
                    item.Click += delegate { SetFocusTask(title); };
                    menu.Items.Add(item);
                    any = true;
                }
            }

            if (any) menu.Items.Add(new ToolStripSeparator());
            var addItem = new ToolStripMenuItem("+ " + Lang.T("Tambah Prioritas"));
            addItem.Click += delegate { BeginInvoke(new Action(PromptAddPriority)); };
            menu.Items.Add(addItem);
            var clearItem = new ToolStripMenuItem(Lang.T("Tanpa tugas"));
            clearItem.Click += delegate { ClearFocusTask(); };
            menu.Items.Add(clearItem);

            MenuLook.Apply(menu);
            menu.Show(System.Windows.Forms.Control.MousePosition);
        }

        sealed class PriorityPromptDialog : KitWindow
        {
            readonly KitText input = new KitText();
            readonly KitButton addBtn = new KitButton { Primary = true };
            readonly KitButton cancelBtn = new KitButton();
            public string EnteredTitle { get { return input.Text; } }

            public PriorityPromptDialog(List<string> suggestions)
            {
                Text = Lang.T("Tambah Prioritas");
                FormBorderStyle = FormBorderStyle.FixedDialog;
                MaximizeBox = false;
                MinimizeBox = false;
                StartPosition = FormStartPosition.CenterScreen;
                ShowInTaskbar = false;
                TopMost = true;

                int w = 380;
                int y = 18;

                var lbl = new Label
                {
                    Text = Lang.T("Fokus utama hari ini:"),
                    Location = new Point(20, y),
                    Size = new Size(w - 40, 20),
                    Font = Ink.Text(13f),
                    ForeColor = KitInk.Text,
                    BackColor = KitInk.Window
                };
                Controls.Add(lbl);
                y += 24;

                input.Location = new Point(20, y);
                input.Size = new Size(w - 40, 26);
                input.Font = Ink.Text(13f);
                input.BackColor = KitInk.Group;
                input.ForeColor = KitInk.Text;
                Controls.Add(input);
                y += 34;

                if (suggestions != null && suggestions.Count > 0)
                {
                    int cx = 20;
                    for (int i = 0; i < suggestions.Count; i++)
                    {
                        string s = suggestions[i];
                        var chip = new KitButton
                        {
                            Text = s.Length > 24 ? s.Substring(0, 22) + "…" : s,
                            Location = new Point(cx, y),
                            Size = new Size((w - 48) / 2, 26),
                            Font = Ink.Small(12f)
                        };
                        chip.Click += delegate
                        {
                            input.Text = s;
                            DialogResult = DialogResult.OK;
                            Close();
                        };
                        Controls.Add(chip);
                        if (i % 2 == 0)
                        {
                            cx += (w - 48) / 2 + 8;
                        }
                        else
                        {
                            cx = 20;
                            y += 32;
                        }
                    }
                    if (suggestions.Count % 2 == 1) y += 32;
                    y += 6;
                }

                addBtn.Text = Lang.T("Tambah");
                addBtn.Size = new Size(88, 30);
                addBtn.Location = new Point(w - 20 - 88 - 8 - 80, y);
                addBtn.Font = Ink.Text(12.5f);
                addBtn.Click += delegate
                {
                    if (input.Text.Trim().Length == 0) return;
                    DialogResult = DialogResult.OK;
                    Close();
                };
                Controls.Add(addBtn);

                cancelBtn.Text = Lang.T("Batal");
                cancelBtn.Size = new Size(80, 30);
                cancelBtn.Location = new Point(w - 20 - 80, y);
                cancelBtn.Font = Ink.Text(12.5f);
                cancelBtn.Click += delegate
                {
                    DialogResult = DialogResult.Cancel;
                    Close();
                };
                Controls.Add(cancelBtn);

                AcceptButton = addBtn;
                CancelButton = cancelBtn;
                ClientSize = new Size(w, y + 48);
            }
        }
    }
}
