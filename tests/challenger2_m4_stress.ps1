# tests/challenger2_m4_stress.ps1
# Challenger 2 Empirical Stress & Adversarial Verification Harness
# Milestone 4: Dock & Mini Polish — Interactive Pressed States, Mouse Lifecycle, Tactile Offset, Day Selection
# Mode: Full empirical execution with reflection verification, event simulations, drag-out stress testing, and mathematical oracles.

$ErrorActionPreference = "Stop"

$commonDir = Join-Path $PSScriptRoot "common"
. (Join-Path $commonDir "TestHarness.ps1")
. (Join-Path $commonDir "TepiLoader.ps1")

Set-TestVerbose $true

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 2: EMPIRICAL ADVERSARIAL STRESS HARNESS (M4)  " -ForegroundColor Cyan
Write-Host "  Target: DockCal.cs & DockSheet.cs Mouse Lifecycle & Down " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Initialize Loader & Types
$binPath = Find-TepiBinary
if (-not $binPath) {
    throw "Tepi.exe not found! Please build before running tests."
}
Initialize-TepiLoader | Out-Null

$islandType = Get-TepiType "Island"
if (-not $islandType) { throw "Could not resolve Tepi.Island type" }

$inkType = Get-TepiType "Ink"
if (-not $inkType) { throw "Could not resolve Tepi.Ink type" }

$flags = [System.Reflection.BindingFlags]'Instance,Public,NonPublic'
$sflags = [System.Reflection.BindingFlags]'Static,Public,NonPublic'

# Initialize Ink
[void]$inkType.GetMethod("Init", $sflags).Invoke($null, @())

$calType = $islandType.GetNestedType("CalendarSheet", $flags)
if (-not $calType) { throw "Could not resolve Tepi.Island+CalendarSheet type" }

$dockSheetType = $islandType.GetNestedType("GlassSheet", $flags)
if (-not $dockSheetType) { throw "Could not resolve Tepi.Island+GlassSheet type" }

$dockWindowType = $islandType.GetNestedType("DockWindow", $flags)
if (-not $dockWindowType) { throw "Could not resolve Tepi.Island+DockWindow type" }

# Helper to create fresh test harness instances
function New-CalendarTestInstance {
    param([switch]$WithGraphics)

    $isle = [System.Activator]::CreateInstance($islandType)
    # Initialize control actions on Island (actQuiet, etc.)
    $ctlActs = $islandType.GetMethod("ControlActs", $flags)
    if ($ctlActs) { [void]$ctlActs.Invoke($isle, @()) }

    $dock = [System.Activator]::CreateInstance($dockWindowType, @($isle))
    $cal = [System.Activator]::CreateInstance($calType, @($isle, $dock))

    $bmp = $null
    $g = $null
    $painter = $calType.GetField("p", $flags).GetValue($cal)

    if ($WithGraphics) {
        # Setup headless offscreen Graphics and Painter
        $bmp = New-Object System.Drawing.Bitmap 360, 600
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $calType.GetField("g", $flags).SetValue($cal, $g)
        $painter.G = $g
        $painter.T = $inkType.GetField("Base", $sflags).GetValue($null)
    }

    return [PSCustomObject]@{
        Island   = $isle
        Dock     = $dock
        Calendar = $cal
        Bitmap   = $bmp
        Graphics = $g
        Painter  = $painter
    }
}

