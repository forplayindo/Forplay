---@type fun(nuiAction: string, serverEvent: string) NUI->server pass-through registrar (client.nui).
local proxy = require 'client.nui'

-- Thin delegates into server/stocks: market snapshot, cash deposits/withdrawals and trades.
proxy('f_phone:stocks:market',   'f_phone:server:stocks:market')
proxy('f_phone:stocks:deposit',  'f_phone:server:stocks:deposit')
proxy('f_phone:stocks:withdraw', 'f_phone:server:stocks:withdraw')
proxy('f_phone:stocks:buy',      'f_phone:server:stocks:buy')
proxy('f_phone:stocks:sell',     'f_phone:server:stocks:sell')
proxy('f_phone:stocks:holders',  'f_phone:server:stocks:holders')
proxy('f_phone:stocks:watch',    'f_phone:server:stocks:watch')

---Server push: a live price tick; relays it to open charts and tickers.
---@param data table price snapshot from server/stocks
RegisterNetEvent('f_phone:client:stocks:prices', function(data)
    SendNUIMessage({ action = 'f_phone:stocks:prices', data = data })
end)
