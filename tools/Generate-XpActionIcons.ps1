Add-Type -AssemblyName System.Drawing

$outputDirectory = Join-Path $PSScriptRoot '..\LogiPetPlugin\src\Resources\Actions'
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$colors = @{
    Face = [Drawing.Color]::FromArgb(255, 236, 233, 216)
    Light = [Drawing.Color]::FromArgb(255, 255, 255, 255)
    Shadow = [Drawing.Color]::FromArgb(255, 128, 128, 128)
    Dark = [Drawing.Color]::FromArgb(255, 38, 38, 38)
    Blue = [Drawing.Color]::FromArgb(255, 36, 94, 219)
    Sky = [Drawing.Color]::FromArgb(255, 98, 165, 255)
    Mint = [Drawing.Color]::FromArgb(255, 45, 212, 143)
    Yellow = [Drawing.Color]::FromArgb(255, 255, 207, 64)
    Brown = [Drawing.Color]::FromArgb(255, 201, 130, 53)
    BrownDark = [Drawing.Color]::FromArgb(255, 144, 84, 34)
    Red = [Drawing.Color]::FromArgb(255, 226, 74, 54)
}

$scale = 4
$origin = 9

function Add-PixelRect($graphics, [int]$x, [int]$y, [int]$width, [int]$height, $color) {
    $brush = New-Object Drawing.SolidBrush $color
    $graphics.FillRectangle($brush, $origin + $x * $scale, $origin + $y * $scale, $width * $scale, $height * $scale)
    $brush.Dispose()
}

function Add-XpPanel($graphics) {
    $graphics.Clear([Drawing.Color]::Transparent)
    Add-PixelRect $graphics 0 0 18 18 $colors.Dark
    Add-PixelRect $graphics 1 1 16 16 $colors.Face
    Add-PixelRect $graphics 1 1 16 1 $colors.Light
    Add-PixelRect $graphics 1 1 1 16 $colors.Light
    Add-PixelRect $graphics 1 16 16 1 $colors.Shadow
    Add-PixelRect $graphics 16 1 1 16 $colors.Shadow
}

function Add-Paw($graphics, [int]$offsetX = 0, [int]$offsetY = 0) {
    Add-PixelRect $graphics (5 + $offsetX) (4 + $offsetY) 2 3 $colors.Brown
    Add-PixelRect $graphics (8 + $offsetX) (3 + $offsetY) 2 3 $colors.Brown
    Add-PixelRect $graphics (11 + $offsetX) (4 + $offsetY) 2 3 $colors.Brown
    Add-PixelRect $graphics (6 + $offsetX) (8 + $offsetY) 7 6 $colors.BrownDark
    Add-PixelRect $graphics (7 + $offsetX) (7 + $offsetY) 5 1 $colors.BrownDark
    Add-PixelRect $graphics (8 + $offsetX) (9 + $offsetY) 3 3 $colors.Brown
}

function Add-Dog($graphics, [int]$offsetX = 0, [int]$offsetY = 0, [bool]$lying = $false) {
    if ($lying) {
        Add-PixelRect $graphics (3 + $offsetX) (10 + $offsetY) 10 3 $colors.Brown
        Add-PixelRect $graphics (12 + $offsetX) (8 + $offsetY) 3 4 $colors.Brown
        Add-PixelRect $graphics (13 + $offsetX) (9 + $offsetY) 1 1 $colors.Dark
        Add-PixelRect $graphics (2 + $offsetX) (9 + $offsetY) 2 1 $colors.BrownDark
        Add-PixelRect $graphics (5 + $offsetX) (13 + $offsetY) 3 1 $colors.BrownDark
        Add-PixelRect $graphics (11 + $offsetX) (13 + $offsetY) 3 1 $colors.BrownDark
        return
    }
    Add-PixelRect $graphics (5 + $offsetX) (8 + $offsetY) 8 5 $colors.Brown
    Add-PixelRect $graphics (11 + $offsetX) (5 + $offsetY) 4 5 $colors.Brown
    Add-PixelRect $graphics (13 + $offsetX) (6 + $offsetY) 1 1 $colors.Dark
    Add-PixelRect $graphics (10 + $offsetX) (4 + $offsetY) 2 3 $colors.BrownDark
    Add-PixelRect $graphics (3 + $offsetX) (7 + $offsetY) 3 2 $colors.BrownDark
    Add-PixelRect $graphics (6 + $offsetX) (12 + $offsetY) 2 3 $colors.BrownDark
    Add-PixelRect $graphics (11 + $offsetX) (12 + $offsetY) 2 3 $colors.BrownDark
    Add-PixelRect $graphics (11 + $offsetX) (9 + $offsetY) 3 1 $colors.Mint
}