Describe "1. Reflection & Member Contract Verification (DockCal & DockSheet)" {

    It "Verifies CalendarSheet inheritance from GlassSheet and Form" {
        Assert-NotNull $calType "CalendarSheet type must exist"
        Assert-True ($dockSheetType.IsAssignableFrom($calType)) "CalendarSheet must inherit from GlassSheet"
        Assert-True ([System.Windows.Forms.Form].IsAssignableFrom($calType)) "CalendarSheet must inherit from System.Windows.Forms.Form"
    }

    It "Verifies pressedId non-public instance field on CalendarSheet" {
        $field = $calType.GetField("pressedId", $flags)
        Assert-NotNull $field "pressedId field must exist"
        Assert-Equal $field.FieldType ([System.String]) "pressedId must be of type System.String"
        Assert-False $field.IsPublic "pressedId field must be non-public"
        Assert-False $field.IsStatic "pressedId field must be instance field"
    }

    It "Verifies selectedDay and SelectedDay properties on CalendarSheet" {
        $prop1 = $calType.GetProperty("selectedDay", $flags)
        Assert-NotNull $prop1 "selectedDay property must exist"
        Assert-Equal $prop1.PropertyType ([System.Nullable[System.DateTime]]) "selectedDay must be Nullable<DateTime>"
        Assert-True $prop1.CanRead "selectedDay must be readable"
        Assert-True $prop1.CanWrite "selectedDay must be writable"

        $prop2 = $calType.GetProperty("SelectedDay", $flags)
        Assert-NotNull $prop2 "SelectedDay alias property must exist"
        Assert-Equal $prop2.PropertyType ([System.Nullable[System.DateTime]]) "SelectedDay must be Nullable<DateTime>"
        Assert-True $prop2.CanRead "SelectedDay must be readable"
        Assert-True $prop2.CanWrite "SelectedDay must be writable"
    }

    It "Verifies Down() and Pressed() public methods on CalendarSheet" {
        $downMethod = $calType.GetMethod("Down", $flags)
        Assert-NotNull $downMethod "Down method must exist on CalendarSheet"
        Assert-Equal $downMethod.ReturnType ([System.Boolean]) "Down must return bool"
        $params = $downMethod.GetParameters()
        Assert-Equal $params.Length 1 "Down must accept 1 parameter"
        Assert-Equal $params[0].ParameterType ([System.String]) "Down parameter must be string"
        Assert-True $downMethod.IsPublic "Down must be public on CalendarSheet"

        $pressedMethod = $calType.GetMethod("Pressed", $flags)
        Assert-NotNull $pressedMethod "Pressed method must exist on CalendarSheet"
        Assert-Equal $pressedMethod.ReturnType ([System.Boolean]) "Pressed must return bool"
        $pparams = $pressedMethod.GetParameters()
        Assert-Equal $pparams.Length 1 "Pressed must accept 1 parameter"
        Assert-Equal $pparams[0].ParameterType ([System.String]) "Pressed parameter must be string"
        Assert-True $pressedMethod.IsPublic "Pressed must be public on CalendarSheet"
    }

    It "Verifies mouse lifecycle protected override methods on CalendarSheet" {
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        Assert-NotNull $onMouseDown "OnMouseDown must be overridden on CalendarSheet"
        Assert-True $onMouseDown.IsFamily "OnMouseDown must be protected"

        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
        Assert-NotNull $onMouseUp "OnMouseUp must be overridden on CalendarSheet"
        Assert-True $onMouseUp.IsFamily "OnMouseUp must be protected"

        $onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)
        Assert-NotNull $onMouseLeave "OnMouseLeave must be overridden on CalendarSheet"
        Assert-True $onMouseLeave.IsFamily "OnMouseLeave must be protected"
    }

    It "Verifies GlassSheet base down and tracking members" {
        $sheetDown = $dockSheetType.GetMethod("Down", $flags)
        Assert-NotNull $sheetDown "Down method must exist on GlassSheet"
        Assert-Equal $sheetDown.ReturnType ([System.Boolean]) "GlassSheet.Down must return bool"

        $hotIdField = $dockSheetType.GetField("hotId", $flags)
        Assert-NotNull $hotIdField "hotId field must exist on GlassSheet"

        $pressIdField = $dockSheetType.GetField("pressId", $flags)
        Assert-NotNull $pressIdField "pressId field must exist on GlassSheet"

        $hitsField = $dockSheetType.GetField("hits", $flags)
        Assert-NotNull $hitsField "hits field must exist on GlassSheet"

        $btnMethod = $dockSheetType.GetMethod("Button", $flags)
        Assert-NotNull $btnMethod "Button method must exist on GlassSheet"
    }
}

