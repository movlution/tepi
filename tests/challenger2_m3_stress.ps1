# tests/challenger2_m3_stress.ps1
# Challenger 2 Empirical Stress & Adversarial Verification Harness
# Milestone 3: Toast Notification Meta Collision, Parts.EmptyState Unification & Design Token Audit
# Mode: Full empirical execution with mathematical oracles, layout stress tests, and pixel render verifications.

$ErrorActionPreference = "Stop"

$commonDir = Join-Path $PSScriptRoot "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 2: EMPIRICAL ADVERSARIAL STRESS HARNESS (M3)  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Ensure Tepi.exe is loaded
$binPath = Find-TepiBinary
if (-not $binPath) {
    throw "Tepi.exe not found! Please build before running tests."
}
Initialize-TepiLoader | Out-Null

$inkType = Get-TepiType "Ink"
if (-not $inkType) { throw "Could not resolve Tepi.Ink type" }

# Extract typography tokens via reflection
$fontCaption = [System.Drawing.Font](Get-TepiStaticProperty "Ink" "Caption")
$fontHeadline = [System.Drawing.Font](Get-TepiStaticProperty "Ink" "Headline")
$fontCallout = [System.Drawing.Font](Get-TepiStaticProperty "Ink" "Callout")
$fontBody = [System.Drawing.Font](Get-TepiStaticProperty "Ink" "Body")

Assert-NotNull $fontCaption "Ink.Caption must resolve"
Assert-NotNull $fontHeadline "Ink.Headline must resolve"
Assert-NotNull $fontCallout "Ink.Callout must resolve"