function Save-XpIcon([string]$name, [scriptblock]$paint) {
    $bitmap = New-Object Drawing.Bitmap 90, 90, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    Add-XpPanel $graphics
    & $paint $graphics
    $path = Join-Path $outputDirectory "$name.png"
    $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

Save-XpIcon 'snack' {
    param($g)
    Add-PixelRect $g 4 7 3 2 $colors.Light; Add-PixelRect $g 3 6 2 2 $colors.Yellow
    Add-PixelRect $g 4 9 2 2 $colors.Yellow; Add-PixelRect $g 6 7 7 3 $colors.Yellow
    Add-PixelRect $g 13 6 2 2 $colors.Yellow; Add-PixelRect $g 13 9 2 2 $colors.Yellow
    Add-PixelRect $g 7 8 5 1 $colors.Light
}
Save-XpIcon 'water' {
    param($g)
    Add-PixelRect $g 9 3 2 2 $colors.Blue; Add-PixelRect $g 8 5 4 2 $colors.Blue
    Add-PixelRect $g 6 7 8 5 $colors.Blue; Add-PixelRect $g 7 12 6 2 $colors.Blue
    Add-PixelRect $g 8 7 2 4 $colors.Sky; Add-PixelRect $g 10 6 1 2 $colors.Light
}
Save-XpIcon 'highfive' { param($g) Add-Paw $g }
Save-XpIcon 'stretch' {
    param($g)
    Add-Dog $g -1 0 $false
    Add-PixelRect $g 2 3 7 1 $colors.Blue; Add-PixelRect $g 2 3 1 4 $colors.Blue
    Add-PixelRect $g 2 3 3 3 $colors.Blue; Add-PixelRect $g 12 14 4 1 $colors.Blue
    Add-PixelRect $g 15 11 1 4 $colors.Blue; Add-PixelRect $g 13 13 3 2 $colors.Blue
}
Save-XpIcon 'play' {
    param($g)
    Add-PixelRect $g 4 4 10 10 $colors.Mint; Add-PixelRect $g 5 5 8 8 $colors.Blue
    Add-PixelRect $g 8 6 2 6 $colors.Light; Add-PixelRect $g 10 7 2 4 $colors.Light
    Add-PixelRect $g 12 8 1 2 $colors.Light
}
Save-XpIcon 'journal' {
    param($g)
    Add-PixelRect $g 4 3 10 12 $colors.Light; Add-PixelRect $g 4 3 10 2 $colors.Blue
    Add-PixelRect $g 6 6 6 1 $colors.Shadow; Add-PixelRect $g 6 8 4 1 $colors.Shadow
    Add-PixelRect $g 6 12 2 2 $colors.Mint; Add-PixelRect $g 9 10 2 4 $colors.Yellow
    Add-PixelRect $g 12 8 1 6 $colors.Blue
}
Save-XpIcon 'come' {
    param($g)
    Add-Paw $g 2 2
    Add-PixelRect $g 2 3 8 2 $colors.Blue; Add-PixelRect $g 2 3 3 5 $colors.Blue
    Add-PixelRect $g 2 6 2 2 $colors.Sky
}
Save-XpIcon 'zoomies' {
    param($g)
    Add-Dog $g -2 2 $false
    Add-PixelRect $g 11 2 4 2 $colors.Yellow; Add-PixelRect $g 9 4 5 3 $colors.Yellow
    Add-PixelRect $g 8 7 4 2 $colors.Yellow; Add-PixelRect $g 7 9 3 2 $colors.Yellow
}
Save-XpIcon 'speak' {
    param($g)
    Add-PixelRect $g 3 3 12 9 $colors.Light; Add-PixelRect $g 4 4 10 7 $colors.Blue
    Add-PixelRect $g 6 6 2 2 $colors.Light; Add-PixelRect $g 9 6 2 2 $colors.Light
    Add-PixelRect $g 12 6 1 2 $colors.Light; Add-PixelRect $g 5 12 4 2 $colors.Blue
}
Save-XpIcon 'sit' {
    param($g)
    Add-PixelRect $g 7 7 6 7 $colors.Brown; Add-PixelRect $g 10 4 4 5 $colors.Brown
    Add-PixelRect $g 12 5 1 1 $colors.Dark; Add-PixelRect $g 9 3 2 3 $colors.BrownDark
    Add-PixelRect $g 4 12 5 2 $colors.BrownDark; Add-PixelRect $g 11 13 4 2 $colors.BrownDark
    Add-PixelRect $g 10 8 4 1 $colors.Mint
}
Save-XpIcon 'lie' { param($g) Add-Dog $g 0 0 $true }
Save-XpIcon 'nap' {
    param($g)
    Add-PixelRect $g 5 4 6 9 $colors.Yellow; Add-PixelRect $g 8 3 5 10 $colors.Face
    Add-PixelRect $g 10 4 4 1 $colors.Blue; Add-PixelRect $g 12 5 2 1 $colors.Blue
    Add-PixelRect $g 10 6 4 1 $colors.Blue; Add-PixelRect $g 12 8 3 1 $colors.Sky
    Add-PixelRect $g 13 9 2 1 $colors.Sky; Add-PixelRect $g 12 10 3 1 $colors.Sky
}
Save-XpIcon 'scratch' {
    param($g)
    Add-Paw $g -2 2
    Add-PixelRect $g 12 3 1 7 $colors.Red; Add-PixelRect $g 14 4 1 7 $colors.Red
    Add-PixelRect $g 16 5 1 7 $colors.Red
}

$files = Get-ChildItem -LiteralPath $outputDirectory -Filter '*.png' | Sort-Object Name
$preview = New-Object Drawing.Bitmap 420, 420, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$previewGraphics = [Drawing.Graphics]::FromImage($preview)
$previewGraphics.Clear([Drawing.Color]::FromArgb(255, 236, 233, 216))
$font = New-Object Drawing.Font 'Tahoma', 9
$textBrush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 20, 20, 20))
for ($index = 0; $index -lt $files.Count; $index++) {
    $column = $index % 4
    $row = [Math]::Floor($index / 4)
    $image = [Drawing.Image]::FromFile($files[$index].FullName)
    $previewGraphics.DrawImage($image, 8 + $column * 103, 8 + $row * 103, 90, 90)
    $previewGraphics.DrawString($files[$index].BaseName, $font, $textBrush, 9 + $column * 103, 96 + $row * 103)
    $image.Dispose()
}
$previewPath = Join-Path $PSScriptRoot '..\docs\action-ring-xp-icons.png'
$preview.Save($previewPath, [Drawing.Imaging.ImageFormat]::Png)
$textBrush.Dispose(); $font.Dispose(); $previewGraphics.Dispose(); $preview.Dispose()

Write-Output $outputDirectory
Write-Output $previewPath
