# Typography System & Font Fallback Chain Investigation (Milestone 1)

## 1. Observation

### Codebase Observations
1. **`src/Ink.cs:194-220` (Font initialization and family picking)**:
   ```csharp
   const int FDisplay = 0, FText = 1, FSemi = 2, FSmall = 3, FMono = 4, FIcons = 5, FSmallSemi = 6;
   static readonly string[] families = new string[7];

   public static string MenuFamily { get { return families[FText]; } }
   public static string IconFamily { get { return families[FIcons]; } }
   static readonly Dictionary<int, Font> fonts = new Dictionary<int, Font>();

   public static void Init()
   {
       var have = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
       using (var fc = new InstalledFontCollection())
           foreach (var f in fc.Families) have.Add(f.Name);
       families[FDisplay] = Pick(have, "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI");
       families[FText] = Pick(have, "Segoe UI Variable Text", "Segoe UI");
       families[FSemi] = Pick(have, "Segoe UI Variable Text Semibold", "Segoe UI Semibold", "Segoe UI");
       families[FSmall] = Pick(have, "Segoe UI Variable Small", "Segoe UI");
       families[FMono] = Pick(have, "Cascadia Mono", "Consolas", "Courier New");
       families[FIcons] = Pick(have, "Segoe Fluent Icons", "Segoe MDL2 Assets", "Segoe UI Symbol");
       families[FSmallSemi] = Pick(have, "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI");
   }

   static string Pick(HashSet<string> have, params string[] names)
   {
       foreach (var n in names) if (have.Contains(n)) return n;
       return System.Drawing.SystemFonts.MessageBoxFont.FontFamily.Name;
   }
   ```
2. **`src/Ink.cs:222-249` (Type scale and font instantiation)**:
   ```csharp
   public static Font Display(float px) { return Get(FDisplay, px); }
   public static Font Text(float px) { return Get(FText, px); }
   public static Font Semi(float px) { return Get(FSemi, px); }
   public static Font Small(float px) { return Get(FSmall, px); }
   public static Font SmallSemi(float px) { return Get(FSmallSemi, px); }
   public static Font Mono(float px) { return Get(FMono, px); }
   public static Font Icons(float px) { return Get(FIcons, px); }

   // Type scale roles
   public static Font Hero { get { return Get(FDisplay, 40f); } }
   public static Font Title1 { get { return Get(FDisplay, 22f); } }
   public static Font Title2 { get { return Get(FSemi, 17f); } }
   public static Font Headline { get { return Get(FSemi, 14.5f); } }
   public static Font Body { get { return Get(FText, 13.5f); } }
   public static Font Callout { get { return Get(FText, 12.5f); } }
   public static Font Caption { get { return Get(FSmall, 11f); } }

   static Font Get(int family, float px)
   {
       int key = family * 100000 + (int)Math.Round(px * 10);
       Font f;
       if (!fonts.TryGetValue(key, out f))
       {
           f = new Font(families[family] ?? "Segoe UI", px, FontStyle.Regular, GraphicsUnit.Pixel);
           fonts[key] = f;
       }
       return f;
   }
   ```
3. **`src/Menus.cs:105`**:
   `public static readonly Font MenuFont = new Font(Ink.MenuFamily, 9.5f);`
   - Initialized at class-load time as a static field.
   - If `Ink.Init()` has not run yet, `Ink.MenuFamily` returns `null`.
   - Running `new Font(null, 9.5f)` in .NET GDI+ instantiates a font using `Microsoft Sans Serif` permanently.
4. **`src/ColorPicker.cs:190`**:
   `using (var f = new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point))`
   - The only hardcoded font name outside of `Ink.cs` in the entire codebase. (Scheduled for M2 refactoring).
5. **`src/Island.cs:114`**:
   `Ink.Init();` is called inside `Island` constructor. There is currently no `static Ink()` constructor in `src/Ink.cs`.

### Runtime & System Measurement Observations
1. **Installed font collection enumeration on Windows 11**:
   Querying `(New-Object System.Drawing.Text.InstalledFontCollection).Families` via GDI+ produces:
   - `Segoe UI Variable Display`
   - `Segoe UI Variable Display Light`
   - `Segoe UI Variable Display Semib`  (Length: 31 characters)
   - `Segoe UI Variable Display Semil`  (Length: 31 characters)
   - `Segoe UI Variable Small`
   - `Segoe UI Variable Small Light`
   - `Segoe UI Variable Small Semibol` (Length: 31 characters)
   - `Segoe UI Variable Small Semilig` (Length: 31 characters)
   - `Segoe UI Variable Text`
   - `Segoe UI Variable Text Light`
   - `Segoe UI Variable Text Semibold` (Length: 31 characters)
   - `Segoe UI Variable Text Semiligh` (Length: 31 characters)
   - `Segoe UI Semibold`
   - `Segoe UI`
   - `Segoe Fluent Icons`
   - `Cascadia Mono`

