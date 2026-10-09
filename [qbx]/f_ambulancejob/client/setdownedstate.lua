-- Teks 2D (countdown respawn / bleed out / "tekan G panggil EMS") sudah diganti UI f_deathscreen.
-- Di sini tinggal menjaga animasi mati tetap terpasang.

---@param ped number
local function playDeadAnimation(ped)
    if IsInHospitalBed then
        if not IsEntityPlayingAnim(ped, InBedDict, InBedAnim, 3) then
            lib.playAnim(ped, InBedDict, InBedAnim, 1.0, 1.0, -1, 1, 0, false, false, false)
        end
    else
        exports.f_medical:PlayDeadAnimation()
    end
end

---Set dead state animation.
CreateThread(function()
    while true do
        if exports.f_medical:IsDead() then
            playDeadAnimation(cache.ped)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
