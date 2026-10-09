-- Item obat yang efeknya diputuskan server (ox_inventory server export).

local CALM = {
    min = 25, max = 35,   -- stress turun
    cooldown = 5 * 60,    -- detik antar minum
}

---@type table<string, integer> citizenid -> os.time() minum terakhir
local lastCalm = {}

---Calming Pills. 'usingItem' = boleh dipakai? (cooldown), 'usedItem' = item sudah terpotong -> efek.
exports('calmPills', function(event, _, inventory)
    local src = inventory and inventory.id
    local player = type(src) == 'number' and exports.qbx_core:GetPlayer(src)
    if not player then return false end
    local cid = player.PlayerData.citizenid

    if event == 'usingItem' then
        local wait = (lastCalm[cid] or 0) + CALM.cooldown - os.time()
        if wait > 0 then
            exports.qbx_core:Notify(src, ('Tunggu %d menit lagi sebelum minum obat penenang lagi.'):format(math.ceil(wait / 60)), 'error')
            return false
        end
        return
    end

    if event == 'usedItem' then
        lastCalm[cid] = os.time()
        local state = Player(src).state
        local stress = math.max(0, (tonumber(state.stress) or 0) - math.random(CALM.min, CALM.max))
        state:set('stress', stress, true)
        player.Functions.SetMetaData('stress', stress)
        TriggerClientEvent('f_ambulancejob:client:calmEffect', src)
    end
end)