2. **String membership in `have` (`InstalledFontCollection`)**:
   - `have.Contains("Segoe UI Variable Display Semib")` -> **`True`**
   - `have.Contains("Segoe UI Variable Display Semibold")` -> **`False`**
   - `have.Contains("Segoe UI Variable Small Semibol")` -> **`True`**
   - `have.Contains("Segoe UI Variable Small Semibold")` -> **`False`**
   - `have.Contains("Segoe UI Variable Text Semibold")` -> **`True`**

3. **Behavior when changing `Pick` to only full names**:
   Running `Pick(have, "Segoe UI Variable Display Semibold", "Segoe UI Semibold", "Segoe UI")`:
   - `have.Contains("Segoe UI Variable Display Semibold")` evaluates to `False`.
   - Result picked: **`"Segoe UI Semibold"`** (fallback triggered).
   - Segoe UI Variable Display is completely skipped!

4. **GDI+ `new Font(...)` constructor behavior**:
   - `new Font("Segoe UI Variable Display Semib", 12f)` -> `FontFamily.Name` is `"Segoe UI Variable Display Semib"`.
   - `new Font("Segoe UI Variable Display Semibold", 12f)` -> `FontFamily.Name` is `"Segoe UI Variable Display Semib"` (GDI+ internally matches to the 31-char name).
   - `new Font("NonExistentFont", 12f)` -> `FontFamily.Name` is `"Microsoft Sans Serif"`.

---

## 2. Logic Chain

1. **Win32 GDI Font Architecture Limitation (`LF_FACESIZE = 32`)**:
   In the Windows Win32 GDI subsystem (`LOGFONT` structure and `EnumFontFamiliesEx`), the font family name buffer `lfFaceName` is defined as `WCHAR lfFaceName[LF_FACESIZE]`, where `LF_FACESIZE = 32`.
   Accounting for the null terminator, the maximum string length for a font family name exposed by GDI is **31 characters**.

2. **Source of Truncation**:
   - `"Segoe UI Variable Display Semibold"` has **34 characters**.
     Truncated at 31 characters: `"Segoe UI Variable Display Semib"`
   - `"Segoe UI Variable Small Semibold"` has **32 characters**.
     Truncated at 31 characters: `"Segoe UI Variable Small Semibol"`
   - `"Segoe UI Variable Text Semibold"` has exactly **31 characters**.
     Fits completely within the buffer without truncation.

3. **Misdiagnosis in Prior Audits**:
   `01-visual.md` (VIS-15) and subsequent task summaries in `PROJECT.md` and `SCOPE.md` assumed that `"Display Semib"` and `"Small Semibol"` in `Ink.cs:207, 213` were accidental typos introduced by a developer. They recommended changing them to `"Display Semibold"` and `"Small Semibold"`.

4. **Fatal Consequence of Naive "Fix"**:
   `Ink.cs` does not instantiate fonts to discover available families; it enumerates `InstalledFontCollection` into `have = new HashSet<string>()`.
   Since `InstalledFontCollection` queries GDI, every family name in `have` is subject to the 31-character limit.
   Therefore, `have` contains `"Segoe UI Variable Display Semib"` and NOT `"Segoe UI Variable Display Semibold"`.
   If a developer naively replaces the strings with `"Segoe UI Variable Display Semibold"`, `have.Contains(...)` will return `false`.
   The `Pick` function will skip Segoe UI Variable entirely and fall back to `"Segoe UI Semibold"`.
   This causes Windows 11 users to lose the optical advantages of Segoe UI Variable Display and Small.

5. **Static Initialization Timing Risk**:
   `Ink` has no static constructor. If `Menus.MenuFont` (or any `KitWindow` control) is instantiated before `Island` invokes `Ink.Init()`, `Ink.MenuFamily` evaluates to `null`.
   `new Font(null, 9.5f)` defaults permanently to `Microsoft Sans Serif`, degrading typography in context menus across the application.

6. **Bulletproof Resolution Strategy**:
   - Provide **BOTH** the full intended font family name and the 31-character GDI truncated name in the candidate lists for `Pick`.
   - Augment `Pick()` to automatically check `n.Substring(0, 31)` whenever `n.Length > 31`.
   - Add a static constructor `static Ink() { Init(); }` to guarantee that `families` is populated before any member of `Ink` is accessed.

---

## 3. Caveats

1. **Windows 10 Compatibility**:
   Windows 10 does not include `Segoe UI Variable` (it was introduced in Windows 11 Build 22000). On Windows 10, all Segoe UI Variable lookups will fail and cleanly fall back to `Segoe UI Semibold` and `Segoe UI`. This is the intended behavior and must not be altered.
2. **`ColorPicker.cs:190` Boundary**:
   `ColorPicker.cs:190` contains `new Font("Segoe UI Semibold", 10f, GraphicsUnit.Point)`. While this bypasses `Ink.Semi`, its remediation is scheduled under Milestone 2 (Feature 16: "ColorPicker Loupe Token Alignment"). In Milestone 1, write boundaries are restricted to `Ink.cs`, `Colors.cs`, `Glass.cs`, and `WinTheme.cs`.