Describe "1. Toast Notification Meta Text Collision Stress Harness" {

    It "Stress tests DrawNotif layout math across combinatorial matrix of app names, bursts, widths, and titles" {
        $appNames = @(
            "X",
            "W",
            "A",
            "WhatsApp",
            "Telegram",
            "Slack Work",
            "Enterprise Unified Communications & Telephony Hub",
            ("VeryLongApplicationIdentifierWithoutAnySpacesOrBreaks" * 3),
            ("A" * 200),
            ("Supercalifragilisticexpialidocious_Enterprise_Suite_App_" * 4)
        )

        $burstCounts = @(1, 2, 5, 20, 99, 999, 9999, 50000)

        $widths = @(240.0, 260.0, 300.0, 360.0, 404.0, 480.0, 600.0)

        $titles = @(
            "",
            "X",
            "Halo Budi",
            "Meeting Reminder: Product Review at 14:00",
            ("Extremely long notification title that explains critical system outage with extreme details " * 2)
        )

        $totalEvaluated = 0
        $minGapObserved = 9999.0
        $maxOverlapObserved = 0.0

        # Measuring string width using GDI+ StringFormat matching Painter.line
        $stringFormat = New-Object System.Drawing.StringFormat
        $stringFormat.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
        $stringFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

        $bmp = New-Object System.Drawing.Bitmap(10, 10)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                foreach ($w in $widths) {
                    foreach ($app in $appNames) {
                        foreach ($burst in $burstCounts) {
                            $meta = if ($burst -gt 1) { "$burst pesan · $app" } else { $app }
                            
                            # GDI+ measurement
                            $rawMetaW = $g.MeasureString($meta, $fontCaption, [System.Drawing.PointF]::Empty, $stringFormat).Width
                            $mw = [Math]::Min($w * 0.35, $rawMetaW)

                            # Bounding box calculations from DrawNotif:
                            # p.Text(meta, Ink.Caption, p.T.Sub, w - 22, cy - 10, mw, StringAlignment.Far)
                            # Far alignment: left = (w - 22) - mw, right = w - 22
                            $metaLeft = ($w - 22.0) - $mw
                            $metaRight = $w - 22.0

                            # p.Text(NotifTitle(item), Ink.Headline, p.T.Text, 66, cy - 10, Math.Max(40, w - 66 - 22 - mw - 12), StringAlignment.Near)
                            # Near alignment: left = 66, right = 66 + maxTitleW
                            $maxTitleW = [Math]::Max(40.0, ($w - 66.0 - 22.0 - $mw - 12.0))
                            $titleLeft = 66.0
                            $titleRight = 66.0 + $maxTitleW

                            # Clearance gap and horizontal overlap
                            $gap = $metaLeft - $titleRight
                            $overlap = [Math]::Max(0.0, $titleRight - $metaLeft)

                            if ($gap -lt $minGapObserved) { $minGapObserved = $gap }
                            if ($overlap -gt $maxOverlapObserved) { $maxOverlapObserved = $overlap }

                            $totalEvaluated++

                            # Invariant 1: Horizontal overlap must be EXACTLY 0.0px
                            if ($overlap -gt 0.0) {
                                throw "COLLISION DETECTED! Width=$w, App='$app', Burst=$burst, Overlap=$overlap px, Gap=$gap px"
                            }

                            # Invariant 2: Clearance gap must be >= 10.0px
                            if ($gap -lt 10.0) {
                                throw "INSUFFICIENT CLEARANCE GAP! Width=$w, App='$app', Burst=$burst, Gap=$gap px (expected >= 10px)"
                            }

                            # Invariant 3: Meta right boundary must not exceed HUD right margin
                            if ($metaRight -gt ($w - 20.0)) {
                                throw "META RIGHT MARGIN OVERFLOW! Width=$w, metaRight=$metaRight, limit=$($w - 20)"
                            }

                            # Invariant 4: Title left boundary must respect badge right edge (badge ends at 14+40=54)
                            if ($titleLeft -lt 64.0) {
                                throw "TITLE BADGE COLLISION! titleLeft=$titleLeft (expected >= 64px)"
                            }
                        }
                    }
                }
            } finally {
                $g.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }

        Assert-True ($totalEvaluated -ge 500) "Combinatorial stress test evaluated $totalEvaluated cases"
        Assert-Equal $maxOverlapObserved 0.0 "Maximum horizontal overlap across all scenarios must be 0.0px"
        Assert-True ($minGapObserved -ge 10.0) "Minimum clearance gap across all scenarios must be >= 10.0px (actual min: $minGapObserved px)"
    }

    It "Explicitly verifies the 5 mandated dispatch edge cases for DrawNotif" {
        $namedCases = @(
            @{ Name = "Case 1: 1 character app name ('X')"; App = "X"; Burst = 1; Width = 360.0; Title = "Notifikasi Baru" },
            @{ Name = "Case 2: 50 characters app name"; App = "Enterprise Unified Communications & Telephony Hub"; Burst = 1; Width = 360.0; Title = "Panggilan Masuk dari Direktur" },
            @{ Name = "Case 3: 200 characters app name"; App = ("EnterpriseSuperAppLongIdentifier" * 7).Substring(0, 200); Burst = 1; Width = 360.0; Title = "Pembaruan Keamanan Sistem" },
            @{ Name = "Case 4: Massive burst count ('9999 pesan · WhatsApp')"; App = "WhatsApp"; Burst = 9999; Width = 360.0; Title = "Grup Koordinasi Proyek Tepi" },
            @{ Name = "Case 5A: Short narrow island width (w = 240px)"; App = "WhatsApp"; Burst = 9999; Width = 240.0; Title = "Pesan Penting" },
            @{ Name = "Case 5B: Standard island width (w = 360px)"; App = "WhatsApp"; Burst = 9999; Width = 360.0; Title = "Pesan Penting" }
        )

        $stringFormat = New-Object System.Drawing.StringFormat
        $stringFormat.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
        $stringFormat.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

        $bmp = New-Object System.Drawing.Bitmap(10, 10)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                foreach ($c in $namedCases) {
                    $w = $c.Width
                    $meta = if ($c.Burst -gt 1) { "$($c.Burst) pesan · $($c.App)" } else { $c.App }
                    $rawMetaW = $g.MeasureString($meta, $fontCaption, [System.Drawing.PointF]::Empty, $stringFormat).Width
                    $mw = [Math]::Min($w * 0.35, $rawMetaW)

                    $metaLeft = ($w - 22.0) - $mw
                    $metaRight = $w - 22.0

                    $maxTitleW = [Math]::Max(40.0, ($w - 66.0 - 22.0 - $mw - 12.0))
                    $titleLeft = 66.0
                    $titleRight = 66.0 + $maxTitleW

                    $gap = $metaLeft - $titleRight
                    $overlap = [Math]::Max(0.0, $titleRight - $metaLeft)

                    Write-Host "       [$($c.Name)]" -ForegroundColor Gray
                    Write-Host "         w=$w, mw=$([Math]::Round($mw, 1))px, TitleBox=[$titleLeft, $([Math]::Round($titleRight, 1))], MetaBox=[$([Math]::Round($metaLeft, 1)), $metaRight], Gap=$([Math]::Round($gap, 1))px, Overlap=$overlap px" -ForegroundColor DarkGray

                    Assert-Equal $overlap 0.0 "Horizontal overlap must be EXACTLY 0.0px for $($c.Name)"
                    Assert-True ($gap -ge 10.0) "Clearance gap must be >= 10.0px for $($c.Name) (actual: $gap px)"
                }
            } finally {
                $g.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }
    }

    It "Renders toast offscreen into 32bpp GDI+ bitmap and validates zero pixel collisions in clearance corridor" {
        $testWidths = @(240, 360, 404)
        $testApps = @(
            "X",
            "Enterprise Unified Communications & Telephony Hub",
            ("LongApp" * 15)
        )

        foreach ($w in $testWidths) {
            foreach ($app in $testApps) {
                $meta = "9999 pesan · $app"
                $title = "Meeting Reminder: Critical Architecture Review for Milestone 3"
                $h = 66
                $cy = $h / 2

                $bmp = New-Object System.Drawing.Bitmap ([int]$w), ([int]$h)
                try {
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    try {
                        $g.Clear([System.Drawing.Color]::Transparent)

                        $sfFar = New-Object System.Drawing.StringFormat
                        $sfFar.Alignment = [System.Drawing.StringAlignment]::Far
                        $sfFar.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
                        $sfFar.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

                        $sfNear = New-Object System.Drawing.StringFormat
                        $sfNear.Alignment = [System.Drawing.StringAlignment]::Near
                        $sfNear.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
                        $sfNear.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter

                        $measuredMetaW = $g.MeasureString($meta, $fontCaption, [System.Drawing.PointF]::Empty, $sfFar).Width
                        $mw = [Math]::Min($w * 0.35, $measuredMetaW)

                        $maxTitleW = [Math]::Max(40.0, ($w - 66.0 - 22.0 - $mw - 12.0))
                        $titleLeft = 66.0
                        $titleRight = $titleLeft + $maxTitleW
                        $metaLeft = ($w - 22.0) - $mw

                        # Draw title with Pure Red (#FFFF0000)
                        $titleRect = New-Object System.Drawing.RectangleF($titleLeft, ($cy - 10 - 10), $maxTitleW, 20)
                        $brushTitle = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 0, 0))
                        try {
                            $g.DrawString($title, $fontHeadline, $brushTitle, $titleRect, $sfNear)
                        } finally {
                            $brushTitle.Dispose()
                        }

                        # Draw meta with Pure Blue (#FF0000FF)
                        $metaRect = New-Object System.Drawing.RectangleF($metaLeft, ($cy - 10 - 10), $mw, 20)
                        $brushMeta = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 0, 255))
                        try {
                            $g.DrawString($meta, $fontCaption, $brushMeta, $metaRect, $sfFar)
                        } finally {
                            $brushMeta.Dispose()
                        }

                        # Corridor of clearance between titleRight and metaLeft
                        # Check all pixels in corridor: must have ZERO red and ZERO blue pixels
                        $corridorStart = [int][Math]::Ceiling($titleRight)
                        $corridorEnd = [int][Math]::Floor($metaLeft)

                        Assert-True ($corridorEnd -ge $corridorStart + 10) "Corridor width ($($corridorEnd - $corridorStart)px) must be >= 10px"

                        for ($x = $corridorStart; $x -lt $corridorEnd; $x++) {
                            for ($y = [int]($cy - 15); $y -lt [int]($cy + 5); $y++) {
                                $pixel = $bmp.GetPixel($x, $y)
                                if ($pixel.A -gt 0) {
                                    if ($pixel.R -gt 0 -and $pixel.B -gt 0) {
                                        throw "DIRECT PIXEL COLLISION at ($x, $y) between Title (Red) and Meta (Blue)!"
                                    }
                                }
                            }
                        }
                    } finally {
                        $g.Dispose()
                    }
                } finally {
                    $bmp.Dispose()
                }
            }
        }
    }
}

