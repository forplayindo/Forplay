-- Panel hologram e-toll (DUI + DrawSpritePoly) seperti di ox_fuel, selalu menghadap kamera.
-- Hanya terlihat oleh pemain yang tap. Browser DUI hanya hidup selama panel tampil.
local display = {}

local TXD = 'f_toll_holo'
local WIDTH, HEIGHT = 0.62, 0.36 -- ukuran panel (m), rasio sama dengan DUI 512x300
local LOAD_GRACE = 750 -- ms setelah DUI tersedia sebelum dianggap halaman sudah termuat

local dui, txd, tex
local count = 0
local createdAt = 0
local synced = false
local lastData
local pos
local hideAt
local follow -- { entity, offset }: panel ikut kendaraan
local drawing = false

local function ensureDui()
	if dui then return end
	txd = txd or CreateRuntimeTxd(TXD)
	count += 1
	tex = ('screen%d'):format(count)
	dui = CreateDui(('nui://%s/html/hologram.html'):format(cache.resource), 512, 300)
	CreateRuntimeTextureFromDuiHandle(txd, tex, GetDuiHandle(dui))
	createdAt, synced = GetGameTimer(), false
end

local function destroyDui()
	if not dui then return end
	DestroyDui(dui)
	dui = nil
end

local function loaded()
	return dui and IsDuiAvailable(dui) and GetGameTimer() - createdAt >= LOAD_GRACE
end

local function tri(a, b, c, ua, va, ub, vb, uc, vc)
	DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, TXD, tex,
		ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

local function drawPanel()
	if follow then
		if not DoesEntityExist(follow.entity) then return end
		pos = GetOffsetFromEntityInWorldCoords(follow.entity, follow.offset.x, follow.offset.y, follow.offset.z)
	end
	local yaw = math.rad(GetFinalRenderedCamRot(2).z)
	local right = vec3(math.cos(yaw), math.sin(yaw), 0.0) * (WIDTH / 2)
	local up = vec3(0.0, 0.0, HEIGHT / 2)
	local tl, tr, br, bl = pos - right + up, pos + right + up, pos + right - up, pos - right - up

	-- dua arah winding (poly GTA hanya satu sisi)
	tri(tl, tr, br, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0)
	tri(tl, br, bl, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0)
	tri(tl, br, tr, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0)
	tri(tl, bl, br, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0)
end

---@param at vector3 | { entity: number, offset: vector3 } titik tengah panel, atau ikut entity
---@param data table isi panel (lihat html/hologram.html)
---@param duration number ms
function display.show(at, data, duration)
	ensureDui()
	if type(at) == 'table' and at.entity then
		follow = at
		pos = GetOffsetFromEntityInWorldCoords(at.entity, at.offset.x, at.offset.y, at.offset.z)
	else
		follow, pos = nil, at
	end
	hideAt = GetGameTimer() + duration
	lastData = json.encode(data)
	if loaded() then
		SendDuiMessage(dui, lastData)
		synced = true
	else
		synced = false
	end

	if drawing then return end
	drawing = true

	CreateThread(function()
		while pos and GetGameTimer() < hideAt do
			if loaded() then
				if not synced and lastData then
					SendDuiMessage(dui, lastData)
					synced = true
				end
				drawPanel()
			end
			Wait(0)
		end
		if not loaded() then print(('[f_toll] hologram tidak termuat (dui=%s, tersedia=%s)'):format(dui, dui and IsDuiAvailable(dui))) end
		pos, follow, drawing = nil, nil, false
		destroyDui()
	end)
end

AddEventHandler('onResourceStop', function(resource)
	if resource == cache.resource then destroyDui() end
end)

return display
