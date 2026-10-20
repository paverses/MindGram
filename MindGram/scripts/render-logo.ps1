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
