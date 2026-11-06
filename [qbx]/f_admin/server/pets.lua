-- Pengajuan kepemilikan hewan dari f_petshop. Hanya Admin & Owner (Support tidak bisa).
-- Data & penyimpanan tetap di f_petshop (exports GetPetRequests / DecidePetRequest).

local function canApprove(src)
    local role = GetRole(src)
    return role == 'owner' or role == 'admin'
end

Handle('pets', false, function(src)
    if not canApprove(src) then return { ok = false, msg = 'Khusus Admin & Owner.' } end
    if GetResourceState('f_petshop') ~= 'started' then return { ok = false, msg = 'f_petshop tidak berjalan.' } end
    local rows, max = exports.f_petshop:GetPetRequests()
    for _, r in ipairs(rows) do r.when = os.date('%d/%m %H:%M', r.created) end
    return { ok = true, requests = rows, max = max }
end)

Handle('pets_decide', false, function(src, d)
    if not canApprove(src) then return { ok = false, msg = 'Khusus Admin & Owner.' } end
    if GetResourceState('f_petshop') ~= 'started' then return { ok = false, msg = 'f_petshop tidak berjalan.' } end
    local approve = d.approve == true
    local ok, msg = exports.f_petshop:DecidePetRequest(tonumber(d.id), approve, CharName(src))
    if ok then Log(src, 'pet', (approve and 'menyetujui' or 'menolak') .. ' pengajuan hewan: ' .. msg) end
    return { ok = ok, msg = msg }
end)

-- jumlah pengajuan menunggu (untuk badge di menu)
function PendingPetCount()
    if GetResourceState('f_petshop') ~= 'started' then return 0 end
    local ok, rows = pcall(function() return exports.f_petshop:GetPetRequests() end)
    return ok and rows and #rows or 0
end