3. **Point vs Pixel Units**:
   `Menus.cs:105` uses `9.5f` in `GraphicsUnit.Point` (~12.67px at 96 DPI), whereas `Kit.cs` uses `GraphicsUnit.Pixel`. Aligning menu font scaling with `Ui` scaling is an M2 concern, but ensuring `Ink.MenuFamily` is initialized prevents it from degrading to `Microsoft Sans Serif`.

---

## 4. Conclusion & Concrete Recommendation for Worker

The Worker MUST NOT simply rename `"Display Semib"` to `"Display Semibold"` or `"Small Semibol"` to `"Small Semibold"`. Doing so will break font resolution in GDI+ and trigger fallback to legacy `Segoe UI Semibold`.

### Specific Code Changes for `src/Ink.cs`:

#### 1. Add Static Constructor in `src/Ink.cs` (lines ~91-94)
Ensure `Ink.Init()` runs as soon as `Ink` is touched:
```csharp
    static class Ink
    {
        static Ink()
        {
            Init();
        }

        public static Tone Base = Tone.Dark(), Flip = Tone.Paper();
```

#### 2. Update `Init()` Candidate Lists in `src/Ink.cs:207, 213`
Include both the canonical full name and the 31-char GDI truncated name:
```csharp
        public static void Init()
        {
            var have = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            using (var fc = new InstalledFontCollection())
                foreach (var f in fc.Families) have.Add(f.Name);
            families[FDisplay] = Pick(have, "Segoe UI Variable Display Semibold", "Segoe UI Variable Display Semib", "Segoe UI Semibold", "Segoe UI");
            families[FText] = Pick(have, "Segoe UI Variable Text", "Segoe UI");
            families[FSemi] = Pick(have, "Segoe UI Variable Text Semibold", "Segoe UI Semibold", "Segoe UI");
            families[FSmall] = Pick(have, "Segoe UI Variable Small", "Segoe UI");
            families[FMono] = Pick(have, "Cascadia Mono", "Consolas", "Courier New");
            families[FIcons] = Pick(have, "Segoe Fluent Icons", "Segoe MDL2 Assets", "Segoe UI Symbol");
            families[FSmallSemi] = Pick(have, "Segoe UI Variable Small Semibold", "Segoe UI Variable Small Semibol", "Segoe UI Semibold", "Segoe UI");
        }
```

#### 3. Harden `Pick()` with 31-Character Truncation Matching (`src/Ink.cs:216-220`)
Allow `Pick()` to automatically match any name exceeding GDI's 31-character limit:
```csharp
        static string Pick(HashSet<string> have, params string[] names)
        {
            foreach (var n in names)
            {
                if (have.Contains(n)) return n;
                if (n.Length > 31 && have.Contains(n.Substring(0, 31))) return n.Substring(0, 31);
            }
            return System.Drawing.SystemFonts.MessageBoxFont.FontFamily.Name;
        }
```

### Complete Fallback Matrix Across Platforms

| Slot | Windows 11 Target | Windows 11 Resolved | Windows 10 Fallback | Lowest Fallback |
|---|---|---|---|---|
| `FDisplay` (0) | Segoe UI Variable Display Semibold | `Segoe UI Variable Display Semib` | `Segoe UI Semibold` | `Segoe UI` |
| `FText` (1) | Segoe UI Variable Text | `Segoe UI Variable Text` | `Segoe UI` | `MessageBoxFont` |
| `FSemi` (2) | Segoe UI Variable Text Semibold | `Segoe UI Variable Text Semibold` | `Segoe UI Semibold` | `Segoe UI` |
| `FSmall` (3) | Segoe UI Variable Small | `Segoe UI Variable Small` | `Segoe UI` | `MessageBoxFont` |
| `FMono` (4) | Cascadia Mono | `Cascadia Mono` | `Consolas` | `Courier New` |
| `FIcons` (5) | Segoe Fluent Icons | `Segoe Fluent Icons` | `Segoe MDL2 Assets` | `Segoe UI Symbol` |
| `FSmallSemi` (6) | Segoe UI Variable Small Semibold | `Segoe UI Variable Small Semibol` | `Segoe UI Semibold` | `Segoe UI` |

---

## 5. Verification Method

### 1. Verification Scripts
Run the test scripts located in the state folder:
```powershell
# Verify full vs truncated names and robust Pick behavior
powershell -NoProfile -ExecutionPolicy Bypass -File .agents\teamwork\sub_orch_m1_explorer_1\test_robust_pick.ps1

# Verify GDI+ font construction and family resolution
powershell -NoProfile -ExecutionPolicy Bypass -File .agents\teamwork\sub_orch_m1_explorer_1\test_unknown_font.ps1
```

### 2. Compilation Verification
Verify the project compiles cleanly with the C# compiler:
```cmd
cmd /c build.cmd
```
Expected output:
```
Build OK: D:\PROJECT\Other\tepi\Tepi.exe
```

### 3. Invalidation Conditions
- If `Pick` returns `"Segoe UI Semibold"` on Windows 11 for `FDisplay` or `FSmallSemi`, the fix has failed and Segoe UI Variable is not resolving.
- If `MenuFont` in `Menus.cs` resolves to `"Microsoft Sans Serif"`, static initialization order has failed.
