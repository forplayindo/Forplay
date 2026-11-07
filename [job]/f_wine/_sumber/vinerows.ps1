$ErrorActionPreference = 'Stop'
$cwDir = 'C:\Users\GTA\Documents\_\CodeWalker30_dev46'
$gta = 'C:\Program Files (x86)\Steam\steamapps\common\Grand Theft Auto V'
$outDir = $args[0]
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\SharpDX.dll")
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\SharpDX.Mathematics.dll")
[void][System.Reflection.Assembly]::LoadFrom("$cwDir\CodeWalker.Core.dll")
[CodeWalker.GameFiles.GTA5Keys]::LoadFromPath($gta, $null)
$mgr = New-Object CodeWalker.GameFiles.RpfManager
$mgr.Init($gta, [Action[string]]{ param($s) }, [Action[string]]{ param($s) }, $false, $true)
$m = [CodeWalker.GameFiles.RpfManager].GetMethods() | Where-Object { $_.Name -eq 'GetFile' -and $_.IsGenericMethod -and $_.GetParameters()[0].ParameterType.Name -eq 'RpfEntry' }
$gYmap = $m.MakeGenericMethod([CodeWalker.GameFiles.YmapFile])
$gYdr = $m.MakeGenericMethod([CodeWalker.GameFiles.YdrFile])
$rows = New-Object System.Collections.Generic.List[string]
$ydrs = @{}
foreach ($rpf in $mgr.AllRpfs) {
    if ($rpf.Path -notlike '*cityhills_01*') { continue }
    foreach ($e in $rpf.AllEntries) {
        $n = $e.NameLower
        if ($n -match '^ch1_(04b|05|09b)_vinegrapes_.*\.ydr$' -and $rpf.Path -notlike 'update*') { $ydrs[$n] = $e }
        if ($n -like '*.ymap' -and $n -match '^ch1_(04b|05|09b)') {
            $y = $gYmap.Invoke($mgr, @($e))
            if (-not $y -or -not $y.AllEntities) { continue }
            foreach ($ent in $y.AllEntities) {
                $an = [string]$ent._CEntityDef.archetypeName
                if ($an -match 'vinegrapes') {
                    $p = $ent.Position; $q = $ent.Orientation
                    $rows.Add(("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}" -f $e.Name, $an, $p.X, $p.Y, $p.Z, $q.X, $q.Y, $q.Z, $q.W, $ent._CEntityDef.lodDist))
                }
            }
        }
    }
}
[System.IO.File]::WriteAllLines("$outDir\rows.txt", $rows)
$bb = New-Object System.Collections.Generic.List[string]
foreach ($k in $ydrs.Keys) {
    $d = $gYdr.Invoke($mgr, @($ydrs[$k]))
    if (-not $d -or -not $d.Drawable) { continue }
    $dr = $d.Drawable
    $bb.Add(("{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f $k.Replace('.ydr',''), $dr.BoundingBoxMin.X, $dr.BoundingBoxMin.Y, $dr.BoundingBoxMin.Z, $dr.BoundingBoxMax.X, $dr.BoundingBoxMax.Y, $dr.BoundingBoxMax.Z))
}
[System.IO.File]::WriteAllLines("$outDir\bbox.txt", $bb)
# export 2 contoh ydr ke xml untuk analisa daun
$i = 0
New-Item -ItemType Directory -Force "$outDir\xml" | Out-Null
foreach ($k in $ydrs.Keys) {
    if (-not $ydrs[$k]) { continue }
    $data = $ydrs[$k].File.ExtractFile($ydrs[$k])
    $fn = ''
    $xml = [CodeWalker.GameFiles.MetaXml]::GetXml($ydrs[$k], $data, [ref]$fn, "$outDir\xml")
    New-Item -ItemType Directory -Force "$outDir\xml" | Out-Null
    [System.IO.File]::WriteAllText("$outDir\xml\$fn", $xml)
}
"rows $($rows.Count) ydr $($ydrs.Count)"