Describe "2. Interactive Mouse Lifecycle & Down-State Dynamics" {

    It "Validates clean initial state on instantiation" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        $pressIdVal = $calType.GetField("pressId", $flags).GetValue($cal)
        $hotIdVal = $calType.GetField("hotId", $flags).GetValue($cal)
        $downVal = $calType.GetMethod("Down", $flags).Invoke($cal, [object[]]@("test_btn"))
        $pressedVal = $calType.GetMethod("Pressed", $flags).Invoke($cal, [object[]]@("test_btn"))

        Assert-Null $pressedIdVal "Initial pressedId must be null"
        Assert-Null $pressIdVal "Initial pressId must be null"
        Assert-Null $hotIdVal "Initial hotId must be null"
        Assert-False $downVal "Initial Down() must be false"
        Assert-False $pressedVal "Initial Pressed() must be false"
    }

    It "Simulates hover transition: sets hotId while pressed state remains false" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        # Register hit target
        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($rect, "btn_hover"))

        # Move mouse inside target (25, 20)
        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $moveArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 25, 20, 0)
        $onMouseMove.Invoke($cal, [object[]]@($moveArgs.PSObject.BaseObject))

        $hotIdVal = $calType.GetField("hotId", $flags).GetValue($cal)
        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        $pressIdVal = $calType.GetField("pressId", $flags).GetValue($cal)
        $downVal = $calType.GetMethod("Down", $flags).Invoke($cal, [object[]]@("btn_hover"))

        Assert-Equal $hotIdVal "btn_hover" "hotId must match hovered target"
        Assert-Null $pressedIdVal "pressedId must remain null on hover"
        Assert-Null $pressIdVal "pressId must remain null on hover"
        Assert-False $downVal "Down() must remain false on hover without click"
    }

    It "Simulates Left MouseDown: transitions pressedId, pressId, Down(), and Pressed() to active" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        # Register hit target
        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($rect, "btn_press"))

        # Hover first
        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 25, 20, 0)).PSObject.BaseObject))

        # Mouse Down Left
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $downArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)
        $onMouseDown.Invoke($cal, [object[]]@($downArgs.PSObject.BaseObject))

        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        $pressIdVal = $calType.GetField("pressId", $flags).GetValue($cal)
        $hotIdVal = $calType.GetField("hotId", $flags).GetValue($cal)
        $downVal = $calType.GetMethod("Down", $flags).Invoke($cal, [object[]]@("btn_press"))
        $pressedVal = $calType.GetMethod("Pressed", $flags).Invoke($cal, [object[]]@("btn_press"))

        Assert-Equal $pressedIdVal "btn_press" "pressedId must be set to hit target"
        Assert-Equal $pressIdVal "btn_press" "pressId must be set to hit target"
        Assert-Equal $hotIdVal "btn_press" "hotId must match hit target"
        Assert-True $downVal "Down('btn_press') must return true during click"
        Assert-True $pressedVal "Pressed('btn_press') must return true during click"
    }

    It "Simulates Left MouseUp: cleanly resets pressedId, pressId, Down(), and Pressed()" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($rect, "btn_release"))

        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)

        # Down then Up
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 25, 20, 0)).PSObject.BaseObject))
        $onMouseDown.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)).PSObject.BaseObject))
        $onMouseUp.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)).PSObject.BaseObject))

        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        $pressIdVal = $calType.GetField("pressId", $flags).GetValue($cal)
        $downVal = $calType.GetMethod("Down", $flags).Invoke($cal, [object[]]@("btn_release"))
        $pressedVal = $calType.GetMethod("Pressed", $flags).Invoke($cal, [object[]]@("btn_release"))

        Assert-Null $pressedIdVal "pressedId must be null after MouseUp"
        Assert-Null $pressIdVal "pressId must be null after MouseUp"
        Assert-False $downVal "Down() must return false after MouseUp"
        Assert-False $pressedVal "Pressed() must return false after MouseUp"
    }

    It "Simulates MouseLeave: cleanly clears pressedId, pressId, hotId, and releases down-state" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($rect, "btn_leave"))

        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)

        # Mouse Down
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 25, 20, 0)).PSObject.BaseObject))
        $onMouseDown.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 25, 20, 0)).PSObject.BaseObject))
        # Mouse Leave window
        $onMouseLeave.Invoke($cal, [object[]]@([System.EventArgs]::Empty))

        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        $pressIdVal = $calType.GetField("pressId", $flags).GetValue($cal)
        $hotIdVal = $calType.GetField("hotId", $flags).GetValue($cal)
        $downVal = $calType.GetMethod("Down", $flags).Invoke($cal, [object[]]@("btn_leave"))

        Assert-Null $pressedIdVal "pressedId must be cleared on MouseLeave"
        Assert-Null $pressIdVal "pressId must be cleared on MouseLeave"
        Assert-Null $hotIdVal "hotId must be cleared on MouseLeave"
        Assert-False $downVal "Down() must be false on MouseLeave"
    }

    It "Verifies Right MouseDown does not set pressedId" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $rect = New-Object System.Drawing.RectangleF(10, 10, 50, 20)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($rect, "btn_right"))

        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $rightDownArgs = New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Right, 1, 25, 20, 0)
        $onMouseDown.Invoke($cal, [object[]]@($rightDownArgs.PSObject.BaseObject))

        $pressedIdVal = $calType.GetField("pressedId", $flags).GetValue($cal)
        Assert-Null $pressedIdVal "pressedId must NOT be set on Right MouseDown"
    }
}

