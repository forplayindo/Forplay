# Konversi file GTA <-> XML lewat CodeWalker.Core
# cw.ps1 export <file.ydr|ytyp|ymap> <outDir>
# cw.ps1 import <file.ydr.xml|...> <outFile>   (folder xml = folder tekstur .dds)
param([string]$mode, [string]$inPath, [string]$outPath)
$ErrorActionPreference = 'Stop'
$cwDir = 'C:\Users\GTA\Documents\_\CodeWalker30_dev46'
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\SharpDX.dll")
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\SharpDX.Mathematics.dll")
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\CodeWalker.Core.dll")
if ($mode -eq 'export') {
    $data = [System.IO.File]::ReadAllBytes($inPath)
    $ref = [ref]$data
    $entry = [CodeWalker.GameFiles.RpfFile]::CreateResourceFileEntry($ref, 0)
    $data = [CodeWalker.GameFiles.ResourceBuilder]::Decompress($ref.Value)
    $entry.Name = [System.IO.Path]::GetFileName($inPath)
    $entry.NameLower = $entry.Name.ToLowerInvariant()
    New-Item -ItemType Directory -Force $outPath | Out-Null
    $fn = ''
    $xml = [CodeWalker.GameFiles.MetaXml]::GetXml($entry, $data, [ref]$fn, $outPath)
    [System.IO.File]::WriteAllText((Join-Path $outPath $fn), $xml)
    "exported $fn"
} elseif ($mode -eq 'import') {
    $doc = New-Object System.Xml.XmlDocument
    $doc.Load($inPath)
    $trim = 0
    $fmt = [CodeWalker.GameFiles.XmlMeta]::GetXMLFormat($inPath.ToLowerInvariant(), [ref]$trim)
    $bytes = [CodeWalker.GameFiles.XmlMeta]::GetData($doc, $fmt, [System.IO.Path]::GetDirectoryName($inPath))
    if (-not $bytes) { throw "import gagal ($fmt)" }
    [System.IO.File]::WriteAllBytes($outPath, $bytes)
    "imported $fmt -> $outPath ($($bytes.Length) bytes)"
}
