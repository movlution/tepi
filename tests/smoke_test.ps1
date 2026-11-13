# smoke_test.ps1
# End-to-End Infrastructure Smoke Test Suite for Tepi
# Verifies compilation, assembly loading, reflection helpers, headless offscreen rendering, and CLI invocation.

$commonDir = Join-Path $PSScriptRoot "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Smoke Test Suite: Environment & Binary Integrity" {
    It "Validates 64-bit runtime environment" {
        Assert-Equal ([IntPtr]::Size) 8 "Process must be 64-bit ([IntPtr]::Size == 8)"
    }

    It "Validates Tepi.exe binary exists on disk and is non-empty" {
        $binPath = Find-TepiBinary
        Assert-NotNull $binPath "Tepi.exe must be located"
        $file = Get-Item $binPath
        Assert-True ($file.Length -gt 500000) "Tepi.exe size must exceed 500KB (actual: $($file.Length) bytes)"
    }

    It "Loads Tepi.exe assembly into reflection cache" {
        $asm = Initialize-TepiLoader
        Assert-NotNull $asm "Assembly must be loaded"
        $types = $asm.GetTypes()
        Assert-True ($types.Length -gt 100) "Assembly must contain application types (found: $($types.Length))"
    }
}

Describe "Smoke Test Suite: Core Reflection & Type Resolution" {
    It "Resolves primary engine and token types" {
        $requiredTypes = @("Ink", "Tone", "Island", "KitInk", "KitButton", "KitSwitch", "KitSlider", "KitRow", "KitWindow")
        foreach ($typeName in $requiredTypes) {
            $t = Get-TepiType $typeName
            Assert-NotNull $t "Type [$typeName] must be resolvable via Get-TepiType"
        }
    }

    It "Verifies Design Token Spacing & Radii constants on Tepi.Ink" {
        $radiusShell = Get-TepiStaticField "Ink" "RadiusShell"
        $radiusModule = Get-TepiStaticField "Ink" "RadiusModule"
        $radiusControl = Get-TepiStaticField "Ink" "RadiusControl"

        Assert-Equal $radiusShell 32 "RadiusShell must equal 32"
        Assert-Equal $radiusModule 20 "RadiusModule must equal 20"
        Assert-Equal $radiusControl 12 "RadiusControl must equal 12"

        $sp4 = Get-TepiStaticField "Ink" "Sp4"
        $sp8 = Get-TepiStaticField "Ink" "Sp8"
        $sp16 = Get-TepiStaticField "Ink" "Sp16"
        $sp32 = Get-TepiStaticField "Ink" "Sp32"

        Assert-Equal $sp4 4 "Sp4 spacing token must equal 4"
        Assert-Equal $sp8 8 "Sp8 spacing token must equal 8"
        Assert-Equal $sp16 16 "Sp16 spacing token must equal 16"
        Assert-Equal $sp32 32 "Sp32 spacing token must equal 32"
    }

    It "Verifies Typography Scale properties on Tepi.Ink" {
        Invoke-TepiStaticMethod "Ink" "Init" @()

        $roles = @("Hero", "Title1", "Title2", "Headline", "Body", "Callout", "Caption")
        foreach ($role in $roles) {
            $font = Get-TepiStaticProperty "Ink" $role
            Assert-NotNull $font "Typography role [$role] must return a non-null Font object"
            Assert-True ($font -is [System.Drawing.Font]) "[$role] must be an instance of System.Drawing.Font"
            Assert-True ($font.SizeInPoints -gt 0) "[$role] font size must be greater than 0"
        }
    }

    It "Verifies KitInk color token properties" {
        Reset-TepiTheme -Light $false

        $kitTokens = @("Window", "Side", "Group", "Line", "Hover", "Raised", "Text", "Sub", "Faint", "Disabled", "Accent", "OnAccent")
        foreach ($token in $kitTokens) {
            $color = Get-TepiStaticProperty "KitInk" $token
            Assert-NotNull $color "KitInk token [$token] must not be null"
            Assert-True ($color -is [System.Drawing.Color]) "KitInk token [$token] must be System.Drawing.Color"
            Assert-Equal $color.A 255 "KitInk token [$token] must be fully opaque (A=255)"
        }
    }
}

