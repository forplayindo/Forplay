-- Rekening ORGANISASI untuk app Bank di tablet (sd-tablet, device profile `orgBank = true`).
--
-- Aturan, semuanya ditegakkan di server (UI hanya menyembunyikan tombol):
--   - Semua anggota job aktif boleh MELIHAT saldo + riwayat transaksi rekening job-nya.
--   - Hanya grade dengan flag `isboss` (qbx_core/shared/jobs.lua) yang boleh MENGIRIM uang.
--   - Job & identitas selalu dibaca dari source, tidak pernah dari payload.
-- Uang & riwayat dibaca dari f_banking (rekening job = id job, mis. 'police').

---@type table f_phone config root (configs/config.lua).
local config  = require 'configs.config'
---@type table Company money across providers (bridge.server.society).
local society = require 'bridge.server.society'
---@type table Personal bank adapter (bridge.server.banking): credit the recipient.
local bank    = require 'bridge.server.banking'
---@type table Job bridge (bridge.server.job): active job, label, isboss.
local job     = require 'bridge.server.job'
---@type table Player bridge (bridge.server.player): citizenid/name/source lookups.
local player  = require 'bridge.server.player'
---@type table Settings store (server.settings.store): phone number <-> citizenid.
local settings = require 'server.settings.store'
---@type table Personal Wallet handlers (server.banking.actions): addExternal for the recipient's log.
local actions = require 'server.banking.actions'
---@type table Shared server helpers (server.util).
local util    = require 'server.util'

local BK = config.Banking or {}

local org = {}

---@type integer Transaksi yang dikirim ke UI (terbaru dulu).
local TX_LIMIT = 100
---@type integer Rate limit transfer organisasi per boss.
local SEND_WINDOW, SEND_MAX = 60000, 10
---@type table<string, boolean> Job yang tidak punya rekening organisasi.
local NO_ACCOUNT = { unemployed = true }

local RB = 'f_banking'

local function fail(key, msg) return { success = false, messageKey = key, message = msg } end

---@return string iso UTC ISO-8601 timestamp dari unix seconds
local function iso(ts) return os.date('!%Y-%m-%dT%H:%M:%SZ', tonumber(ts) or os.time()) end

---Konteks pemanggil: job aktif yang punya rekening organisasi, atau nil + alasan penolakan.
---@param src integer
---@return table|nil ctx { cid, job, label, isBoss }
---@return table|nil refusal
local function context(src)
    local cid = player.getIdentifier(src)
    if not cid then return nil, fail('orgbank.playerNotFound', 'Pemain tidak ditemukan') end
    local myJob = job.getName(src)
    if not myJob or NO_ACCOUNT[myJob] then return nil, fail('orgbank.noJob', 'Kamu tidak berada di organisasi') end
    if not society.available() then return nil, fail('orgbank.noProvider', 'Rekening organisasi tidak tersedia') end
    return {
        cid    = cid,
        job    = myJob,
        label  = job.getLabel(myJob) or myJob,
        isBoss = job.isBoss(src, myJob, 0) == true,
    }
end

