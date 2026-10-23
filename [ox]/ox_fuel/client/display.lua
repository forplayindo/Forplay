-- Panel hologram proses pengisian (DUI + DrawSpritePoly), selalu menghadap kamera.
-- Hanya terlihat oleh player yang sedang mengisi.
-- Browser DUI hanya hidup selama player memegang selang / hologram tampil (hemat RAM/CPU client).
local display = {}

local TXD = 'ox_fuel_holo'
local WIDTH, HEIGHT = 0.62, 0.36 -- ukuran panel (m), rasio sama dengan DUI 512x300
local LOAD_GRACE = 750 -- ms setelah DUI tersedia sebelum dianggap halaman sudah termuat

local dui
local txd -- runtime txd dibuat sekali; tiap DUI baru dapat nama texture baru
local tex
local count = 0
local createdAt = 0
local synced = false -- data terakhir sudah dikirim ke halaman yang sudah termuat
local lastData
local keep = false -- player masih memegang selang: jangan hapus DUI setelah hologram hilang
local pos -- titik tengah panel
local hideAt -- GetGameTimer() kapan panel disembunyikan (nil = tampil terus)
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

---Halaman sudah siap ditampilkan (bukan kotak kosong)
local function loaded()
	return dui and IsDuiAvailable(dui) and GetGameTimer() - createdAt >= LOAD_GRACE
end

local function tri(a, b, c, ua, va, ub, vb, uc, vc)
	DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, TXD, tex,
		ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

local function drawPanel()
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

---Siapkan browser lebih awal (saat ambil selang) supaya hologram langsung tampil berisi
function display.prepare()
	keep = true
	ensureDui()
end

---Selang dikembalikan: browser boleh dihapus (langsung, atau setelah hologram selesai)
function display.release()
	keep = false
	if not drawing then destroyDui() end
end

---@param at vector3 titik tengah panel
function display.show(at)
	ensureDui()
	pos, hideAt = at, nil

	if drawing then return end
	drawing = true

	CreateThread(function()
		while pos and not (hideAt and GetGameTimer() >= hideAt) do
			-- digambar hanya setelah halaman termuat; data terakhir dikirim ulang sekali saat siap
			if loaded() then
				if not synced and lastData then
					SendDuiMessage(dui, lastData)
					synced = true
				end
				drawPanel()
			end
			Wait(0)
		end

		pos, drawing = nil, false
		if not keep then destroyDui() end
	end)
end

---@param data { title?: string, label?: string, unit?: string, liters: number, total: number, percent: number, status: string, state?: 'done' | 'warn' }
function display.update(data)
	lastData = json.encode(data)
	if dui and loaded() then
		SendDuiMessage(dui, lastData)
		synced = true
	end
end

---@param delay? number ms
function display.hide(delay)
	hideAt = GetGameTimer() + (delay or 0)
end

AddEventHandler('onResourceStop', function(resource)
	if resource == cache.resource then destroyDui() end
end)

return display
