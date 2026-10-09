# Generator atlas huruf untuk f_signs.
# Jalankan ulang kalau ingin ganti font:  powershell -ExecutionPolicy Bypass -File tools\make_atlas.ps1
# Hasil: atlas/<gaya>.png (huruf tajam), atlas/<gaya>_glow.png (pendar, setengah resolusi), shared/fonts.lua (ukuran tiap huruf)

param([string]$Root = (Split-Path -Parent $PSScriptRoot))

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class AtlasUtil {
    // Semua pixel dibuat putih (alpha tetap) supaya tidak ada pinggiran gelap saat texture di-filter
    public static void ForceWhite(Bitmap bmp) {
        var rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
        var data = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int len = data.Stride * bmp.Height;
        var buf = new byte[len];
        Marshal.Copy(data.Scan0, buf, 0, len);
        for (int i = 0; i < len; i += 4) { buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; }
        Marshal.Copy(buf, 0, data.Scan0, len);
        bmp.UnlockBits(data);
    }
}
'@

$CellW = 128; $CellH = 96; $Pad = 16; $Cols = 16; $Rows = 6
$TexW = $CellW * $Cols; $TexH = $CellH * $Rows

$Fonts = @(
    @{ Key = 'led';  Family = 'Bahnschrift SemiBold';  Tracking = 0.12; Glow = @(@(30, 18), @(22, 28), @(14, 45), @(8, 70)) },
    @{ Key = 'neon'; Family = 'Bahnschrift Light'; Tracking = 0.16; Glow = @(@(30, 22), @(22, 34), @(14, 55), @(8, 90), @(4, 140)) }
)

$fmt = [System.Drawing.StringFormat]::GenericTypographic
$chars = 33..126

function New-GlyphPath($family, $em, [int]$code) {
    # Winding: kontur yang bertumpuk (font variabel seperti Bahnschrift) tidak bolong
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath([System.Drawing.Drawing2D.FillMode]::Winding)
    $p.AddString([string][char]$code, $family, 0, [single]$em, (New-Object System.Drawing.PointF(0, 0)), $fmt)
    return $p
}

function New-Canvas($w, $h) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.PixelOffsetMode = 'HighQuality'
    $g.Clear([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    return @($bmp, $g)
}

$lua = New-Object System.Text.StringBuilder
[void]$lua.AppendLine('-- DIBUAT OTOMATIS oleh tools/make_atlas.ps1 - jangan diedit manual')
[void]$lua.AppendLine('SignFonts = {}')

New-Item -ItemType Directory -Force (Join-Path $Root 'atlas') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $Root 'shared') | Out-Null

foreach ($f in $Fonts) {
    $family = New-Object System.Drawing.FontFamily($f.Family)

    # 1. Ukur di em 100 untuk mencari skala yang muat di sel
    $minTop = 1e9; $maxBottom = -1e9; $maxW = 0
    foreach ($c in $chars) {
        $p = New-GlyphPath $family 100 $c
        $b = $p.GetBounds()
        if ($b.Width -gt 0) {
            if ($b.Top -lt $minTop) { $minTop = $b.Top }
            if ($b.Bottom -gt $maxBottom) { $maxBottom = $b.Bottom }
            if ($b.Width -gt $maxW) { $maxW = $b.Width }
        }
        $p.Dispose()
    }
    $k = [Math]::Min(($CellH - 2 * $Pad) / ($maxBottom - $minTop), ($CellW - 2 * $Pad) / $maxW)
    $em = 100 * $k
    $dy = $Pad - $minTop * $k

    $hb = (New-GlyphPath $family $em 72).GetBounds() # 'H'
    $capTop = $hb.Top + $dy
    $baseline = $hb.Bottom + $dy
    $capH = $baseline - $capTop

    # 2. Gambar atlas tajam + atlas pendar (resolusi penuh, nanti diperkecil)
    $core = New-Canvas $TexW $TexH
    $glow = New-Canvas $TexW $TexH
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $widths = @{}

    foreach ($c in $chars) {
        $i = $c - 32
        $col = $i % $Cols; $row = [Math]::Floor($i / $Cols)
        $p = New-GlyphPath $family $em $c
        $b = $p.GetBounds()
        $m = New-Object System.Drawing.Drawing2D.Matrix
        $m.Translate([single]($col * $CellW + $Pad - $b.X), [single]($row * $CellH + $dy))
        $p.Transform($m)
        $core[1].FillPath($white, $p)

        foreach ($gl in $f.Glow) {
            $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($gl[1], 255, 255, 255), [single]$gl[0])
            $pen.LineJoin = 'Round'
            $glow[1].DrawPath($pen, $p)
            $pen.Dispose()
        }
        $glow[1].FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 255, 255, 255))), $p)

        $widths[$c] = [Math]::Round($b.Width, 2)
        $p.Dispose()
    }

    $half = New-Canvas ($TexW / 2) ($TexH / 2)
    $half[1].InterpolationMode = 'HighQualityBicubic'
    $half[1].DrawImage($glow[0], 0, 0, $TexW / 2, $TexH / 2)

    [AtlasUtil]::ForceWhite($core[0])
    [AtlasUtil]::ForceWhite($half[0])
    $core[0].Save((Join-Path $Root "atlas\$($f.Key).png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $half[0].Save((Join-Path $Root "atlas\$($f.Key)_glow.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    foreach ($x in @($core, $glow, $half)) { $x[1].Dispose(); $x[0].Dispose() }

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $w = ($chars | ForEach-Object { '[{0}]={1}' -f $_, $widths[$_].ToString($inv) }) -join ','
    [void]$lua.AppendLine(("SignFonts.{0} = {{ texW = {1}, texH = {2}, cellW = {3}, cellH = {4}, cols = {5}, pad = {6}, capTop = {7}, baseline = {8}, space = {9}, tracking = {10},`n    w = {{ {11} }} }}" -f `
        $f.Key, $TexW, $TexH, $CellW, $CellH, $Cols, $Pad,
        [Math]::Round($capTop, 2).ToString($inv), [Math]::Round($baseline, 2).ToString($inv),
        [Math]::Round($capH * 0.42, 2).ToString($inv), [Math]::Round($capH * $f.Tracking, 2).ToString($inv), $w))

    Write-Host ("{0}: em {1:N1}px, tinggi huruf kapital {2:N1}px" -f $f.Key, $em, $capH)
}

[System.IO.File]::WriteAllText((Join-Path $Root 'shared\fonts.lua'), $lua.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Selesai.'
