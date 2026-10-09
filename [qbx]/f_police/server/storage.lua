---Marks an owned vehicle as impounded (state 2). Only redemption at the police counter (f_cityhall
---tickets) releases it again.
function ImpoundForever(body, engine, fuel, plate)
    MySQL.query('UPDATE player_vehicles SET state = 2, body = ?, engine = ?, fuel = ? WHERE plate = ?', {body, engine, fuel, plate})
end
