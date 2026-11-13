using System;
using System.Collections.Generic;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Tepi
{
    // Clipboard history: text only, memory only; images go to Shots
    partial class Island
    {
        class ClipItem { public string Text; public DateTime Utc; }

        const int ClipMax = 25, ClipChars = 100000;
        const float ClipRowH = 50;
        readonly List<ClipItem> clips = new List<ClipItem>();
        readonly Spring clipScroll = new Spring(0, 300, 34, 0.2f);
        readonly System.Windows.Forms.Timer clipRetry = new System.Windows.Forms.Timer { Interval = 120 };
        bool clipListening;

        [DllImport("user32.dll", SetLastError = true)] static extern bool AddClipboardFormatListener(IntPtr hwnd);
        [DllImport("user32.dll", SetLastError = true)] static extern bool RemoveClipboardFormatListener(IntPtr hwnd);

        bool ClipsOn { get { return settings.GetBool("clipboard", false); } }

        void ApplyClips()
        {
            bool want = ClipsOn || ShotsOn || ScreenTextArmed;
            if (!ClipsOn) clips.Clear();
            if (want == clipListening) return;
            if (want) clipListening = AddClipboardFormatListener(Handle);
            else { RemoveClipboardFormatListener(Handle); clipListening = false; clipRetry.Stop(); }
            clipRetry.Tick -= ClipRetryTick;
            clipRetry.Tick += ClipRetryTick;
        }

        void ClipRetryTick(object sender, EventArgs e) { clipRetry.Stop(); if (clipListening) ReadClipboard(false); }

        // WM_CLIPBOARDUPDATE
        void OnClipboardUpdate()
        {
            if (!clipListening) return;
            ReadClipboard(true);
            if (expanded && page == PageShelf) ShelfClipCheck();
        }

        void ReadClipboard(bool retry)
        {
            // Tepi putting the old clipboard back
            if (DateTime.UtcNow < clipQuietUtc) return;
            string text;
            try
            {
                var data = System.Windows.Forms.Clipboard.GetDataObject();
                if (data == null) return;
                // Password managers flag secrets this way
                if (data.GetDataPresent("ExcludeClipboardContentFromMonitorProcessing") || data.GetDataPresent("Clipboard Viewer Ignore")) return;
                if (data.GetDataPresent("CanIncludeInClipboardHistory"))
                {
                    var flag = data.GetData("CanIncludeInClipboardHistory") as System.IO.MemoryStream;
                    if (flag != null && flag.Length >= 4 && BitConverter.ToInt32(flag.ToArray(), 0) == 0) return;
                }
                // Picture without text: preview it
                if (data.GetDataPresent(DataFormats.Bitmap) && !data.GetDataPresent(DataFormats.UnicodeText))
                {
                    if (TakeScreenText(data)) return;
                    if (ShotsOn) OnClipImage(data);
                    return;
                }
                if (!ClipsOn || !data.GetDataPresent(DataFormats.UnicodeText)) return;
                text = data.GetData(DataFormats.UnicodeText) as string;
            }
            catch (ExternalException)
            {
                // Another app holds the clipboard
                if (retry) clipRetry.Start();
                return;
            }
            if (string.IsNullOrWhiteSpace(text)) return;
            if (text.Length > ClipChars) text = text.Substring(0, ClipChars);
            clips.RemoveAll(c => c.Text == text);
            clips.Insert(0, new ClipItem { Text = text, Utc = DateTime.UtcNow });
            if (clips.Count > ClipMax) clips.RemoveRange(ClipMax, clips.Count - ClipMax);
            if (expanded && page == PageShelf && shelfSeg == 1) Kick();
        }

        void CopyClip(ClipItem c)
        {
            try { System.Windows.Forms.Clipboard.SetText(c.Text); }
            catch (ExternalException ex) { Log.Write("clipboard set: " + ex.Message); return; }
            ShowInfo('', Lang.T("Disalin lagi"), Preview(c.Text, 60), true);
        }

        static string Preview(string text, int max)
        {
            var sb = new System.Text.StringBuilder();
            bool space = false;
            foreach (char ch in text)
            {
                if (char.IsWhiteSpace(ch)) { space = sb.Length > 0; continue; }
                if (space) { sb.Append(' '); space = false; }
                sb.Append(ch);
                if (sb.Length >= max) break;
            }
            return sb.ToString();
        }

        float ClipsHeight()
        {
            if (!ClipsOn || clips.Count == 0) return 252;
            return Clamp(PanelTop + 14 + clips.Count * ClipRowH, 150, 372);
        }

        void DrawClipsPage(float w, float h, DateTime now)
        {
            if (!ClipsOn)
            {
                EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Riwayat clipboard mati"), Lang.T("Teks yang disalin hanya disimpan di memori dan hilang saat Tepi ditutup"), Lang.T("Nyalakan"), "clipsOn", delegate { SetFlag("clipboard", true); }, PillKind.Primary);
                return;
            }
            if (clips.Count == 0)
            {
                EmptyState(new RectangleF(0, PanelTop, w, h - PanelTop), '', Lang.T("Belum ada yang disalin"), Lang.T("Teks yang kamu salin muncul di sini"));
                return;
            }
            var area = new RectangleF(10, PanelTop + 4, w - 20, h - PanelTop - 14);
            var st = g.Save();
            g.IntersectClip(area);
            float y = area.Y - clipScroll.Value, keep = p.Alpha;
            for (int i = 0; i < clips.Count; i++, y += ClipRowH)
            {
                float dy, a = RowIn(i, now, out dy);
                float ry = y + CollapseAt("clip", i) + dy;
                if (ry + ClipRowH < area.Top || ry > area.Bottom) continue;
                p.Alpha = keep * a;
                var c = clips[i];
                var row = new RectangleF(area.X + 4, ry + 2, area.Width - 8, ClipRowH - 4);
                string id = "clip" + c.Utc.Ticks, del = "clipDel" + c.Utc.Ticks;
                bool hover = Hover(id) || Hover(del);
                if (hover) p.FillRound(row, Ink.RadiusControl, p.T.Fill);
                float rcy = row.Y + row.Height / 2;
                float tw = hover ? row.Width - 62 : row.Width - 28;
                p.Text(Preview(c.Text, 140), Ink.Semi(12.5f), p.T.Text, row.X + 14, rcy - 8, tw, StringAlignment.Near);
                string meta = Lang.F("{0} karakter", c.Text.Length) + " · " + Fmt.Ago(c.Utc);
                p.Text(meta, Ink.Small(11f), p.T.Faint, row.X + 14, rcy + 9, tw, StringAlignment.Near);
                var x = new RectangleF(row.Right - 36, rcy - 14, 28, 28);
                if (hover)
                {
                    p.Circle(x.X + 14, x.Y + 14, 12, Hover(del) ? p.T.FillHover : p.T.Fill);
                    p.Cross(x.X + 14, x.Y + 14, 10, p.T.Sub);
                }
                var pick = c;
                var pickRow = row;
                int idx = i;
                if (row.Top >= area.Top && row.Bottom <= area.Bottom)
                {
                    AddHit(row, id, delegate
                    {
                        var tc = CanvasRect(new RectangleF(w / 2, 16, 0, 0));
                        VanishTo(new[] { CanvasRect(pickRow) }, new PointF(tc.X, tc.Y), false);
                        CopyClip(pick);
                    });
                    AddHit(x, del, delegate
                    {
                        Vanish(new[] { CanvasRect(pickRow) }, false);
                        Collapse("clip", idx, ClipRowH);
                        clips.Remove(pick);
                        Kick();
                    });
                }
            }
            p.Alpha = keep;
            g.Restore(st);
        }
    }
}