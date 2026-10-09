---@type table f_phone config root (configs/config.lua); read for the booking caps.
local config    = require 'configs.config'
---@type table Shared server helpers (server.util): envelopes, clamping, TINYINT reads.
local util      = require 'server.util'
---@type table Player bridge (bridge.server.player): the suspect's live server id.
local player    = require 'bridge.server.player'
---@type table Money bridge (bridge.server.money): the accounts a citation is debited from.
local money     = require 'bridge.server.money'
---@type table Jail bridge (bridge.server.jail): prison detection and the sentence call.
local prison    = require 'bridge.server.jail'
---@type table MDT persistence (server.mdt.store): the ref allocator and name hydration.
local store     = require 'server.mdt.store'
---@type table MDT permissions (server.mdt.access): the read gate and the audited write wrapper.
local access    = require 'server.mdt.access'
---@type table Penal code (server.mdt.offences): the only place a sentence or fine is calculated.
local offences  = require 'server.mdt.offences'
---@type table Reports and cases (server.mdt.paperwork): the suspect-charge lookup a booking reads.
local paperwork = require 'server.mdt.paperwork'

---@type table Jail module; the table returned at end of file. Sentences and citations are derived
---from the report's own charge lines, and the enforcement ledger is claimed before anything is
---applied so one report can never book the same suspect twice.
local jail = {}

---@type table MDT config (configs/mdt.lua).
local MDT = config.Mdt

---@type table Booking settings (configs/mdt.lua Jail).
local J = MDT.Jail or {}

---@type integer Hard ceiling on a single citation, whatever the charges total.
local MAX_FINE = math.max(0, math.floor(tonumber(J.MaxFine) or 25000))

---@type integer Most an officer may cut from a sentence at booking.
local MAX_REDUCTION = math.max(0, math.floor(tonumber(J.MaxReductionMonths) or 0))

---@type integer Most an officer may cut from a citation at booking.
local MAX_FINE_REDUCTION = math.max(0, math.floor(tonumber(J.MaxFineReduction) or 0))

---@type integer Hard ceiling on a single sentence.
local MAX_MONTHS = math.max(1, math.floor(tonumber(J.MaxMonths) or 240))

---@type string Account a citation is debited from before cash is touched.
local ACCOUNT = type(J.JailAccount) == 'string' and J.JailAccount or 'bank'

---@type integer Rows returned per page.
local PAGE_SIZE = math.floor(tonumber((MDT.Paging or {}).PageSize) or 25)

---@type integer Highest page a client may ask for.
local MAX_PAGE = math.floor(tonumber((MDT.Paging or {}).MaxPage) or 400)

---Coerces a client page number to a whole page inside the served range.
---@param v any
---@return integer page 1..MAX_PAGE
local function pageOf(v)
    local n = tonumber(v)
    if not util.finite(n) or n ~= math.floor(n) or n < 1 then return 1 end
    return n > MAX_PAGE and MAX_PAGE or n
end

---Escapes the LIKE wildcards in a search term.
---@param term string
---@return string
local function likeSafe(term)
    return (term:gsub('([%%_\\])', '\\%1'))
end

---Decodes a stored charge blob back into charge lines.
---@param raw any stored JSON text
---@return table[] charges
local function decodeCharges(raw)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return {} end
    return decoded
end

---The arrest payload shape, shared by the log and the detail pane.
---@param row table DB row
---@return table arrest
local function shapeOf(row)
    return {
        ref             = row.ref,
        reportRef       = row.report_ref,
        citizenid       = row.citizenid,
        subject         = (row.subject_name and row.subject_name ~= '') and row.subject_name or row.citizenid,
        officer         = row.officer_name or '',
        officerCid      = row.officer_cid,
        callsign        = (row.officer_callsign and row.officer_callsign ~= '') and row.officer_callsign or nil,
        charges         = decodeCharges(row.charges),
        months          = tonumber(row.months) or 0,
        fine            = tonumber(row.fine) or 0,
        jailed          = util.truthy(row.jailed),
        fined           = util.truthy(row.fined),
        status          = row.status or 'served',
        servedAt        = tonumber(row.served_at),
        servedBy        = row.served_by,
        cancelledBy     = row.cancelled_by,
        createdAt       = tonumber(row.created_at) or 0,
    }
end

---The enforcement ledger for a (report, suspect) pair, defaulted when nothing is booked yet.
---@param reportRef string
---@param citizenid string
---@return boolean jailed
---@return boolean fined
local function ledger(reportRef, citizenid)
    local row = MySQL.single.await(
        'SELECT jailed, fined FROM phone_mdt_enforcement WHERE report_ref = ? AND citizenid = ? LIMIT 1',
        { reportRef, citizenid })
    if not row then return false, false end
    return util.truthy(row.jailed), util.truthy(row.fined)