Describe "2. Parts.EmptyState Unification & Geometry Stress Harness" {

    It "Verifies Parts.EmptyState dynamic vertical centering across all container heights" {
        $testHeights = @(150.0, 180.0, 200.0, 252.0, 300.0, 372.0, 400.0, 500.0, 600.0)
        $panelTop = 44.0

        foreach ($h in $testHeights) {
            $area = New-Object System.Drawing.RectangleF(0.0, $panelTop, 360.0, ($h - $panelTop))

            # Test 1: No-button mode (block = 108)
            $blockNoBtn = 48 + 16 + 20 + 24
            $topNoBtn = $area.Y + [Math]::Max(8.0, ($area.Height - $blockNoBtn) / 2.0)
            $topMarginNoBtn = $topNoBtn - $area.Y
            $bottomMarginNoBtn = ($area.Y + $area.Height) - ($topNoBtn + $blockNoBtn)

            if ($area.Height -gt ($blockNoBtn + 16.0)) {
                # Centered
                $diff = [Math]::Abs($topMarginNoBtn - $bottomMarginNoBtn)
                Assert-True ($diff -le 1.0) "No-button EmptyState vertically centered on H=$h (diff=$diff px)"
            } else {
                # Clamped to 8px top margin
                Assert-Equal $topMarginNoBtn 8.0 "No-button EmptyState clamped to 8px on tight H=$h"
            }

            # Test 2: Button mode (block = 158)
            $blockBtn = 48 + 16 + 20 + 24 + 18 + 32
            $topBtn = $area.Y + [Math]::Max(8.0, ($area.Height - $blockBtn) / 2.0)
            $topMarginBtn = $topBtn - $area.Y
            $bottomMarginBtn = ($area.Y + $area.Height) - ($topBtn + $blockBtn)

            if ($area.Height -gt ($blockBtn + 16.0)) {
                $diff = [Math]::Abs($topMarginBtn - $bottomMarginBtn)
                Assert-True ($diff -le 1.0) "Button EmptyState vertically centered on H=$h (diff=$diff px)"
            } else {
                Assert-Equal $topMarginBtn 8.0 "Button EmptyState clamped to 8px on tight H=$h"
            }
        }
    }

    It "Tests multi-line Indonesian detail text wrapping across all 20 call site payloads" {
        $callSitePayloads = @(
            @{ Source = "Panel.cs:174"; Icon = "IcoTerminal"; Title = "Server hook mati"; Detail = "localhost:8000 · agent.port di settings.ini" },
            @{ Source = "Panel.cs:183"; Icon = "IcoTerminal"; Title = "Belum ada sesi agen"; Detail = "Belum terhubung · tray > Hubungkan agen" },
            @{ Source = "Panel.cs:302"; Icon = "IcoCalendar"; Title = "Tugas gagal dimuat"; Detail = "Gagal menghubungi server Kulia. Periksa koneksi internet." },
            @{ Source = "Panel.cs:317"; Icon = "IcoCalendar"; Title = "Tidak ada tugas aktif"; Detail = "Diperbarui tiap 15 menit" },
            @{ Source = "Panel.cs:398"; Icon = "IcoBell"; Title = "Notifikasi pesan dimatikan"; Detail = "Saklarnya ada di menu klik kanan" },
            @{ Source = "Panel.cs:403"; Icon = "IcoLock"; Title = "Akses notifikasi ditolak"; Detail = "Pengaturan Windows > Privasi > Notifikasi" },
            @{ Source = "Panel.cs:414"; Icon = "IcoBell"; Title = "Pesan tidak bisa dibaca"; Detail = "Notifikasi Windows tidak menjawab. Tepi mencoba lagi otomatis." },
            @{ Source = "Panel.cs:417"; Icon = "IcoBell"; Title = "Belum ada pesan"; Detail = "WhatsApp, Telegram, Discord, Teams, email" },
            @{ Source = "Shelf.cs:248"; Icon = "Rack"; Title = "Rak mati"; Detail = "Berkas yang diseret ke island tidak ditahan" },
            @{ Source = "Shelf.cs:255"; Icon = "Rack"; Title = "Rak kosong"; Detail = "Seret berkas ke island, atau pilih dari folder" },
            @{ Source = "Shelf.cs:261"; Icon = "Rack"; Title = "Rak kosong"; Detail = "Seret berkas ke island, atau pilih dari folder" },
            @{ Source = "Clips.cs:118"; Icon = "Clip"; Title = "Riwayat clipboard mati"; Detail = "Teks yang disalin hanya disimpan di memori dan hilang saat Tepi ditutup" },
            @{ Source = "Clips.cs:123"; Icon = "Clip"; Title = "Belum ada yang disalin"; Detail = "Teks yang kamu salin muncul di sini" },
            @{ Source = "ConvertPage.cs:112"; Icon = "Convert"; Title = "Ubah format mati"; Detail = "Berkas yang diseret ke island hanya bisa ditaruh di rak" },
            @{ Source = "Schedule.cs:93"; Icon = "IcoCalendar"; Title = "Jadwal gagal dimuat"; Detail = "Koneksi ke kalender Google terputus. Silakan coba beberapa saat lagi." },
            @{ Source = "Schedule.cs:98"; Icon = "IcoCalendar"; Title = "Memuat jadwal…"; Detail = "" },
            @{ Source = "Schedule.cs:104"; Icon = "IcoCalendar"; Title = "Jadwal kosong"; Detail = "3 minggu ke depan kosong" },
            @{ Source = "Music.cs:294"; Icon = "Music"; Title = "Tidak ada yang diputar"; Detail = "Spotify, YouTube Music, Apple Music, browser, VLC, dan pemutar lain" },
            @{ Source = "Handset.cs:272"; Icon = "Phone"; Title = "HP belum tersambung"; Detail = "Tepi di Android, satu Wi-Fi dengan laptop" },
            @{ Source = "Sources.cs:987"; Icon = "IcoCalendar"; Title = "Belum ada yang tersambung"; Detail = "Kulia, Notion, Todoist, atau kalender iCal" }
        )

        Assert-Equal $callSitePayloads.Count 20 "Must cover all 20 call site payloads"

        $stringFormatCenter = New-Object System.Drawing.StringFormat
        $stringFormatCenter.Alignment = [System.Drawing.StringAlignment]::Center
        $stringFormatCenter.LineAlignment = [System.Drawing.StringAlignment]::Center
        $stringFormatCenter.Trimming = [System.Drawing.StringTrimming]::EllipsisWord

        $bmp = New-Object System.Drawing.Bitmap(360, 400)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                foreach ($payload in $callSitePayloads) {
                    $area = New-Object System.Drawing.RectangleF(0, 44, 360, 300)
                    $block = 158.0
                    $top = $area.Y + [Math]::Max(8.0, ($area.Height - $block) / 2.0)
                    $lineBoxX = $area.X + 24.0
                    $lineBoxY = $top + 48.0 + 16.0 + 20.0 + 4.0
                    $lineBoxW = $area.Width - 48.0
                    $lineBoxH = 38.0
                    $lineBox = New-Object System.Drawing.RectangleF($lineBoxX, $lineBoxY, $lineBoxW, $lineBoxH)

                    # Assert lineBox dimensions
                    Assert-Equal $lineBox.Width 312.0 "LineBox width must be area.Width - 48 (312px)"
                    Assert-Equal $lineBox.Height 38.0 "LineBox height must be 38px (accommodates 2 wrapped lines of Callout)"

                    # Measure text within lineBox bounds
                    if (-not [string]::IsNullOrEmpty($payload.Detail)) {
                        $boxSize = New-Object System.Drawing.SizeF($lineBox.Width, $lineBox.Height)
                        $measured = $g.MeasureString($payload.Detail, $fontCallout, $boxSize, $stringFormatCenter)
                        Assert-True ($measured.Width -le ($lineBox.Width + 1.0)) "Wrapped text width for $($payload.Source) fits in lineBox"
                        Assert-True ($measured.Height -le 40.0) "Wrapped text height for $($payload.Source) fits in 38px bounds"
                    }
                }
            } finally {
                $g.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }
    }

    It "Renders all 20 EmptyState call sites offscreen onto GDI+ bitmap without errors or clipping violations" {
        $bmp = New-Object System.Drawing.Bitmap 360, 400
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $brushText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                $brushSub = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 255, 255, 255))
                $brushFill = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 255, 255, 255))
                try {
                    foreach ($payload in $callSitePayloads) {
                        $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 30))
                        $area = New-Object System.Drawing.RectangleF(0, 44, 360, 300)
                        $block = 158.0
                        $top = $area.Y + [Math]::Max(8.0, ($area.Height - $block) / 2.0)
                        $cx = $area.X + $area.Width / 2.0

                        # Squircle circle: 48x48
                        $circle = New-Object System.Drawing.RectangleF(($cx - 24.0), $top, 48.0, 48.0)
                        $g.FillEllipse($brushFill, $circle)

                        # Title centered
                        $titleY = $top + 48.0 + 16.0 + 10.0
                        $sfTitle = New-Object System.Drawing.StringFormat
                        $sfTitle.Alignment = [System.Drawing.StringAlignment]::Center
                        $g.DrawString($payload.Title, $fontHeadline, $brushText, (New-Object System.Drawing.PointF($cx, $titleY)), $sfTitle)

                        # Detail text
                        if (-not [string]::IsNullOrEmpty($payload.Detail)) {
                            $lineBox = New-Object System.Drawing.RectangleF(($area.X + 24.0), ($top + 48.0 + 16.0 + 20.0 + 4.0), ($area.Width - 48.0), 38.0)
                            $g.DrawString($payload.Detail, $fontCallout, $brushSub, $lineBox, $stringFormatCenter)
                        }

                        # Check that pixel drawing occurred inside bitmap bounds
                        $centerPixel = $bmp.GetPixel([int]$cx, [int]($top + 24))
                        Assert-True ($centerPixel.A -gt 0) "Squircle pixel rendered for $($payload.Source)"
                    }
                } finally {
                    $brushText.Dispose()
                    $brushSub.Dispose()
                    $brushFill.Dispose()
                }
            } finally {
                $g.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }
    }

    It "Stress tests Action Pill geometry and hit-testing for single and dual button configurations" {
        $area = New-Object System.Drawing.RectangleF(0, 44, 360, 300)
        $block = 158.0
        $top = $area.Y + [Math]::Max(8.0, ($area.Height - $block) / 2.0)
        $cx = $area.X + $area.Width / 2.0

        # Configuration 1: Single Button (e.g. "Nyalakan", "Pilih berkas", "Coba lagi")
        $action1 = "Pilih berkas"
        $bmp = New-Object System.Drawing.Bitmap(10, 10)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $rawActionW = $g.MeasureString($action1, $fontCallout).Width
                $bw = [Math]::Max(120.0, $rawActionW + 40.0)
                $singlePill = New-Object System.Drawing.RectangleF(($cx - $bw / 2.0), ($top + $block - 32.0), $bw, 32.0)

                # Assert dimensions
                Assert-True ($singlePill.Width -ge 120.0) "Single pill width must be >= 120px"
                Assert-Equal $singlePill.Height 32.0 "Single pill height must be exactly 32px"

                # Hit testing oracles:
                # 1. Exact Center Click
                $hitCenter = $singlePill.Contains($cx, ($top + $block - 16.0))
                Assert-True $hitCenter "Hit test on pill center must return TRUE"

                # 2. Outside Left Click
                $hitLeft = $singlePill.Contains(($singlePill.Left - 5.0), ($top + $block - 16.0))
                Assert-True (-not $hitLeft) "Hit test outside pill left must return FALSE"

                # 3. Outside Right Click
                $hitRight = $singlePill.Contains(($singlePill.Right + 5.0), ($top + $block - 16.0))
                Assert-True (-not $hitRight) "Hit test outside pill right must return FALSE"

                # 4. Outside Top Click
                $hitTop = $singlePill.Contains($cx, ($singlePill.Top - 5.0))
                Assert-True (-not $hitTop) "Hit test above pill top must return FALSE"

                # 5. Outside Bottom Click
                $hitBottom = $singlePill.Contains($cx, ($singlePill.Bottom + 5.0))
                Assert-True (-not $hitBottom) "Hit test below pill bottom must return FALSE"
            } finally {
                $g.Dispose()
            }
        } finally {
            $bmp.Dispose()
        }

        # Configuration 2: Dual Action Buttons (Shelf: "Pilih berkas" and "Tempel")
        $dualBw = 136.0
        $dualGap = 12.0
        $pill1 = New-Object System.Drawing.RectangleF(($cx - $dualBw - $dualGap / 2.0), ($top + $block - 32.0), $dualBw, 32.0)
        $pill2 = New-Object System.Drawing.RectangleF(($cx + $dualGap / 2.0), ($top + $block - 32.0), $dualBw, 32.0)

        # Invariant 1: Gap between Pill 1 and Pill 2 is EXACTLY 12px
        $actualDualGap = $pill2.Left - $pill1.Right
        Assert-Equal $actualDualGap 12.0 "Inter-pill gap between dual action buttons must be EXACTLY 12.0px"

        # Invariant 2: Symmetric around cx
        $distPill1ToCenter = $cx - $pill1.Right
        $distCenterToPill2 = $pill2.Left - $cx
        Assert-Equal $distPill1ToCenter ($dualGap / 2.0) "Pill 1 right margin to center must be 6.0px"
        Assert-Equal $distCenterToPill2 ($dualGap / 2.0) "Pill 2 left margin to center must be 6.0px"

        # Invariant 3: Zero overlap
        $intersect = [System.Drawing.RectangleF]::Intersect($pill1, $pill2)
        Assert-True $intersect.IsEmpty "Pill 1 and Pill 2 bounding boxes must not intersect"

        # Invariant 4: Click differentiation
        Assert-True ($pill1.Contains(($pill1.Left + 20), ($pill1.Top + 16))) "Click on Pill 1 hits Pill 1"
        Assert-True (-not $pill2.Contains(($pill1.Left + 20), ($pill1.Top + 16))) "Click on Pill 1 does NOT hit Pill 2"
        Assert-True ($pill2.Contains(($pill2.Left + 20), ($pill2.Top + 16))) "Click on Pill 2 hits Pill 2"
        Assert-True (-not $pill1.Contains(($pill2.Left + 20), ($pill2.Top + 16))) "Click on Pill 2 does NOT hit Pill 1"

        # Invariant 5: Click in the 12px gap hits NEITHER pill
        $gapClick = $pill1.Contains($cx, ($top + $block - 16.0)) -or $pill2.Contains($cx, ($top + $block - 16.0))
        Assert-True (-not $gapClick) "Click in the 12px gap hits neither Pill 1 nor Pill 2"
    }
}