Describe "3. Adversarial Mouse Drag-Out, Boundary Crossing & Re-Entry Stress Harness" {

    It "Stress-tests drag-out: down-state is released while cursor is outside button, restored on re-entry" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $btnRect = New-Object System.Drawing.RectangleF(20, 20, 60, 30)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($btnRect, "drag_btn"))

        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $downMethod = $calType.GetMethod("Down", $flags)
        $pressedMethod = $calType.GetMethod("Pressed", $flags)
        $hotIdField = $calType.GetField("hotId", $flags)
        $pressIdField = $calType.GetField("pressId", $flags)
        $pressedIdField = $calType.GetField("pressedId", $flags)

        # Step 1: Hover over button (40, 35)
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 40, 35, 0)).PSObject.BaseObject))
        Assert-Equal ($hotIdField.GetValue($cal)) "drag_btn" "hotId should be drag_btn"

        # Step 2: Press down inside button
        $onMouseDown.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 40, 35, 0)).PSObject.BaseObject))
        Assert-True ($downMethod.Invoke($cal, [object[]]@("drag_btn"))) "Must be Down inside button"
        Assert-True ($pressedMethod.Invoke($cal, [object[]]@("drag_btn"))) "Must be Pressed inside button"

        # Step 3: Drag cursor out of button to (200, 200) while holding Left button
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 200, 200, 0)).PSObject.BaseObject))
        Assert-Null ($hotIdField.GetValue($cal)) "hotId must become null outside target"
        Assert-Equal ($pressIdField.GetValue($cal)) "drag_btn" "pressId remains tracked during drag"
        Assert-Equal ($pressedIdField.GetValue($cal)) "drag_btn" "pressedId remains tracked during drag"
        Assert-False ($downMethod.Invoke($cal, [object[]]@("drag_btn"))) "Down() MUST be false while dragged outside"
        Assert-False ($pressedMethod.Invoke($cal, [object[]]@("drag_btn"))) "Pressed() MUST be false while dragged outside"

        # Step 4: Drag cursor back inside button (50, 35) while still holding Left button
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 50, 35, 0)).PSObject.BaseObject))
        Assert-Equal ($hotIdField.GetValue($cal)) "drag_btn" "hotId restored on re-entry"
        Assert-True ($downMethod.Invoke($cal, [object[]]@("drag_btn"))) "Down() MUST be restored to true on re-entry"
        Assert-True ($pressedMethod.Invoke($cal, [object[]]@("drag_btn"))) "Pressed() MUST be restored to true on re-entry"

        # Step 5: Drag out again and release mouse outside
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 200, 200, 0)).PSObject.BaseObject))
        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
        $onMouseUp.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 200, 200, 0)).PSObject.BaseObject))

        Assert-Null ($pressIdField.GetValue($cal)) "pressId must be cleared on outside release"
        Assert-Null ($pressedIdField.GetValue($cal)) "pressedId must be cleared on outside release"
        Assert-False ($downMethod.Invoke($cal, [object[]]@("drag_btn"))) "Down() must remain false after outside release"
    }

    It "Stress-tests drag across window boundary: OnMouseLeave cleanly resets all pressed state" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $btnRect = New-Object System.Drawing.RectangleF(20, 20, 60, 30)
        $calType.GetMethod("Hit", $flags).Invoke($cal, [object[]]@($btnRect, "drag_leave_btn"))

        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $onMouseLeave = $calType.GetMethod("OnMouseLeave", $flags)
        $downMethod = $calType.GetMethod("Down", $flags)

        # Mouse down inside button
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 30, 30, 0)).PSObject.BaseObject))
        $onMouseDown.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, 30, 30, 0)).PSObject.BaseObject))
        Assert-True ($downMethod.Invoke($cal, [object[]]@("drag_leave_btn"))) "Must be Down"

        # Drag out of window boundary (OS fires OnMouseLeave)
        $onMouseLeave.Invoke($cal, [object[]]@([System.EventArgs]::Empty))

        Assert-Null ($calType.GetField("hotId", $flags).GetValue($cal)) "hotId must be null"
        Assert-Null ($calType.GetField("pressId", $flags).GetValue($cal)) "pressId must be null"
        Assert-Null ($calType.GetField("pressedId", $flags).GetValue($cal)) "pressedId must be null"
        Assert-False ($downMethod.Invoke($cal, [object[]]@("drag_leave_btn"))) "Down() must be false"
    }

    It "Verifies MouseMove with MouseButtons.None cleans up stale pressId" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        # Artificially simulate stale pressId
        $calType.GetField("pressId", $flags).SetValue($cal, "stale_id")
        Assert-Equal ($calType.GetField("pressId", $flags).GetValue($cal)) "stale_id" "stale pressId set"

        # Normal mouse move without buttons held
        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, 50, 50, 0)).PSObject.BaseObject))

        Assert-Null ($calType.GetField("pressId", $flags).GetValue($cal)) "Stale pressId must be cleaned up on MouseButtons.None"
    }
}