end

---Claims the ledger BEFORE anything is applied, so two officers booking the same suspect at the
---same moment cannot both succeed. False when the pair is already enforced for what was asked.
---@param reportRef string
---@param citizenid string
---@param wantJail boolean
---@param wantFine boolean
---@return boolean claimed
local function claim(reportRef, citizenid, wantJail, wantFine)
    local wantsJail = wantJail and 1 or 0
    local wantsFine = wantFine and 1 or 0
    local now = os.time()

    MySQL.query.await([[
        INSERT IGNORE INTO phone_mdt_enforcement (report_ref, citizenid, jailed, fined, updated_at)
        VALUES (?, ?, 0, 0, ?)
    ]], { reportRef, citizenid, now })

    local affected = MySQL.update.await([[
        UPDATE phone_mdt_enforcement
        SET jailed = GREATEST(jailed, ?), fined = GREATEST(fined, ?), updated_at = ?
        WHERE report_ref = ? AND citizenid = ?
          AND (? = 0 OR jailed = 0)
          AND (? = 0 OR fined = 0)
    ]], { wantsJail, wantsFine, now, reportRef, citizenid, wantsJail, wantsFine })

    return (tonumber(affected) or 0) > 0
end

---Gives back a claimed flag when the world refused to apply it.
---@param reportRef string
---@param citizenid string
---@param column 'jailed'|'fined'
local function release(reportRef, citizenid, column)
    MySQL.update.await(
        ('UPDATE phone_mdt_enforcement SET `%s` = 0 WHERE report_ref = ? AND citizenid = ?'):format(column),
        { reportRef, citizenid })
end

---Stamps the arrest ref onto the ledger row so the Logs trail can walk from either end.
---@param reportRef string
---@param citizenid string
---@param arrestRef string
local function stampArrest(reportRef, citizenid, arrestRef)
    MySQL.update.await(
        'UPDATE phone_mdt_enforcement SET arrest_ref = ? WHERE report_ref = ? AND citizenid = ?',
        { arrestRef, reportRef, citizenid })
end

---Resolves a report and suspect payload into the charges filed against that person.
---@param me table caller identity from access.identity
---@param payload table { reportRef, citizenid }
---@return table|nil report
---@return table|nil suspect
---@return table[] lines resolved charge lines
---@return integer months
---@return integer fine
---@return table? refusal failure envelope when report or suspect is nil
local function quoteFor(me, payload)
    local reportRef = util.limitedString(payload.reportRef, 16)
    local citizenid = util.limitedString(payload.citizenid, 64)
    if not reportRef or not citizenid then
        return nil, nil, {}, 0, 0, util.fail('mdt.pickReportSuspect', 'Pick a report and a suspect')
    end

    local report, suspect, rows = paperwork.suspectCharges(me, reportRef, citizenid)
    if not report then return nil, nil, {}, 0, 0, util.fail('mdt.reportNotAvailable', 'That report is not available') end
    if not suspect then
        return report, nil, {}, 0, 0, util.fail('mdt.citizenNotSuspectReport', 'That citizen is not a suspect on that report')
    end

    local lines, months, fine = offences.totalFor(rows)
    if months > MAX_MONTHS then months = MAX_MONTHS end
    if fine > MAX_FINE then fine = MAX_FINE end
    return report, suspect, lines, months, fine
end