---Riwayat f_banking -> bentuk BankTx yang dipakai UI Wallet.
---@param jobName string
---@return table[]
local function transactionsOf(jobName)
    if GetResourceState(RB) ~= 'started' then return {} end
    local ok, rows = pcall(function() return exports[RB]:getAccountTransactions(jobName) end)
    if not ok or type(rows) ~= 'table' then return {} end

    local out = {}
    for i = 1, math.min(#rows, TX_LIMIT) do
        local r = rows[i]
        if type(r) == 'table' then
            local incoming = r.trans_type == 'deposit'
            local amount   = math.abs(tonumber(r.amount) or 0)
            local peer     = incoming and r.issuer or r.receiver
            local msg      = type(r.message) == 'string' and r.message or ''
            local label    = tostring(peer or r.title or 'Transaksi')
            if msg ~= '' then label = ('%s — %s'):format(label, msg:sub(1, 60)) end
            out[#out + 1] = {
                id       = tostring(r.trans_id or ('rb' .. i)),
                merchant = label,
                amount   = incoming and amount or -amount,
                category = incoming and 'income' or 'transfer',
                date     = iso(r.time),
            }
        end
    end
    return out
end

---Semua pemain online dengan job aktif `jobName`.
---@param jobName string
---@return integer[]
local function onlineMembers(jobName)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if s and job.getName(s) == jobName then out[#out + 1] = s end
    end
    return out
end

---Saldo + riwayat rekening organisasi pemanggil.
---@param src integer
function org.overview(src)
    local ctx, refusal = context(src)
    if not ctx then return refusal end
    return {
        success = true,
        data = {
            job          = ctx.job,
            label        = ctx.label,
            balance      = society.getBalance(ctx.job) or 0,
            canTransfer  = ctx.isBoss,
            transactions = transactionsOf(ctx.job),
        },
    }
end

---Kirim uang DARI rekening organisasi ke rekening pribadi seorang pemain (nomor HP atau server ID).
---Hanya boss. Debit organisasi dulu, lalu kredit penerima; gagal kredit = refund ke organisasi.
---@param src integer
---@param payload table { number?: string, serverId?: number, amount: number, note?: string }
function org.send(src, payload)
    local ctx, refusal = context(src)
    if not ctx then return refusal end
    if not ctx.isBoss then return fail('orgbank.bossOnly', 'Hanya pimpinan organisasi yang bisa mengirim uang') end
    payload = type(payload) == 'table' and payload or {}

    local amount = tonumber(payload.amount) or 0
    if not util.finite(amount) then return fail('banking.enterValidAmount', 'Enter a valid amount') end
    amount = math.floor(amount)
    if amount < (BK.MinSend or 1)         then return fail('banking.enterValidAmount', 'Enter a valid amount') end
    if amount > (BK.MaxSend or math.huge) then return fail('banking.amountTooLarge', 'Amount is too large') end
    local note = (tostring(payload.note or ''):gsub('^%s+', ''):gsub('%s+$', '')):sub(1, 80)

    -- Penerima: sama seperti transfer pribadi (server ID atau nomor HP).
    local rcid
    local serverId = tonumber(payload.serverId)
    if serverId and util.finite(serverId) then
        serverId = math.floor(serverId)
        if serverId <= 0 or serverId > 65535 then return fail('banking.noPlayerWithServerId', 'No player with that server ID') end
        rcid = player.getIdentifier(serverId)
        if not rcid then return fail('banking.noPlayerWithServerId', 'No player with that server ID') end
    else
        local number = util.digits(payload.number)
        if number == '' then return fail('banking.enterRecipientNumber', 'Enter a recipient number') end
        rcid = settings.getCitizenByNumber(number)
        if not rcid then return fail('banking.noOneOwnsNumber', 'No one owns that number') end
    end

    if not util.rateLimit(ctx.cid, 'orgbank:send', SEND_WINDOW, SEND_MAX) then
        return fail('banking.tooManyTransfersTryAgain', 'Too many transfers, try again in a minute')
    end

    local rsrc = player.getSourceByIdentifier(rcid)
    if not rsrc and not (BK.AllowOffline and bank.balanceIsFramework()) then
        return fail('banking.recipientOffline', 'Recipient is offline')
    end

    if (society.getBalance(ctx.job) or 0) < amount then
        return fail('orgbank.insufficient', 'Saldo organisasi tidak cukup')
    end

    local reason = ('Transfer %s'):format(ctx.label)
    if not society.removeMoney(ctx.job, amount, reason) then
        return fail('orgbank.debitFailed', 'Tidak bisa mengambil dari rekening organisasi')
    end

    local credited
    if rsrc then credited = bank.addMoney(rsrc, amount, reason) else credited = bank.addOffline(rcid, amount) end
    if not credited then
        society.addMoney(ctx.job, amount, 'Refund transfer gagal')
        return fail('banking.couldNotReachRecipient', 'Could not reach the recipient')
    end

    local senderName = player.getName(src) or ctx.cid
    local rname = (rsrc and player.getName(rsrc)) or rcid
    local message = note ~= '' and note or ('Dikirim oleh %s'):format(senderName)

    -- Riwayat rekening organisasi (f_banking) - tercatat siapa boss yang mengirim.
    if GetResourceState(RB) == 'started' then
        pcall(function()
            exports[RB]:handleTransaction(ctx.job, ('%s / %s'):format(ctx.label, ctx.job), amount,
                ('%s (oleh %s)'):format(message, senderName), ctx.label, rname, 'withdraw')
        end)
    end

    -- Riwayat Wallet pribadi penerima + banner di HP-nya.
    actions.addExternal(rcid, {
        label    = ('Dari %s'):format(ctx.label),
        amount   = amount,
        category = 'income',
        notify   = ('%s mengirim %s'):format(ctx.label, actions.formatMoney(amount)),
    })

    -- Semua anggota online: refresh tampilan + banner organisasi (lolos filter tablet via org = true).
    local members = onlineMembers(ctx.job)
    util.pushMany('f_phone:client:orgBankChanged', members, {})
    util.pushMany('f_phone:client:notify', members, {
        app = 'bank', appId = 'bank', org = true, time = 'now',
        title = ctx.label,
        body  = ('-%s ke %s (oleh %s)'):format(actions.formatMoney(amount), rname, senderName),
    })

    return {
        success = true,
        data = {
            balance = society.getBalance(ctx.job) or 0,
            transaction = {
                id = 'new', merchant = rname, amount = -amount,
                category = 'transfer', date = iso(os.time()),
            },
        },
    }
end

return org
