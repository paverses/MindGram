# Renders the MindGram logo into the PNGs Telegram's intro screen needs.
# Usage (Windows PowerShell): powershell -File MindGram/scripts/render-logo.ps1
# The geometry is the same as MindGram/Branding/logo.svg and MindGramLogo in MindGram/Core.
param([string]$OutDir = (Join-Path $PSScriptRoot "..\Branding\intro"))

Add-Type -AssemblyName System.Drawing

function New-LogoPath([float]$x, [float]$y, [float]$width) {
    $s = $width / 69.0
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    # Bowl
    $p.StartFigure()
    $p.AddLine($x, $y, $x + 20.5 * $s, $y)
    $p.AddArc($x + 20.5 * $s, $y - 14 * $s, 28 * $s, 28 * $s, 180, -180)
    $p.AddLine($x + 48.5 * $s, $y, $x + 69 * $s, $y)
    $p.AddArc($x, $y - 34.5 * $s, 69 * $s, 69 * $s, 0, 180)
    $p.CloseFigure()
    # Left foot
    $p.StartFigure()
    $p.AddArc($x - 23 * $s, $y + 31.5 * $s, 46 * $s, 46 * $s, -90, 60.4)
    $p.AddLine($x + 20 * $s, $y + 43.14 * $s, $x + 20 * $s, $y + 54.5 * $s)
    $p.AddLine($x + 20 * $s, $y + 54.5 * $s, $x, $y + 54.5 * $s)
    $p.CloseFigure()
    # Right foot
    $p.StartFigure()
    $p.AddArc($x + 46 * $s, $y + 31.5 * $s, 46 * $s, 46 * $s, -90, -60.4)
    $p.AddLine($x + 49 * $s, $y + 43.14 * $s, $x + 49 * $s, $y + 54.5 * $s)
    $p.AddLine($x + 49 * $s, $y + 54.5 * $s, $x + 69 * $s, $y + 54.5 * $s)
    $p.CloseFigure()
    return $p
}

function Save-Png([System.Drawing.Bitmap]$b, [string]$path) {
    $b.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
}

New-Item -ItemType Directory -Force $OutDir | Out-Null

# Intro "sphere": a black disc with the white logo (296 x 296 at @2x).
$size = 296
$b = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$g.FillEllipse([System.Drawing.Brushes]::Black, 0, 0, $size, $size)
$w = 150.0
$g.FillPath([System.Drawing.Brushes]::White, (New-LogoPath (($size - $w) / 2) (($size - $w * 54.5 / 69) / 2) $w))
$g.Dispose()
Save-Png $b (Join-Path $OutDir "telegram_sphere@2x.png")

# Intro "plane": Telegram animates a paper plane over the sphere; MindGram shows none.
$b = New-Object System.Drawing.Bitmap 164, 148
$g = [System.Drawing.Graphics]::FromImage($b)
$g.Clear([System.Drawing.Color]::Transparent)
$g.Dispose()
Save-Png $b (Join-Path $OutDir "telegram_plane1@2x.png")

# Preview of the app icon, for checking the artwork.
$size = 512
$b = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($b)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Black)
$w = 300.0
$g.FillPath([System.Drawing.Brushes]::White, (New-LogoPath (($size - $w) / 2) (($size - $w * 54.5 / 69) / 2) $w))
$g.Dispose()
Save-Png $b (Join-Path $OutDir "..\AppIcon-preview.png")

# Alternate app icons for Settings > Appearance > App Icon: the regular one and the inverted one
# (white background, black logo). Names follow Telegram's .alticon folders (see Telegram/BUILD).
function Save-Icon([string]$dir, [string]$file, [int]$size, [bool]$inverted) {
    $b = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    if ($inverted) {
        $g.Clear([System.Drawing.Color]::White)
        $brush = [System.Drawing.Brushes]::Black
    } else {
        $g.Clear([System.Drawing.Color]::Black)
        $brush = [System.Drawing.Brushes]::White
    }
    $w = $size * 0.586
    $g.FillPath($brush, (New-LogoPath (($size - $w) / 2) (($size - $w * 54.5 / 69) / 2) $w))
    $g.Dispose()
    Save-Png $b (Join-Path $dir $file)
}

$iconRoot = Join-Path $PSScriptRoot "..\Branding\AlternateIcons"
foreach ($variant in @(@{ Name = "MindGram"; Inverted = $false }, @{ Name = "MindGramInverted"; Inverted = $true })) {
    $name = $variant.Name
    $dir = Join-Path $iconRoot "$name.alticon"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Save-Icon $dir "$name@2x.png" 120 $variant.Inverted
    Save-Icon $dir "$name@3x.png" 180 $variant.Inverted
    Save-Icon $dir "${name}Ipad.png" 76 $variant.Inverted
    Save-Icon $dir "${name}Ipad@2x.png" 152 $variant.Inverted
    Save-Icon $dir "${name}LargeIpad@2x.png" 167 $variant.Inverted
    Save-Icon $dir "${name}NotificationIcon.png" 20 $variant.Inverted
    Save-Icon $dir "${name}NotificationIcon@2x.png" 40 $variant.Inverted
    Save-Icon $dir "${name}NotificationIcon@3x.png" 60 $variant.Inverted
}