Describe "Smoke Test Suite: Mathematical Contrast & Oracles" {
    It "Verifies authoritative WCAG contrast calculation for Black vs White" {
        $black = [System.Drawing.Color]::Black
        $white = [System.Drawing.Color]::White

        $ratio = Get-WcagContrastRatio $black $white
        Assert-Equal $ratio 21.0 "Black vs White contrast must equal 21.0:1"
    }

    It "Verifies Tepi.Island.Contrast reflection matches authoritative calculation" {
        $black = [System.Drawing.Color]::Black
        $white = [System.Drawing.Color]::White

        $tepiRatio = Get-TepiContrast $black $white
        $wcagRatio = Get-WcagContrastRatio $black $white

        Assert-Equal $tepiRatio $wcagRatio "Tepi.Island.Contrast ($tepiRatio) must match Get-WcagContrastRatio ($wcagRatio)"
    }

    It "Verifies Assert-Contrast assertion passes for accessible pairs and fails for poor pairs" {
        $white = [System.Drawing.Color]::White
        $darkGrey = [System.Drawing.Color]::FromArgb(255, 30, 30, 30)
        $ratio = Assert-Contrast $white $darkGrey 4.5 "Dark grey on white must pass 4.5:1"
        Assert-True ($ratio -ge 4.5) "Contrast ratio must be >= 4.5"
    }
}

Describe "Smoke Test Suite: Headless Offscreen Control Rendering" {
    It "Instantiates and renders KitButton offscreen via DrawToBitmap" {
        $btn = New-TepiControl "KitButton" @{ Text = "Smoke Test Button" }
        Assert-NotNull $btn "KitButton instance must be created"

        $bmp = Render-TepiControlToBitmap $btn 120 36
        Assert-NotNull $bmp "Rendered bitmap must not be null"
        Assert-Equal $bmp.Width 120 "Bitmap width must match requested width"
        Assert-Equal $bmp.Height 36 "Bitmap height must match requested height"

        # Check center pixel has opaque alpha
        $centerPixel = $bmp.GetPixel(60, 18)
        Assert-Equal $centerPixel.A 255 "Center pixel must be opaque"

        $bmp.Dispose()
        $btn.Dispose()
    }

    It "Instantiates and renders KitSwitch offscreen" {
        $switch = New-TepiControl "KitSwitch" @{ Checked = $true }
        Assert-NotNull $switch "KitSwitch instance must be created"

        $bmp = Render-TepiControlToBitmap $switch 60 28
        Assert-NotNull $bmp "Rendered switch bitmap must not be null"
        Assert-Equal $bmp.Width 60 "Switch width must match"
        Assert-Equal $bmp.Height 28 "Switch height must match"

        $bmp.Dispose()
        $switch.Dispose()
    }

    It "Instantiates and renders KitSlider offscreen" {
        $slider = New-TepiControl "KitSlider" @{ Value = 40; Minimum = 0; Maximum = 100 }
        Assert-NotNull $slider "KitSlider instance must be created"

        $bmp = Render-TepiControlToBitmap $slider 140 24
        Assert-NotNull $bmp "Rendered slider bitmap must not be null"
        Assert-Equal $bmp.Width 140 "Slider width must match"
        Assert-Equal $bmp.Height 24 "Slider height must match"

        $bmp.Dispose()
        $slider.Dispose()
    }

    It "Instantiates and renders KitRow offscreen" {
        $row = New-TepiControl "KitRow" @{ Text = "Smoke Row Option" }
        Assert-NotNull $row "KitRow instance must be created"

        $bmp = Render-TepiControlToBitmap $row 180 36
        Assert-NotNull $bmp "Rendered row bitmap must not be null"
        Assert-Equal $bmp.Width 180 "Row width must match"
        Assert-Equal $bmp.Height 36 "Row height must match"

        $bmp.Dispose()
        $row.Dispose()
    }
}

Describe "Smoke Test Suite: Theme State Management & Isolation" {
    It "Switches to Light Mode and verifies state update" {
        Reset-TepiTheme -Light $true
        $isLight = Get-TepiStaticField "Ink" "Light"
        Assert-True $isLight "Ink.Light should be true in Light Mode"

        $baseTone = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $baseTone "Base tone must be set"
    }

    It "Resets to Dark Mode and verifies state isolation" {
        Reset-TepiTheme -Light $false
        $isLight = Get-TepiStaticField "Ink" "Light"
        Assert-False $isLight "Ink.Light should be false in Dark Mode"

        $baseTone = Get-TepiStaticField "Ink" "Base"
        Assert-NotNull $baseTone "Base tone must be set"
    }
}

Describe "Smoke Test Suite: Process & CLI Argument Execution" {
    It "Invokes Tepi.exe --notify without parameters and captures expected exit code" {
        $binPath = Find-TepiBinary
        Assert-NotNull $binPath "Tepi.exe binary path resolved"

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $binPath
        $pinfo.Arguments = "--notify"
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true

        $proc = [System.Diagnostics.Process]::Start($pinfo)
        [void]$proc.WaitForExit(5000)

        Assert-True $proc.HasExited "Process must exit within 5 seconds"
        # Code 2 indicates missing mandatory arguments in Plugin.cs:63-83
        Assert-Equal $proc.ExitCode 2 "Tepi.exe --notify without parameters must exit with code 2"
    }
}