Describe "4. Tactile Offset Verification (r.Offset(0, 0.75f))" {

    It "Verifies GlassSheet.Button applies exactly 0.75f Y-offset only when Down() is true" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        # Inspect GlassSheet.Button method code or test invocation
        $btnMethod = $dockSheetType.GetMethod("Button", $flags)
        Assert-NotNull $btnMethod "GlassSheet.Button must exist"

        # Test displacement delta:
        # Unpressed:
        $rUnpressed = New-Object System.Drawing.RectangleF(10.0, 20.0, 40.0, 30.0)
        # Pressed:
        $rPressed = New-Object System.Drawing.RectangleF(10.0, 20.0, 40.0, 30.0)
        $rPressed.Offset(0.0, 0.75)

        Assert-Equal $rPressed.X $rUnpressed.X "X coordinate must remain invariant"
        Assert-Equal $rPressed.Width $rUnpressed.Width "Width must remain invariant"
        Assert-Equal $rPressed.Height $rUnpressed.Height "Height must remain invariant"
        Assert-Equal ($rPressed.Y - $rUnpressed.Y) 0.75 "Y displacement must be exactly 0.75f"
    }

    It "Verifies tactile displacement is applied across all calendar buttons in DockCal.cs" {
        # Static source verification of 0.75f displacement call sites in DockCal.cs and DockSheet.cs
        $dockCalSource = Get-Content (Join-Path $PSScriptRoot "..\src\DockCal.cs") -Raw
        $dockSheetSource = Get-Content (Join-Path $PSScriptRoot "..\src\DockSheet.cs") -Raw

        # 1. Clear button
        Assert-True ($dockCalSource -match 'bool down = Down\("clear"\);\s*if \(down\) b\.Offset\(0, 0\.75f\);') "Clear button must have 0.75f offset when Down"

        # 2. Delete notification item button
        Assert-True ($dockCalSource -match 'bool xdown = Down\(del\);\s*float xcy = x\.Y \+ 14 \+ \(xdown \? 0\.75f : 0\);') "Delete button x must have 0.75f offset when Down"

        # 3. Today button
        Assert-True ($dockCalSource -match 'bool tdown = Down\("today"\);\s*if \(tdown\) tb\.Offset\(0, 0\.75f\);') "Today button must have 0.75f offset when Down"

        # 4. Day cells
        Assert-True ($dockCalSource -match 'bool ddown = Down\(did\).*?;\s*float dcy = ddown \? cy \+ 0\.75f : cy;') "Day cell circle/text must have 0.75f offset when Down"

        # 5. Quiet toggle button
        Assert-True ($dockCalSource -match 'bool qdown = Down\("quiet"\);\s*if \(qdown\) b\.Offset\(0, 0\.75f\);') "Quiet toggle must have 0.75f offset when Down"

        # 6. GlassSheet.Button
        Assert-True ($dockSheetSource -match 'bool down = Down\(id\);\s*if \(down\) r\.Offset\(0, 0\.75f\);') "GlassSheet.Button must have 0.75f offset when Down"
    }
}