---A page of the booking log, newest first.
jail.list = access.gated('jail.view', function(_, payload)
    local where, params = { '1 = 1' }, {}

    local query = util.limitedString(payload.query, 60)
    if query then
        where[#where + 1] = '(a.subject_name LIKE ? OR a.citizenid LIKE ? OR a.ref LIKE ? OR a.report_ref LIKE ?)'
        local like = '%' .. likeSafe(query) .. '%'
        for _ = 1, 4 do params[#params + 1] = like end
    end

    local clauses = table.concat(where, ' AND ')
    local total = tonumber(MySQL.scalar.await(
        ('SELECT COUNT(*) FROM phone_mdt_arrests a WHERE %s'):format(clauses), params)) or 0

    local page = pageOf(payload.page)
    local rows = MySQL.query.await(([[
        SELECT a.* FROM phone_mdt_arrests a WHERE %s
        ORDER BY a.created_at DESC LIMIT %d OFFSET %d
    ]]):format(clauses, PAGE_SIZE, (page - 1) * PAGE_SIZE), params) or {}

    local out = {}
    for i = 1, #rows do out[i] = shapeOf(rows[i]) end
    return util.ok({ rows = out, total = total, page = page, pageSize = PAGE_SIZE })
end)

---What a report's charges actually cost this suspect, and whether either half has already been
---enforced. Every figure the booking dialog shows comes from here and none of them is editable.
jail.quote = access.gated('jail.view', function(_, payload, me)
    local report, suspect, lines, months, fine, refusal = quoteFor(me, payload)
    if not report or not suspect then return refusal end

    local charges = {}
    for i = 1, #lines do
        local line = lines[i]
        charges[i] = {
            code      = line.code,
            label     = line.label,
            class     = line.class,
            citizenid = suspect.citizenid,
            name      = suspect.name,
            count     = line.count,
            months    = line.months,
            fine      = line.fine,
        }
    end

    local jailed, fined = ledger(report.ref, suspect.citizenid)
    return util.ok({
        months        = months,
        fine          = fine,
        charges       = charges,
        jailedAlready = jailed,
        finedAlready  = fined,
        jailAvailable = prison.available(),
        maxReduction  = math.min(MAX_REDUCTION, months),
        maxFineReduction = math.min(MAX_FINE_REDUCTION, fine),
        maxFine       = MAX_FINE,
    })
end)

---Books a suspect: a sentence, a citation, or both. Nothing here trusts a client figure, the
---ledger is claimed before the world is touched, and a refused sentence hands its claim back.
jail.book = access.audited('jail.book', function(_, payload, me)
    local report, suspect, lines, months, fine, refusal = quoteFor(me, payload)
    if not report or not suspect then return refusal end
    if #lines == 0 then return util.fail('mdt.suspectHasNoChargesReport', 'That suspect has no charges on this report') end

    local reportRef = report.ref
    local citizenid = suspect.citizenid

    local reduction = util.wholeAmount(payload.reductionMonths)
    if reduction > MAX_REDUCTION then reduction = MAX_REDUCTION end
    if reduction > months then reduction = months end
    local sentence = months - reduction

    local fineCut = util.wholeAmount(payload.reductionFine)
    if fineCut > MAX_FINE_REDUCTION then fineCut = MAX_FINE_REDUCTION end
    if fineCut > fine then fineCut = fine end
    local charged = fine - fineCut

    local wantJail = payload.jail == true and sentence > 0
    local wantFine = payload.fine == true and charged > 0
    if payload.jail == true and not prison.available() then
        return util.fail('mdt.thereNoJailSystemServer', 'There is no jail system on this server')
    end
    if not wantJail and not wantFine then
        return util.fail('mdt.nothingEnforcePickSentenceFine', 'Nothing to enforce: pick a sentence or a fine')
    end

    local jailedAlready, finedAlready = ledger(reportRef, citizenid)
    if wantJail and jailedAlready then
        return util.fail('mdt.hasAlreadyBeenJailed', '{name} has already been jailed for {report}', { name = suspect.name, report = reportRef })
    end
    if wantFine and finedAlready then
        return util.fail('mdt.hasAlreadyBeenFined', '{name} has already been fined for {report}', { name = suspect.name, report = reportRef })
    end

    -- foreplay: dua cara penjara. direct = "Penjarakan langsung" (tahanan langsung dikirim ke
    -- penjara sekarang). Selain itu = "Antar ke penjara": booking hanya dicatat ('pending') dan
    -- tahanan dimasukkan di meja administrasi penjara (f_police -> jail.serve). Tersangka wajib
    -- online kalau dipenjara langsung atau ada denda yang ditarik sekarang.
    local direct = wantJail and payload.direct == true
    local target = player.getSourceByIdentifier(citizenid)
    if (wantFine or direct) and not target then return util.fail('mdt.suspectHasOnlineBooked', 'The suspect has to be online to be booked') end

    local held, cash = 0, 0
    if wantFine then
        held = tonumber(money.get(target, ACCOUNT)) or 0
        cash = ACCOUNT == 'cash' and 0 or (tonumber(money.get(target, 'cash')) or 0)
        if held + cash < charged then return util.fail('mdt.suspectCannotCoverFine', 'The suspect cannot cover that fine') end
    end

    if not claim(reportRef, citizenid, wantJail, wantFine) then
        return util.fail('mdt.hasAlreadyBeenBooked', '{name} has already been booked for {report}', { name = suspect.name, report = reportRef })
    end

    local queued = wantJail and not direct

    local sentenced = false
    if direct then
        -- borgol/escort dilepas dulu (f_police): ped yang menempel tidak bisa dipindah ke penjara
        if GetResourceState('f_police') == 'started' then
            pcall(function() exports.f_police:ReleaseForJail(target) end)
        end
        sentenced = prison.sendToJail(target, sentence, me.source)
        if not sentenced then
            release(reportRef, citizenid, 'jailed')
            if not wantFine then return util.fail('mdt.sentenceCouldNotServed', 'The sentence could not be served') end
        end
    end

    local debited = false
    if wantFine then
        local reason = 'MDT citation ' .. reportRef
        local fromAccount = math.min(held, charged)
        local rest = charged - fromAccount

        debited = fromAccount <= 0 or money.remove(target, ACCOUNT, fromAccount, reason) == true
        if debited and rest > 0 then
            debited = money.remove(target, 'cash', rest, reason) == true
            if not debited and fromAccount > 0 then
                money.add(target, ACCOUNT, fromAccount, reason .. ' reversed')
            end
        end

        if not debited then
            release(reportRef, citizenid, 'fined')
            if not queued and not sentenced then return util.fail('mdt.citationCouldNotCollected', 'The citation could not be collected') end
        end
    end

    local charges = {}
    for i = 1, #lines do
        charges[i] = {
            code   = lines[i].code,
            label  = lines[i].label,
            class  = lines[i].class,
            count  = lines[i].count,
            months = lines[i].months,
            fine   = lines[i].fine,
        }
    end

    local ref = store.nextRef('arrest')
    if not ref then return util.fail('mdt.couldNotAllocateArrestNumber', 'Could not allocate an arrest number') end

    local now = os.time()
    MySQL.insert.await([[
        INSERT INTO phone_mdt_arrests
            (ref, report_id, report_ref, citizenid, subject_name, officer_cid, officer_name,
             officer_callsign, charges, months, fine, jailed, fined, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        ref, report.id, reportRef, citizenid, suspect.name,
        me.citizenid, me.name, me.callsign, json.encode(charges),
        (queued or sentenced) and sentence or 0, debited and charged or 0,
        sentenced and 1 or 0, debited and 1 or 0, queued and 'pending' or 'served', now,
    })
    if sentenced then
        MySQL.update.await('UPDATE phone_mdt_arrests SET served_at = ?, served_by = ? WHERE ref = ?',
            { now, me.name, ref })
    end
    stampArrest(reportRef, citizenid, ref)

    local row = MySQL.single.await('SELECT * FROM phone_mdt_arrests WHERE ref = ? LIMIT 1', { ref })
    if not row then return util.fail('mdt.bookingCouldNotRecorded', 'The booking could not be recorded') end

    return util.ok({ arrest = shapeOf(row) }), {
        entityType = 'arrest',
        entityId   = ref,
        details    = {
            subject   = suspect.name,
            citizenid = citizenid,
            reportRef = reportRef,
            months    = (queued or sentenced) and sentence or 0,
            fine      = debited and charged or 0,
            status    = queued and 'pending' or 'served',
            penjara   = direct and 'langsung' or (queued and 'antar ke penjara' or nil),
        },
    }
end)

---foreplay: membatalkan booking penjara yang belum dieksekusi di meja (salah data). Klaim
---'jailed' di ledger dilepas supaya laporan yang sama bisa di-booking ulang; denda yang sudah
---ditarik tidak dikembalikan (dan tidak ditarik dua kali).
jail.cancel = access.audited('jail.cancel', function(_, payload, me)
    local ref = util.limitedString(payload.ref, 16)
    if not ref then return util.fail('mdt.arrestNotFound', 'That booking was not found') end

    local row = MySQL.single.await('SELECT * FROM phone_mdt_arrests WHERE ref = ? LIMIT 1', { ref })
    if not row then return util.fail('mdt.arrestNotFound', 'That booking was not found') end

    local affected = MySQL.update.await([[
        UPDATE phone_mdt_arrests SET status = 'cancelled', cancelled_by = ?
        WHERE ref = ? AND status = 'pending'
    ]], { me.name, ref })
    if (tonumber(affected) or 0) == 0 then
        return util.fail('mdt.arrestNotPending', 'Only a booking that is still waiting can be cancelled')
    end

    if row.report_ref then release(row.report_ref, row.citizenid, 'jailed') end

    row = MySQL.single.await('SELECT * FROM phone_mdt_arrests WHERE ref = ? LIMIT 1', { ref })
    return util.ok({ arrest = shapeOf(row) }), {
        entityType = 'arrest',
        entityId   = ref,
        details    = {
            subject   = row.subject_name,
            citizenid = row.citizenid,
            reportRef = row.report_ref,
            months    = tonumber(row.months) or 0,
        },
    }
end)

---foreplay: booking penjara yang masih menunggu untuk satu warga (dipakai meja penjara f_police).
---Data mentah dari server, tidak ada izin di sini: pemanggil (export) yang memeriksa petugas.
---@param citizenid string
---@return table[] rows
function jail.pendingFor(citizenid)
    local rows = MySQL.query.await([[
        SELECT a.*, r.title AS report_title FROM phone_mdt_arrests a
        LEFT JOIN phone_mdt_reports r ON r.id = a.report_id
        WHERE a.citizenid = ? AND a.status = 'pending'
        ORDER BY a.created_at ASC
    ]], { citizenid }) or {}

    local out = {}
    for i = 1, #rows do
        local shaped = shapeOf(rows[i])
        shaped.reportTitle = rows[i].report_title
        out[i] = shaped
    end
    return out
end

---foreplay: eksekusi semua booking yang menunggu untuk tahanan ini: hukuman dijumlah (maks
---MaxMonths) lalu dikirim ke penjara. Baris diklaim satu per satu dulu (status pending -> served)
---supaya dua petugas yang menekan bersamaan tidak memenjarakan dua kali; gagal = dikembalikan.
---@param target integer server id tahanan
---@param servedBy string nama yang dicatat di MDT
---@param officerSrc integer|nil petugas (nil = otomatis oleh sistem)
---@param auditAs fun(rows: table[]): table|nil identitas untuk baris audit
---@return boolean ok
---@return string|table result pesan gagal, atau { months, refs, subject }
local function serveFor(target, servedBy, officerSrc, auditAs)
    local citizenid = target and player.getIdentifier(target)
    if not citizenid then return false, 'Tahanan tidak ditemukan' end
    if not prison.available() then return false, 'Tidak ada sistem penjara di server ini' end

    local rows = jail.pendingFor(citizenid)
    if #rows == 0 then return false, 'Tidak ada data penahanan di MDT untuk orang ini' end

    local now = os.time()
    local claimed, total = {}, 0
    for i = 1, #rows do
        local affected = MySQL.update.await([[
            UPDATE phone_mdt_arrests SET status = 'served', jailed = 1, served_at = ?, served_by = ?
            WHERE ref = ? AND status = 'pending'
        ]], { now, servedBy, rows[i].ref })
        if (tonumber(affected) or 0) > 0 then
            claimed[#claimed + 1] = rows[i].ref
            total = total + rows[i].months
        end
    end
    if #claimed == 0 then return false, 'Data penahanan ini sudah diproses' end
    if total > MAX_MONTHS then total = MAX_MONTHS end

    local function revert()
        for i = 1, #claimed do
            MySQL.update.await([[
                UPDATE phone_mdt_arrests SET status = 'pending', jailed = 0, served_at = NULL, served_by = NULL
                WHERE ref = ?
            ]], { claimed[i] })
        end
    end

    if total < 1 or not prison.sendToJail(target, total, officerSrc) then
        revert()
        return false, 'Hukuman tidak bisa dijalankan'
    end

    store.audit(auditAs(rows), 'jail.serve', 'arrest', claimed[1], {
        subject   = rows[1].subject,
        citizenid = citizenid,
        months    = total,
        bookings  = table.concat(claimed, ', '),
        oleh      = servedBy,
    })
    return true, { months = total, refs = claimed, subject = rows[1].subject }
end

---Eksekusi di meja administrasi penjara oleh petugas.
---@param src integer petugas
---@param target integer server id tahanan
function jail.serve(src, target)
    local me = access.identity(src)
    if not me or access.domain(me) ~= 'leo' then return false, 'Kamu tidak punya akses MDT polisi' end
    return serveFor(target, me.name, src, function() return me end)
end

---@type string|nil job departemen polisi pertama di config, untuk baris audit eksekusi otomatis
local LEO_JOB
for _, dept in ipairs(access.departments()) do
    if dept.type ~= 'ems' and dept.type ~= 'doj' then LEO_JOB = dept.job break end
end

---foreplay: tahanan yang logout/disconnect sebelum dibawa ke meja penjara langsung dipenjara saat
---login lagi (anti kabur lewat logout). Audit dicatat atas nama petugas yang mendata di MDT.
---@param target integer server id tahanan
function jail.serveOnLogin(target)
    return serveFor(target, 'Sistem (logout saat ditahan)', nil, function(rows)
        local row = rows[1]
        return {
            citizenid = row.officerCid,
            name      = row.officer,
            callsign  = row.callsign,
            job       = LEO_JOB,
        }
    end)
end

return jail
