-- Menu kecil isi bensin (NUI): jenis BBM, jumlah liter, Cash/Transfer
local menu = {}
local pending

local function resolve(value)
	SetNuiFocus(false, false)
	if not pending then return end

	local p = pending
	pending = nil
	p:resolve(value)
end

RegisterNUICallback('confirm', function(body, cb)
	cb(1)
	resolve(body)
end)

RegisterNUICallback('close', function(_, cb)
	cb(1)
	resolve(false)
end)

---@param data table hasil callback ox_fuel:quote
---@return { type: string, liters: number, method: 'cash' | 'bank' } | false
function menu.open(data)
	resolve(false)

	local p = promise.new()
	pending = p

	SetNuiFocus(true, true)
	SendNUIMessage({ action = 'open', data = data })

	return Citizen.Await(p)
end

AddEventHandler('onResourceStop', function(resource)
	if resource == cache.resource and pending then SetNuiFocus(false, false) end
end)

return menu