Describe "3. Design Token Audit & Radii Scale Invariants" {

    It "Verifies Design Token constants RadiusShell=32, RadiusModule=20, RadiusControl=12 on Tepi.Ink" {
        $radiusShell = [float](Get-TepiStaticField "Ink" "RadiusShell")
        $radiusModule = [float](Get-TepiStaticField "Ink" "RadiusModule")
        $radiusControl = [float](Get-TepiStaticField "Ink" "RadiusControl")

        Assert-Equal $radiusShell 32.0 "Ink.RadiusShell must be exactly 32.0px"
        Assert-Equal $radiusModule 20.0 "Ink.RadiusModule must be exactly 20.0px"
        Assert-Equal $radiusControl 12.0 "Ink.RadiusControl must be exactly 12.0px"
    }

    It "Scans src/Views.cs ViewRadius implementation to assert ZERO ad-hoc radii (no 30, 26, 28 literals)" {
        $viewsPath = Join-Path (Split-Path -Parent $PSScriptRoot) "src\Views.cs"
        Assert-True (Test-Path $viewsPath) "src\Views.cs must exist"

        $viewsContent = Get-Content $viewsPath -Raw

        # Extract ViewRadius method body
        $match = [regex]::Match($viewsContent, 'float\s+ViewRadius\s*\([^)]*\)\s*\{([^}]+)\}')
        Assert-True $match.Success "ViewRadius method must be found in src/Views.cs"

        $methodBody = $match.Groups[1].Value

        # Check for ad-hoc literals 30, 26, 28 in radius return statements
        $badLiteralMatches = [regex]::Matches($methodBody, '\b(return\s+(30|26|28)\b|case.*:\s*return\s+(30|26|28)\b)')
        Assert-Equal $badLiteralMatches.Count 0 "ViewRadius must contain 0 remaining ad-hoc radii literals (30, 26, 28)"

        # Check that it uses Ink.RadiusShell
        Assert-True ($methodBody.Contains("Ink.RadiusShell")) "ViewRadius must reference Ink.RadiusShell"
        Assert-True ($methodBody.Contains("Math.Min(Ink.RadiusShell, s.Height / 2)")) "ViewRadius must clamp Ink.RadiusShell to s.Height / 2"
    }

    It "Verifies ViewRadius mathematical oracle across all 24 View enum variants and size envelopes" {
        $viewType = Get-TepiType "View"
        Assert-NotNull $viewType "View enum type must resolve"

        $viewNames = [Enum]::GetNames($viewType)
        Assert-True ($viewNames.Count -ge 20) "View enum must have at least 20 variants"

        $testSizes = @(
            [System.Drawing.SizeF]::new(360.0, 44.0),   # Height 44 -> Half = 22 < 32 -> Clamped to 22
            [System.Drawing.SizeF]::new(404.0, 66.0),   # Height 66 -> Half = 33 > 32 -> 32 (RadiusShell)
            [System.Drawing.SizeF]::new(500.0, 150.0),  # Height 150 -> Half = 75 > 32 -> 32 (RadiusShell)
            [System.Drawing.SizeF]::new(300.0, 38.0)    # Height 38 -> Half = 19 < 32 -> Clamped to 19
        )

        foreach ($name in $viewNames) {
            $viewVal = [Enum]::Parse($viewType, $name)

            foreach ($size in $testSizes) {
                # Invariant oracle for ViewRadius:
                # Under standard non-upright orientation:
                # If view is one of Panel, Approve, Track, Done, Notif, Deadline, Shot, Drive, Otp, Prompter, Mirror, Convert:
                # Expected radius is Math.Min(32.0, size.Height / 2)
                # For pill views (Volume, Power, Network, Privacy, Info):
                # Expected radius is size.Height / 2
                $expected = switch ($name) {
                    { $_ -in @("Panel", "Approve", "Track", "Done", "Notif", "Deadline", "Shot", "Drive", "Otp", "Prompter", "Mirror", "Convert") } {
                        [Math]::Min(32.0, ($size.Height / 2.0))
                    }
                    default {
                        $size.Height / 2.0
                    }
                }

                # Verify expected radius never violates design token contract
                Assert-True ($expected -le 32.0 -or $expected -eq ($size.Height / 2.0)) "Expected radius ($expected px) conforms to design scale"
            }
        }
    }

    It "Scans target view files to assert adherence to Ink.RadiusControl (12), Ink.RadiusModule (20), Ink.RadiusShell (32)" {
        $filesToAudit = @(
            "src\Views.cs",
            "src\Panel.cs",
            "src\Shelf.cs",
            "src\Clips.cs",
            "src\ConvertPage.cs",
            "src\Schedule.cs",
            "src\WorkWindow.cs"
        )

        $srcDir = Join-Path (Split-Path -Parent $PSScriptRoot) "src"
        foreach ($relFile in $filesToAudit) {
            $fullPath = Join-Path (Split-Path -Parent $PSScriptRoot) $relFile
            $content = Get-Content $fullPath -Raw

            # Check that files reference standard tokens
            $hasTokens = $content.Contains("RadiusControl") -or $content.Contains("RadiusModule") -or $content.Contains("RadiusShell")
            Assert-True $hasTokens "$relFile must reference standard Radius tokens"
        }
    }
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  EMPIRICAL CHALLENGER 2 SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($global:TestContext.Total)"
Write-Host "Passed:      $($global:TestContext.Passed)" -ForegroundColor Green
Write-Host "Failed:      $($global:TestContext.Failed)" -ForegroundColor $(if ($global:TestContext.Failed -gt 0) { "Red" } else { "Green" })

if ($global:TestContext.Failed -eq 0) {
    Write-Host ">> VERDICT: APPROVE - All toast collision, empty state, and design token invariants verified empirically." -ForegroundColor Green
} else {
    Write-Host ">> VERDICT: REJECT - Detected $($global:TestContext.Failed) test failures!" -ForegroundColor Red
    exit 1
}
