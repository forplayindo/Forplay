---@type table MDT permissions (server.mdt.access): identity, the gate and the audited wrapper.
local access = require 'server.mdt.access'
---@type table Shared server helpers (server.util): envelopes.
local util   = require 'server.util'

---@type table EMS bills module (custom, foreplay). The table returned at end of file.
---
---The data and the money rules live in f_ambulancejob (server/billing.lua): unpaid EMS service
---bills and the "Tagih" pull from the patient's bank. This module only puts them behind the
---medical terminal's own gate (`patients.view`, EMS departments only) and shapes the envelope.
local bills = {}

---@param fnName string export on f_ambulancejob
---@return table? result
local function ambulance(fnName, ...)
    if GetResourceState('f_ambulancejob') ~= 'started' then return nil end
    local args = { ... }
    local ok, res = pcall(function() return exports['f_ambulancejob'][fnName](nil, table.unpack(args)) end)
    if not ok then
        print(('^1[f_phone:mdt]^0 f_ambulancejob %s failed: %s'):format(fnName, res))
        return nil
    end
    return res
end

---Unpaid EMS bills, newest first. Optional `query` matches patient name or citizen ID.
bills.list = access.gated('patients.view', function(src, payload)
    local res = ambulance('MdtBillsList', src, { query = payload.query })
    if not res then return util.fail('mdt.billsUnavailable', 'Sistem tagihan EMS tidak aktif') end
    if res.error then return util.fail('mdt.billsRefused', res.error) end
    return util.ok({ rows = res.rows or {}, sum = res.sum or 0 })
end)

---Pull one unpaid bill straight from the patient's bank (refused when the balance is short).
bills.collect = access.gated('patients.view', function(src, payload)
    local id = math.floor(tonumber(payload.id) or 0)
    if id <= 0 then return util.fail('mdt.billNotFound', 'Tagihan tidak ditemukan') end
    local res = ambulance('MdtBillsCollect', src, id)
    if not res then return util.fail('mdt.billsUnavailable', 'Sistem tagihan EMS tidak aktif') end
    if res.error then return util.fail('mdt.billsRefused', res.error) end
    return util.ok({ total = res.total })
end)

return bills