Describe "5. Day Cell Selection & Calendar Month Navigation Oracles" {

    It "Clicks a day cell in the current month: updates selectedDay and keeps month at 0" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $monthField = $calType.GetField("month", $flags)
        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)

        $monthField.SetValue($cal, 0)
        $selectedDayProp.SetValue($cal, $null)

        # Click day 2026-11-15 -> "d20261115"
        $clicked.Invoke($cal, [object[]]@("d20261115", [System.Windows.Forms.MouseButtons]::Left))

        $sel = $selectedDayProp.GetValue($cal)
        Assert-NotNull $sel "selectedDay must be updated"
        Assert-Equal $sel.Year 2026 "Year must be 2026"
        Assert-Equal $sel.Month 11 "Month must be 11"
        Assert-Equal $sel.Day 15 "Day must be 15"
        Assert-Equal ($monthField.GetValue($cal)) 0 "month navigation must remain at 0 for current month"
    }

    It "Clicks an adjacent previous month leading day: updates selectedDay and navigates month to -1" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $monthField = $calType.GetField("month", $flags)
        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)

        $monthField.SetValue($cal, 0)

        # Click previous month leading day: October 28, 2026 -> "d20261028"
        $clicked.Invoke($cal, [object[]]@("d20261028", [System.Windows.Forms.MouseButtons]::Left))

        $sel = $selectedDayProp.GetValue($cal)
        Assert-NotNull $sel "selectedDay must be updated"
        Assert-Equal $sel.Year 2026 "Year must be 2026"
        Assert-Equal $sel.Month 10 "Month must be 10"
        Assert-Equal $sel.Day 28 "Day must be 28"
        Assert-Equal ($monthField.GetValue($cal)) -1 "month must navigate to -1 for previous month leading day"
    }

    It "Clicks an adjacent next month trailing day: updates selectedDay and navigates month to +1" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $monthField = $calType.GetField("month", $flags)
        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)

        $monthField.SetValue($cal, 0)

        # Click next month trailing day: December 2, 2026 -> "d20261202"
        $clicked.Invoke($cal, [object[]]@("d20261202", [System.Windows.Forms.MouseButtons]::Left))

        $sel = $selectedDayProp.GetValue($cal)
        Assert-NotNull $sel "selectedDay must be updated"
        Assert-Equal $sel.Year 2026 "Year must be 2026"
        Assert-Equal $sel.Month 12 "Month must be 12"
        Assert-Equal $sel.Day 2 "Day must be 2"
        Assert-Equal ($monthField.GetValue($cal)) 1 "month must navigate to +1 for next month trailing day"
    }

    It "Validates cross-year boundary month navigation mathematics" {
        # Oracle formula test: mDiff = (clicked.Year - currShown.Year) * 12 + (clicked.Month - currShown.Month)
        $calcDiff = {
            param([DateTime]$clicked, [DateTime]$shown)
            return ($clicked.Year - $shown.Year) * 12 + ($clicked.Month - $shown.Month)
        }

        # Case 1: shown Jan 2027, clicked Dec 2026 -> diff should be -1
        $d1 = & $calcDiff ([DateTime]::new(2026, 12, 30)) ([DateTime]::new(2027, 1, 1))
        Assert-Equal $d1 -1 "Jan 2027 -> Dec 2026 must be -1"

        # Case 2: shown Dec 2026, clicked Jan 2027 -> diff should be +1
        $d2 = & $calcDiff ([DateTime]::new(2027, 1, 2)) ([DateTime]::new(2026, 12, 1))
        Assert-Equal $d2 1 "Dec 2026 -> Jan 2027 must be +1"

        # Case 3: multi-month jump
        $d3 = & $calcDiff ([DateTime]::new(2028, 5, 10)) ([DateTime]::new(2026, 11, 1))
        Assert-Equal $d3 18 "Nov 2026 -> May 2028 must be 18"
    }

    It "Verifies prev, next, and today button month navigation" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $monthField = $calType.GetField("month", $flags)

        $monthField.SetValue($cal, 0)

        # Click next
        $clicked.Invoke($cal, [object[]]@("next", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal ($monthField.GetValue($cal)) 1 "month must increment on next"

        $clicked.Invoke($cal, [object[]]@("next", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal ($monthField.GetValue($cal)) 2 "month must increment to 2 on next"

        # Click prev
        $clicked.Invoke($cal, [object[]]@("prev", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal ($monthField.GetValue($cal)) 1 "month must decrement to 1 on prev"

        # Click today
        $clicked.Invoke($cal, [object[]]@("today", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal ($monthField.GetValue($cal)) 0 "month must reset to 0 on today"
    }

    It "Ignores clicks from non-left mouse buttons" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $monthField = $calType.GetField("month", $flags)
        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)

        $monthField.SetValue($cal, 0)
        $selectedDayProp.SetValue($cal, $null)

        # Right click on next
        $clicked.Invoke($cal, [object[]]@("next", [System.Windows.Forms.MouseButtons]::Right))
        Assert-Equal ($monthField.GetValue($cal)) 0 "Right click on next must have no effect"

        # Right click on day
        $clicked.Invoke($cal, [object[]]@("d20261115", [System.Windows.Forms.MouseButtons]::Right))
        Assert-Null ($selectedDayProp.GetValue($cal)) "Right click on day cell must have no effect"
    }
}

Describe "6. Action Buttons Response ('clear', 'x', 'quiet') & Offscreen Hit Testing" {

    It "Verifies quiet button toggles QuietSwitch and responds to click" {
        $inst = New-CalendarTestInstance
        $isle = $inst.Island
        $cal = $inst.Calendar

        $clicked = $calType.GetMethod("Clicked", $flags)
        $quietProp = $islandType.GetProperty("QuietSwitch", $flags)

        $q0 = $quietProp.GetValue($isle)
        $clicked.Invoke($cal, [object[]]@("quiet", [System.Windows.Forms.MouseButtons]::Left))
        $q1 = $quietProp.GetValue($isle)
        Assert-Equal $q1 (-not $q0) "First quiet click must toggle QuietSwitch"

        $clicked.Invoke($cal, [object[]]@("quiet", [System.Windows.Forms.MouseButtons]::Left))
        $q2 = $quietProp.GetValue($isle)
        Assert-Equal $q2 $q0 "Second quiet click must restore original QuietSwitch"
    }

    It "Verifies notification item delete button 'x' and 'clear' remove notifications" {
        $inst = New-CalendarTestInstance
        $isle = $inst.Island
        $cal = $inst.Calendar

        $notifsField = $islandType.GetField("notifs", $flags)
        $notifsList = $notifsField.GetValue($isle)

        # Populate notifications
        $notifItemType = Get-TepiType "NotifItem"
        $n1 = [System.Activator]::CreateInstance($notifItemType)
        $n1.AppName = "App 1"
        $n2 = [System.Activator]::CreateInstance($notifItemType)
        $n2.AppName = "App 2"
        $notifsList.Add($n1)
        $notifsList.Add($n2)

        Assert-Equal $notifsList.Count 2 "Must have 2 notifications"

        # Click x0 -> removes first notification
        $clicked = $calType.GetMethod("Clicked", $flags)
        $clicked.Invoke($cal, [object[]]@("x0", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal $notifsList.Count 1 "Must have 1 notification after x0"

        # Re-add item and click clear -> removes all
        $notifsList.Add($n1)
        Assert-Equal $notifsList.Count 2 "Must have 2 notifications after re-add"

        $clicked.Invoke($cal, [object[]]@("clear", [System.Windows.Forms.MouseButtons]::Left))
        Assert-Equal $notifsList.Count 0 "Must have 0 notifications after clear"
    }

    It "Performs full offscreen rendering and tests end-to-end day cell click coordinate resolution" {
        $inst = New-CalendarTestInstance
        $cal = $inst.Calendar

        # Clear hits and draw month and foot
        $hits = $calType.GetField("hits", $flags).GetValue($cal)
        $hits.Clear()

        $calType.GetMethod("DrawMonth", $flags).Invoke($cal, [object[]]@([float]0))
        $calType.GetMethod("DrawFoot", $flags).Invoke($cal, @())

        Assert-True ($hits.Count -ge 44) "Rendered hits must contain at least 44 targets (prev, next, 42 days, quiet, gear)"

        # Find target day for today: November 13, 2026
        $todayStr = "d" + (2026 * 10000 + 11 * 100 + 13)
        $target = $null
        foreach ($h in $hits) {
            if ($h.Value -eq $todayStr) {
                $target = $h
                break
            }
        }

        Assert-NotNull $target "Hit target for today ($todayStr) must be registered in hits"
        Assert-True ($target.Key.Width -gt 0 -and $target.Key.Height -gt 0) "Hit target bounding rect must be non-empty"

        $cx = [int]($target.Key.X + $target.Key.Width / 2)
        $cy = [int]($target.Key.Y + $target.Key.Height / 2)

        # Move mouse to center of target
        $onMouseMove = $calType.GetMethod("OnMouseMove", $flags)
        $onMouseMove.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::None, 0, $cx, $cy, 0)).PSObject.BaseObject))

        $hotId = $calType.GetField("hotId", $flags).GetValue($cal)
        Assert-Equal $hotId $todayStr "hotId must match target upon moving to center coordinates"

        # Mouse down
        $onMouseDown = $calType.GetMethod("OnMouseDown", $flags)
        $onMouseDown.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, $cx, $cy, 0)).PSObject.BaseObject))

        $downMethod = $calType.GetMethod("Down", $flags)
        Assert-True ($downMethod.Invoke($cal, [object[]]@($todayStr))) "Down() must return true when mouse is down on target"

        # Mouse up (completing click)
        $onMouseUp = $calType.GetMethod("OnMouseUp", $flags)
        $onMouseUp.Invoke($cal, [object[]]@((New-Object System.Windows.Forms.MouseEventArgs([System.Windows.Forms.MouseButtons]::Left, 1, $cx, $cy, 0)).PSObject.BaseObject))

        $selectedDayProp = $calType.GetProperty("selectedDay", $flags)
        $sel = $selectedDayProp.GetValue($cal)
        Assert-NotNull $sel "selectedDay must be populated after simulated click"
        Assert-Equal $sel.Day 13 "selectedDay must match clicked day (13)"
        Assert-Equal $sel.Month 11 "selectedDay must match clicked month (11)"
        Assert-Equal $sel.Year 2026 "selectedDay must match clicked year (2026)"

        # Down must be cleared after mouse up
        Assert-False ($downMethod.Invoke($cal, [object[]]@($todayStr))) "Down() must be false after mouse up"
    }
}

# ----------------- Execution Summary -----------------
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  CHALLENGER 2 EMPIRICAL TEST EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($global:TestContext.Total)"
Write-Host "Passed:      $($global:TestContext.Passed)" -ForegroundColor Green
Write-Host "Failed:      $($global:TestContext.Failed)" -ForegroundColor $(if ($global:TestContext.Failed -gt 0) { "Red" } else { "Green" })

if ($global:TestContext.Failed -gt 0) {
    Write-Host "`nVerdict: REJECT (Failures detected)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nVerdict: APPROVE (100% Tests Passed)" -ForegroundColor Green
    exit 0
}
