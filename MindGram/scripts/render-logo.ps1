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
