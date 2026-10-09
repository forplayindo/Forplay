---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/banking: the account overview and phone transfers.
proxy('f_phone:banking:overview', 'f_phone:server:banking:overview')
proxy('f_phone:banking:send',     'f_phone:server:banking:send')
proxy('f_phone:banking:setCardStyle', 'f_phone:server:banking:setCardStyle')

-- Rekening organisasi (dipakai app Bank di tablet; server/banking/org.lua).
proxy('f_phone:banking:org:overview', 'f_phone:server:banking:org:overview')
proxy('f_phone:banking:org:send',     'f_phone:server:banking:org:send')

---Server push: saldo/riwayat rekening organisasi berubah; tablet yang terbuka refetch.
RegisterNetEvent('f_phone:client:orgBankChanged', function()
    SendNUIMessage({ action = 'f_phone:bank:orgChanged' })
end)

-- Standing orders (server/banking/standing.lua).
proxy('f_phone:banking:standing:list',   'f_phone:server:banking:standing:list')
proxy('f_phone:banking:standing:create', 'f_phone:server:banking:standing:create')
proxy('f_phone:banking:standing:update', 'f_phone:server:banking:standing:update')
proxy('f_phone:banking:standing:delete', 'f_phone:server:banking:standing:delete')

-- Person-to-person invoicing (server/services/invoices.lua personal handlers).
proxy('f_phone:banking:invoices:create', 'f_phone:server:banking:invoices:create')
proxy('f_phone:banking:invoices:sent',   'f_phone:server:banking:invoices:sent')
proxy('f_phone:banking:invoices:cancel', 'f_phone:server:banking:invoices:cancel')

---Server push: another player transferred money to us; relays it to the Wallet.
---@param data table { amount, from } from server/banking/actions.lua
RegisterNetEvent('f_phone:client:bankReceived', function(data)
    SendNUIMessage({ action = 'f_phone:bank:received', data = data })
end)

---Server push: a transaction was recorded outside the app (an external debit/credit); nudges
---the Wallet to refetch.
RegisterNetEvent('f_phone:client:bankTxAdded', function()
    SendNUIMessage({ action = 'f_phone:bank:txAdded' })
end)

---@type boolean True while a balance-refresh nudge is already scheduled.
local nudgePending = false

---Debounced Wallet refresh: framework money events burst (paycheck plus tax), one refetch does.
local function nudgeWallet()
    if nudgePending then return end
    nudgePending = true
    SetTimeout(500, function()
        nudgePending = false
        SendNUIMessage({ action = 'f_phone:bank:txAdded' })
    end)
end

-- Framework money-change broadcasts, so the balance ticks live even when ANOTHER script moves
-- money. Whichever framework is absent simply never fires its event; the handlers are inert.
RegisterNetEvent('hud:client:OnMoneyChange', nudgeWallet)
RegisterNetEvent('QBCore:Client:OnMoneyChange', nudgeWallet)
RegisterNetEvent('esx:setAccountMoney', nudgeWallet)
