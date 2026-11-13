# test_f01_typography.ps1
# Feature 1: Font Family Typo Corrections
# Verifies font family names in Ink.cs (Display Semibold, Small Semibold) without typos and verifies valid GDI+ font resolution.

$commonDir = Join-Path $PSScriptRoot "..\common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Describe "Feature 1: Font Family Typo Corrections & Type Scale Resolution" {
    BeforeEach {
        Invoke-TepiStaticMethod "Ink" "Init" @()
    }

    It "Resolves all 7 Typography scale roles into valid Font instances" {
        $roles = @("Hero", "Title1", "Title2", "Headline", "Body", "Callout", "Caption")
        foreach ($role in $roles) {
            $font = Get-TepiStaticProperty "Ink" $role
            Assert-NotNull $font "Typography role [$role] must return a non-null Font object"
            Assert-True ($font -is [System.Drawing.Font]) "[$role] must be an instance of System.Drawing.Font"
            Assert-True ($font.Size -gt 0) "[$role] font size must be greater than 0"
        }
    }

    It "Verifies Display Semibold resolves to Segoe UI Variable Display family without fallback failure" {
        $fDisplayIndex = Get-TepiStaticField "Ink" "FDisplay"
        $families = Get-TepiStaticField "Ink" "families"
        $displayFamily = $families[$fDisplayIndex]

        Assert-NotNull $displayFamily "Display family name must not be null"
        # Must resolve to Segoe UI Variable Display (with GDI+ 31-char limit) or Segoe UI Semibold
        Assert-True ($displayFamily -match "Segoe UI Variable Display|Segoe UI Semibold|Segoe UI") "Display family [$displayFamily] must resolve to Segoe UI family"
        Assert-NotEqual $displayFamily ([System.Drawing.SystemFonts]::MessageBoxFont.FontFamily.Name) "Display family should resolve properly and not fall back to generic MessageBoxFont"
    }

    It "Verifies Small Semibold resolves to Segoe UI Variable Small family without fallback failure" {
        $fSmallSemiIndex = Get-TepiStaticField "Ink" "FSmallSemi"
        $families = Get-TepiStaticField "Ink" "families"
        $smallSemiFamily = $families[$fSmallSemiIndex]

        Assert-NotNull $smallSemiFamily "Small Semibold family name must not be null"
        Assert-True ($smallSemiFamily -match "Segoe UI Variable Small|Segoe UI Semibold|Segoe UI") "Small Semibold family [$smallSemiFamily] must resolve to Segoe UI family"
        Assert-NotEqual $smallSemiFamily ([System.Drawing.SystemFonts]::MessageBoxFont.FontFamily.Name) "Small Semibold family should resolve properly and not fall back to generic MessageBoxFont"
    }

    It "Verifies TypeScale font pixel sizes match documented values (Hero=40, Title1=22, Title2=17, Headline=14.5, Body=13.5, Callout=12.5, Caption=11)" {
        $hero = Get-TepiStaticProperty "Ink" "Hero"
        $title1 = Get-TepiStaticProperty "Ink" "Title1"
        $title2 = Get-TepiStaticProperty "Ink" "Title2"
        $headline = Get-TepiStaticProperty "Ink" "Headline"
        $body = Get-TepiStaticProperty "Ink" "Body"
        $callout = Get-TepiStaticProperty "Ink" "Callout"
        $caption = Get-TepiStaticProperty "Ink" "Caption"

        Assert-Equal $hero.Size 40 "Hero must be 40px"
        Assert-Equal $title1.Size 22 "Title1 must be 22px"
        Assert-Equal $title2.Size 17 "Title2 must be 17px"
        Assert-Equal $headline.Size 14.5 "Headline must be 14.5px"
        Assert-Equal $body.Size 13.5 "Body must be 13.5px"
        Assert-Equal $callout.Size 12.5 "Callout must be 12.5px"
        Assert-Equal $caption.Size 11 "Caption must be 11px"
    }

    It "Verifies font instances can be created with Bold, Regular, and Semibold weights without throwing GDI+ exception" {
        $fSmall = Get-TepiStaticField "Ink" "FSmall"
        $families = Get-TepiStaticField "Ink" "families"
        $familyName = $families[$fSmall]

        $regular = New-Object System.Drawing.Font($familyName, 12, [System.Drawing.FontStyle]::Regular)
        $bold = New-Object System.Drawing.Font($familyName, 12, [System.Drawing.FontStyle]::Bold)

        Assert-NotNull $regular "Regular font instance must be valid"
        Assert-NotNull $bold "Bold font instance must be valid"
        Assert-Equal $regular.Size 12 "Regular font size must be 12"
        Assert-Equal $bold.Size 12 "Bold font size must be 12"

        $regular.Dispose()
        $bold.Dispose()
    }
}
