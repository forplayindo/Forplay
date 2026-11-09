---------------------------------------------------------------------------
-- Definisi field handling yang bisa diedit (satu sumber untuk server, client, NUI).
--
--   key   nama tag di handling.meta (vektor ditulis 'vecXxx.x' / '.y' / '.z')
--   min/max/step  batas slider DAN batas yang dipaksa server (anti nilai ekstrem)
--   kind  'live'    langsung terasa di mobil yang sedang dikendarai
--         'spawn'   baru terasa setelah mobil di-spawn ulang (fisik dibuat saat spawn)
--         'restart' hanya ditulis ke handling.meta, terasa setelah restart server
--                   (game menyimpan pasangan depan/belakang yang tidak bisa diubah native)
--   conv  pengubah satuan meta -> memori game untuk Set*HandlingFloat:
--         angka = dikali, 'rad' = derajat ke radian. Cek dengan /handlingcek.
--   int   true = SetHandlingInt
---------------------------------------------------------------------------
return {
    { id = 'engine', label = 'Mesin & Kecepatan', fields = {
        { key = 'fInitialDriveForce', label = 'Tenaga mesin', hint = 'Akselerasi. 0,1 truk · 0,3 sport · 0,4+ super', min = 0.01, max = 1.0, step = 0.005, kind = 'live', conv = 1 },
        { key = 'fInitialDriveMaxFlatVel', label = 'Batas kecepatan', hint = 'Kecepatan maks gigi tertinggi (km/j, perkiraan)', min = 40, max = 300, step = 1, kind = 'live', conv = 1 / 3.6 },
        { key = 'fDriveInertia', label = 'Respons gas', hint = 'Seberapa cepat RPM naik saat gas diinjak', min = 0.1, max = 2.0, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fClutchChangeRateScaleUpShift', label = 'Oper gigi naik', hint = 'Makin besar = naik gigi makin cepat', min = 0.5, max = 10, step = 0.1, kind = 'live', conv = 1 },
        { key = 'fClutchChangeRateScaleDownShift', label = 'Oper gigi turun', hint = 'Makin besar = turun gigi makin cepat', min = 0.5, max = 10, step = 0.1, kind = 'live', conv = 1 },
        { key = 'fInitialDragCoeff', label = 'Hambatan angin', hint = 'Makin besar = top speed makin tertahan', min = 0, max = 30, step = 0.1, kind = 'live', conv = 0.0001 },
        { key = 'nInitialDriveGears', label = 'Jumlah gigi', hint = '1 sampai 8 percepatan', min = 1, max = 8, step = 1, kind = 'spawn', int = true },
        { key = 'fDriveBiasFront', label = 'Penggerak roda', hint = '0 = belakang (RWD) · 0,5 = 4WD · 1 = depan (FWD)', min = 0, max = 1, step = 0.05, kind = 'restart' },
    } },
    { id = 'brake', label = 'Rem', fields = {
        { key = 'fBrakeForce', label = 'Kekuatan rem', hint = 'Daya pengereman utama', min = 0.05, max = 3, step = 0.01, kind = 'live', conv = 1 },
        { key = 'fHandBrakeForce', label = 'Rem tangan', hint = 'Kekuatan rem tangan (drift)', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fBrakeBiasFront', label = 'Bobot rem depan', hint = '0,5 = rata · lebih besar = depan lebih kuat', min = 0, max = 1, step = 0.01, kind = 'restart' },
    } },
    { id = 'tyre', label = 'Ban & Setir', fields = {
        { key = 'fTractionCurveMax', label = 'Grip maksimal', hint = 'Daya cengkeram ban di tikungan', min = 0.5, max = 4, step = 0.01, kind = 'live', conv = 1 },
        { key = 'fTractionCurveMin', label = 'Grip saat selip', hint = 'Grip ketika ban sudah slip', min = 0.5, max = 4, step = 0.01, kind = 'live', conv = 1 },
        { key = 'fTractionCurveLateral', label = 'Sudut selip', hint = 'Derajat sebelum ban kehilangan grip', min = 5, max = 35, step = 0.5, kind = 'live', conv = 'rad' },
        { key = 'fLowSpeedTractionLossMult', label = 'Ban spin saat start', hint = '0 = tidak spin · 1+ = burnout', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fTractionLossMult', label = 'Licin di off-road', hint = 'Grip hilang di tanah / rumput', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fSteeringLock', label = 'Sudut setir', hint = 'Derajat belok roda depan', min = 10, max = 75, step = 0.5, kind = 'live', conv = 'rad' },
        { key = 'fTractionBiasFront', label = 'Grip depan vs belakang', hint = '< 0,5 = belakang lebih lengket', min = 0.1, max = 0.9, step = 0.01, kind = 'restart' },
    } },
    { id = 'susp', label = 'Suspensi', fields = {
        { key = 'fSuspensionForce', label = 'Kekerasan per', hint = 'Makin besar = suspensi makin keras', min = 0.5, max = 5, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fSuspensionCompDamp', label = 'Redaman tekan', hint = 'Peredam saat suspensi tertekan', min = 0.1, max = 3, step = 0.05, kind = 'live', conv = 0.1 },
        { key = 'fSuspensionReboundDamp', label = 'Redaman pantul', hint = 'Peredam saat suspensi kembali', min = 0.1, max = 3, step = 0.05, kind = 'live', conv = 0.1 },
        { key = 'fSuspensionUpperLimit', label = 'Batas atas', hint = 'Jarak maks suspensi naik (m)', min = 0, max = 0.5, step = 0.005, kind = 'live', conv = 1 },
        { key = 'fSuspensionLowerLimit', label = 'Batas bawah', hint = 'Jarak maks suspensi turun (m)', min = -0.5, max = 0, step = 0.005, kind = 'live', conv = 1 },
        { key = 'fSuspensionRaise', label = 'Tinggi bodi', hint = 'Negatif = ceper · positif = naik (m)', min = -0.2, max = 0.2, step = 0.005, kind = 'live', conv = 1 },
        { key = 'fAntiRollBarForce', label = 'Anti-roll bar', hint = 'Kurangi bodi miring di tikungan', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fSuspensionBiasFront', label = 'Bobot per depan', hint = '0,5 = rata', min = 0, max = 1, step = 0.01, kind = 'restart' },
        { key = 'fAntiRollBarBiasFront', label = 'Anti-roll depan', hint = '0,5 = rata', min = 0, max = 1, step = 0.01, kind = 'restart' },
    } },
    { id = 'body', label = 'Bodi & Berat', fields = {
        { key = 'fMass', label = 'Berat', hint = 'Kilogram. Pengaruh ke tabrakan & akselerasi', min = 300, max = 30000, step = 50, kind = 'spawn', conv = 1 },
        { key = 'vecCentreOfMassOffset.x', label = 'Titik berat kiri/kanan', hint = 'Geser pusat massa (m)', min = -1, max = 1, step = 0.01, kind = 'spawn', conv = 1 },
        { key = 'vecCentreOfMassOffset.y', label = 'Titik berat depan/belakang', hint = 'Negatif = lebih berat di belakang', min = -2, max = 2, step = 0.01, kind = 'spawn', conv = 1 },
        { key = 'vecCentreOfMassOffset.z', label = 'Titik berat atas/bawah', hint = 'Negatif = lebih stabil, susah terguling', min = -1, max = 1, step = 0.01, kind = 'spawn', conv = 1 },
        { key = 'fPercentSubmerged', label = 'Daya apung', hint = '% tenggelam sebelum mengapung', min = 10, max = 100, step = 1, kind = 'restart' },
    } },
    { id = 'damage', label = 'Kerusakan', fields = {
        { key = 'fCollisionDamageMult', label = 'Kerusakan tabrakan', hint = 'Pengali damage saat menabrak', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fDeformationDamageMult', label = 'Penyok bodi', hint = 'Seberapa mudah bodi penyok', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fEngineDamageMult', label = 'Kerusakan mesin', hint = 'Pengali damage ke mesin', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
        { key = 'fWeaponDamageMult', label = 'Kerusakan tembakan', hint = 'Pengali damage dari senjata', min = 0, max = 3, step = 0.05, kind = 'live', conv = 1 },
    } },
}