# Extra minimal icons: same logo, a quiet two-tone background (top to bottom gradient), no glow.
function Save-ThemedIcon([string]$dir, [string]$file, [int]$size, [string]$top, [string]$bottom, [string]$logo) {
    $b = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml($top)), ([System.Drawing.ColorTranslator]::FromHtml($bottom)), 90.0
    $g.FillRectangle($grad, $rect)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($logo))
    $w = $size * 0.586
    $g.FillPath($brush, (New-LogoPath (($size - $w) / 2) (($size - $w * 54.5 / 69) / 2) $w))
    $g.Dispose()
    Save-Png $b (Join-Path $dir $file)
}

$themes = @(
    @{ Name = "MindGramGraphite"; Top = "#34363B"; Bottom = "#1B1C1F"; Logo = "#F2F2F0" },
    @{ Name = "MindGramPaper";    Top = "#F5F1E8"; Bottom = "#E6E0D2"; Logo = "#1F1F21" },
    @{ Name = "MindGramMidnight"; Top = "#25324F"; Bottom = "#141B2D"; Logo = "#E9ECF4" },
    @{ Name = "MindGramSage";     Top = "#9DB09A"; Bottom = "#78917A"; Logo = "#FBFBF7" }
)
foreach ($theme in $themes) {
    $name = $theme.Name
    $dir = Join-Path $iconRoot "$name.alticon"
    New-Item -ItemType Directory -Force $dir | Out-Null
    foreach ($spec in @(@("$name@2x.png", 120), @("$name@3x.png", 180), @("${name}Ipad.png", 76), @("${name}Ipad@2x.png", 152), @("${name}LargeIpad@2x.png", 167), @("${name}NotificationIcon.png", 20), @("${name}NotificationIcon@2x.png", 40), @("${name}NotificationIcon@3x.png", 60))) {
        Save-ThemedIcon $dir $spec[0] $spec[1] $theme.Top $theme.Bottom $theme.Logo
    }
}

# Preview sheet of every icon, rounded like on the home screen.
$names = @("MindGram", "MindGramInverted") + ($themes | ForEach-Object { $_.Name })
$cell = 180; $gap = 36
$sheet = New-Object System.Drawing.Bitmap ($names.Count * ($cell + $gap) + $gap), ($cell + $gap * 2)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.ColorTranslator]::FromHtml("#8E8E93"))
for ($i = 0; $i -lt $names.Count; $i++) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $iconRoot ("{0}.alticon\{0}@3x.png" -f $names[$i])))
    $x = $gap + $i * ($cell + $gap); $y = $gap
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 40
    $path.AddArc($x, $y, $r * 2, $r * 2, 180, 90); $path.AddArc($x + $cell - $r * 2, $y, $r * 2, $r * 2, 270, 90)
    $path.AddArc($x + $cell - $r * 2, $y + $cell - $r * 2, $r * 2, $r * 2, 0, 90); $path.AddArc($x, $y + $cell - $r * 2, $r * 2, $r * 2, 90, 90)
    $path.CloseFigure()
    $g.SetClip($path)
    $g.DrawImage($img, $x, $y, $cell, $cell)
    $g.ResetClip()
    $img.Dispose()
}
$g.Dispose()
Save-Png $sheet (Join-Path $PSScriptRoot "..\Branding\AlternateIcons-preview.png")

# App badge shown by Telegram at the top centre, under the notch (Components/AppBadge, 93x22 pt @3x):
# a dark pill with the logo standing in for the "M" of "indGram".
$bw = 279; $bh = 66
$badge = New-Object System.Drawing.Bitmap $bw, $bh
$g = [System.Drawing.Graphics]::FromImage($badge)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)
$pill = New-Object System.Drawing.Drawing2D.GraphicsPath
$pill.AddArc(0, 0, $bh, $bh, 90, 180); $pill.AddArc($bw - $bh, 0, $bh, $bh, 270, 180); $pill.CloseFigure()
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#121214"))), $pill)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#F4F4F2"))
# Unbounded (SIL OFL, Branding/fonts) — the typeface of the owner's mini apps.
$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $PSScriptRoot "..\Branding\fonts\Unbounded[wght].ttf"))
$font = New-Object System.Drawing.Font ($fonts.Families | Where-Object { $_.Name -eq "Unbounded Medium" } | Select-Object -First 1), 25, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$text = "indGram"
$format = [System.Drawing.StringFormat]::GenericTypographic
$textSize = $g.MeasureString($text, $font, 1000, $format)
$capHeight = 19.0
$logoWidth = $capHeight * 69 / 54.5
$gap = 2.0
$total = $logoWidth + $gap + $textSize.Width
$x0 = ($bw - $total) / 2
$baseline = ($bh + $capHeight) / 2
$g.FillPath($white, (New-LogoPath $x0 ($baseline - $capHeight) $logoWidth))
$ascent = $font.FontFamily.GetCellAscent([System.Drawing.FontStyle]::Regular) * $font.Size / $font.FontFamily.GetEmHeight([System.Drawing.FontStyle]::Regular)
$g.DrawString($text, $font, $white, ($x0 + $logoWidth + $gap), ($baseline - $ascent), $format)
$g.Dispose()
Save-Png $badge (Join-Path $PSScriptRoot "..\Branding\AppBadge@3x.png")
