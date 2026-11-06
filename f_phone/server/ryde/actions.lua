---@type table Player bridge (bridge.server.player): citizenid/name/live-source lookups.
local player    = require 'bridge.server.player'
---@type table Shared app-accounts store (server.accounts.store): signed-in session -> account rows.
local acctStore = require 'server.accounts.store'
---@type table Money bridge (bridge.server.money): framework-agnostic bank debits/credits.
local money     = require 'bridge.server.money'
---@type table Ryde persistence layer (server.ryde.store): driver profiles + finished rides.
local store     = require 'server.ryde.store'
---@type table Settings store (server.settings.store): phone-number provisioning for trip cards.
local settings  = require 'server.settings.store'
---@type table Banking actions (server.banking.actions): phone Wallet transaction log entries.
local bank      = require 'server.banking.actions'
---@type table Ryde config (configs/ryde.lua): destinations, fare rails, driver cut, leaderboard.
local config    = require 'configs.ryde'

---@type table Actions module; the table returned at end of file.
local actions = {}

-- Live matching state, in-memory only; finished rides persist via store.insertRide. Driver-side
-- keys are the Ryde account username, riders are keyed by citizenid.
---@type table<string, table> On-duty drivers by username: { cid, name, vehicle, plate, color, rating, since }.
local online       = {}
---@type table<string, table> Pending ride requests by id (no driver locked in yet).
local requests     = {}
---@type table<string, table> Engaged trips by id (offered -> enroute_pickup -> arriving -> in_progress -> completed).
local trips        = {}
---@type table<string, string> The request/trip id a rider (citizenid) is currently in.
local riderActive  = {}
---@type table<string, string> The trip id a driver (username) is currently on.
local driverActive = {}
---@type table<integer, string> Citizenid per live src, cached so disconnect cleanup stays reliable.
local srcCid       = {}
---@type table<integer, table> { tripId, role } per src while they watch a trip map (gates the live peer stream).
local tripViewers  = {}

---@type string Client event prefix every Ryde push goes out under.
local EV = 'f_phone:client:ryde:'

---@type integer Minimum gap between ride requests from one rider (ms). Long enough to make a
---request/cancel loop worthless, short enough that re-picking a destination is not a wait.
local REQUEST_COOLDOWN = 5000

local util = require 'server.util'
local ok, fail = util.ok, util.fail


---Coerces a client-supplied value to a finite number, rejecting non-numbers, NaN and the
---infinities.
---@param v any
---@return number|nil n the finite number, nil when unusable
local function finite(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

---Current server source for a citizenid, or nil when they're offline.
---@param cid string|nil
---@return integer|nil
local function srcOf(cid) return cid and player.getSourceByIdentifier(cid) or nil end

---Pushes an event straight to a player by citizenid. No-op when offline.
---@param cid string|nil
---@param event string suffix appended to EV
---@param data table
local function pushTo(cid, event, data)
    local src = srcOf(cid)
    if src then TriggerClientEvent(EV .. event, src, data) end
end

---Fans an event out to every on-duty driver; a driver whose live source can't be resolved is
---logged.
---@param event string suffix appended to EV
---@param data table
local function broadcastToDrivers(event, data)
    for _, d in pairs(online) do
        local src = srcOf(d.cid)
        if src then
            TriggerClientEvent(EV .. event, src, data)
        else
            print(('^1[f_phone:ryde]^0 online driver %s could not be reached (no live source)'):format(d.cid))
        end
    end
end

---How many riders are waiting on the open board right now (no driver locked in).
---@return integer
local function waitingCount()
    local n = 0
    for _ in pairs(requests) do n = n + 1 end
    return n
end

---@type integer Minimum gap between waiting-count broadcasts (ms). The count is a cosmetic badge
---and this is the one Ryde event that goes to EVERY player on the server.
local WAITING_MIN_MS = 1000

---@type integer, boolean Last broadcast stamp, and whether a change is still waiting to go out.
local waitingAt, waitingPending = 0, false

---Broadcasts the current waiting-rider count to every player, at most once per WAITING_MIN_MS.
---A change raised inside the window is deferred to the end of it, never dropped.
local function broadcastWaiting()
    local now  = GetGameTimer()
    local wait = WAITING_MIN_MS - (now - waitingAt)
    if wait > 0 then
        if waitingPending then return end
        waitingPending = true
        SetTimeout(wait, function()
            waitingPending = false
            waitingAt = GetGameTimer()
            TriggerClientEvent(EV .. 'waitingCount', -1, { count = waitingCount() })
        end)
        return
    end
    waitingAt = now
    TriggerClientEvent(EV .. 'waitingCount', -1, { count = waitingCount() })
end

---Fires a Ryde phone notification (quietInApp) to a player by citizenid for a trip milestone.
---@param cid string|nil
---@param body string
local function notifyRyde(cid, body)
    local src = srcOf(cid)
    if not src then return end
    TriggerClientEvent('f_phone:client:notify', src, {
        app = 'ryde', appId = 'ryde', quietInApp = true, time = 'now', title = 'Ryde', body = body,
    })
end

---Fires a Bank/Wallet notification (quietInApp) for a Ryde money movement.
---@param cid string|nil
---@param body string
local function notifyBank(cid, body)
    local src = srcOf(cid)
    if not src then return end
    TriggerClientEvent('f_phone:client:notify', src, {
        app = 'bank', appId = 'bank', quietInApp = true, time = 'now',
        titleKey = 'banking.bankTitle', title = 'Bank', body = body,
    })
end

---Resolves the caller's signed-in Ryde account from src, attaching the citizenid as `_cid` and
---the resolved display name; refreshes the src -> citizenid cache.
---@param src integer player server id
---@return table|nil account
local function account(src)
    local cid = player.getIdentifier(src)
    if not cid then return nil end
    local acc = acctStore.getSessionAccount('ryde', cid)
    if not acc then return nil end
    acc._cid  = cid
    acc.name  = (acc.displayName and acc.displayName ~= '') and acc.displayName or acc.username
    srcCid[src] = cid
    return acc
end

---Resolves the caller as a rider (no Ryde account required): citizenid from src, character
---name; refreshes the src -> citizenid cache.
---@param src integer player server id
---@return table|nil rider { cid, name }
local function rider(src)
    local cid = player.getIdentifier(src)
    if not cid then return nil end
    srcCid[src] = cid
    return { cid = cid, name = player.getName(src) }
end

---Straight-line 2D distance in km between two {x, y} points.
---@param a table
---@param b table
---@return number
local function distanceKm(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) / 1000
end

---Estimated road distance in km (straight line * RoadFactor), rounded to 0.1 km.
---@param a table
---@param b table
---@return number
local function roadKm(a, b)
    return math.floor(distanceKm(a, b) * (config.RoadFactor or 1.0) * 10 + 0.5) / 10
end

---Fixed fare for a road distance: BaseFare + km * PerKm, rounded to Rp 1.000 and clamped.
---@param km number
---@return integer
local function calcFare(km)
    local fare = (config.BaseFare or 0) + km * (config.PerKm or 0)
    fare = math.floor(fare / 1000 + 0.5) * 1000
    return math.floor(math.max(config.MinFare or 0, math.min(config.MaxFare or fare, fare)))
end

---Trims a pending request down to a driver's board card, omitting the rider's citizenid and
---payment choice.
---@param r table request record
---@return table
local function publicRequest(r)
    return {
        id = r.id, riderName = r.riderName,
        pickup = r.pickup, dropoff = r.dropoff,
        distance = r.distance, fare = r.fare, createdAt = r.createdAt,
    }
end

---Builds the trip as seen by one side; `role` tags which end the payload is for, and each side
---gets the other party's phone number.
---@param t table trip record
---@param role string 'rider'|'driver'
---@return table
local function publicTrip(t, role)
    return {
        id = t.id, requestId = t.requestId, status = t.status, role = role,
        riderName = t.riderName, driverName = t.driverName,
        vehicle = t.vehicle, plate = t.plate, color = t.color, rating = t.driverRating,
        number = (role == 'driver') and t.riderNumber or t.driverNumber,
        fare = t.fare, payment = t.payment,
        pickup = t.pickup, dropoff = t.dropoff, distance = t.distance,
    }
end

---Tears down an engaged trip, records it as cancelled, and notifies the party who didn't
---trigger the cancel. `by` is 'rider' | 'driver' | 'disconnect'.
---@param trip table
---@param by string
local function cancelTrip(trip, by)
    trips[trip.id] = nil
    if riderActive[trip.riderUsername] == trip.id then riderActive[trip.riderUsername] = nil end
    driverActive[trip.driverUsername] = nil
    trip.status = 'cancelled'
    trip.paid   = false
    store.insertRide(trip)
    if by ~= 'rider' then
        pushTo(trip.riderCid,  'tripUpdate', { id = trip.id, status = 'cancelled', role = 'rider',  by = by })
    end
    if by ~= 'driver' then
        pushTo(trip.driverCid, 'tripUpdate', { id = trip.id, status = 'cancelled', role = 'driver', by = by })
    end
end

---Holds an engaged trip for DisconnectGrace seconds after one side crashes; one timer per drop,
---no polling. Back in time (onPlayerLoaded clears `offline`) = trip continues; otherwise it is
---cancelled free of charge.
---@param trip table
---@param cid string citizenid of the player who dropped
local function holdTrip(trip, cid)
    local role  = (trip.riderCid == cid) and 'rider' or 'driver'
    local other = (role == 'rider') and trip.driverCid or trip.riderCid
    local grace = config.DisconnectGrace or 300
    local token = {}
    trip.offline = { cid = cid, role = role, token = token }
    notifyRyde(other, ('%s terputus. Menunggu maksimal %d menit.'):format(role == 'rider' and 'Penumpang' or 'Supir', math.ceil(grace / 60)))

    SetTimeout(grace * 1000, function()
        if trips[trip.id] ~= trip or not trip.offline or trip.offline.token ~= token then return end
        if srcOf(cid) then trip.offline = nil; return end  -- back, but the load event was missed
        cancelTrip(trip, 'disconnect')
        if role == 'driver' then online[trip.driverUsername] = nil end
        notifyRyde(other, ('%s tidak kembali. Perjalanan dibatalkan tanpa biaya.'):format(role == 'rider' and 'Penumpang' or 'Supir'))
    end)
end

---Drops a single offered trip and frees its driver, leaving the rider's open request untouched;
---a still-open request goes back on this driver's board.
---@param trip table
local function dropOffer(trip)
    trips[trip.id] = nil
    driverActive[trip.driverUsername] = nil
    local req = trip.requestId and requests[trip.requestId] or nil
    if req then
        pushTo(trip.driverCid, 'requestAdded', publicRequest(req))
    end
end

---Drops every outstanding offer on a request except `keepId` (nil = drop all), bumping each
---passed-over driver back to free with a `notify` status push.
---@param requestId string
---@param keepId string|nil
---@param notify string
local function clearOffersFor(requestId, keepId, notify)
    for id, t in pairs(trips) do
        if t.requestId == requestId and t.status == 'offered' and id ~= keepId then
            dropOffer(t)
            pushTo(t.driverCid, 'tripUpdate', { id = id, status = notify, role = 'driver' })
        end
    end
end

---Returns whether the trip's rider and driver currently sit in the same vehicle, read from
---server-side OneSync entities.
---@param trip table
---@return boolean
local function inSameVehicle(trip)
    local driverSrc = srcOf(trip.driverCid)
    local riderSrc  = srcOf(trip.riderCid)
    if not (driverSrc and riderSrc) then return false end
    local dv = GetVehiclePedIsIn(GetPlayerPed(driverSrc), false)
    local rv = GetVehiclePedIsIn(GetPlayerPed(riderSrc), false)
    return dv ~= 0 and dv == rv
end

---Returns whether a live player is within `radius` metres of a world point, using server-side
---ped coords.
---@param src number|nil
---@param x number
---@param y number
---@param radius number
---@return boolean
local function withinOf(src, x, y, radius)
    if not src then return false end
    local c = GetEntityCoords(GetPlayerPed(src))
    local dx, dy = c.x - x, c.y - y
    return (dx * dx + dy * dy) <= (radius * radius)
end

---Posts a rider's ride request onto the open board, one live request/trip per rider; coords are
---coerced finite, labels capped, payment whitelisted, and free on-duty drivers notified.
---@param src integer player server id
---@param payload table { pickup: { label?, x, y }, dropoff: { label?, x, y }, payment?: string }
---@return table result { requestId } on success
function actions.requestRide(src, payload)
    local rdr = rider(src)
    if not rdr then return fail('ryde.couldNotResolveCharacter', 'Could not resolve your character.') end
    if riderActive[rdr.cid] then return fail('ryde.alreadyHaveActiveRide', 'You already have an active ride.') end

    local p = type(payload) == 'table' and payload or {}
    local pickup  = type(p.pickup)  == 'table' and p.pickup  or nil
    local dropoff = type(p.dropoff) == 'table' and p.dropoff or nil
    local px = pickup and finite(pickup.x)
    local py = pickup and finite(pickup.y)
    local dx = dropoff and finite(dropoff.x)
    local dy = dropoff and finite(dropoff.y)
    if not (px and py and dx and dy) then
        return fail('ryde.pickDestinationFirst', 'Pick a destination first.')
    end
    -- Checked after validation so a mis-picked destination never spends the budget. A request/cancel
    -- loop is otherwise free, and each pass fans out to every driver plus a server-wide broadcast.
    if not util.cooldown(rdr.cid, 'ryde:request', REQUEST_COOLDOWN) then
        return fail('ryde.justRequestedRideGiveMoment', 'You just requested a ride. Give it a moment.')
    end

    local req = {
        id            = store.newId(),
        riderUsername = rdr.cid,
        riderName     = rdr.name,
        riderCid      = rdr.cid,
        pickup        = { label = (type(pickup.label) == 'string' and pickup.label or 'Lokasi saat ini'):sub(1, 96), x = px + 0.0, y = py + 0.0 },
        dropoff       = { label = (type(dropoff.label) == 'string' and dropoff.label or 'Destination'):sub(1, 96), x = dx + 0.0, y = dy + 0.0 },
        payment       = 'card',
        createdAt     = os.time() * 1000,
    }
    req.distance = roadKm(req.pickup, req.dropoff)
    req.fare     = calcFare(req.distance)
    if money.get(src, 'bank') < req.fare then
        return fail('ryde.notEnoughBank', ('Saldo bank tidak cukup. Tarif perjalanan ini Rp %d.'):format(req.fare))
    end

    requests[req.id]      = req
    riderActive[rdr.cid]  = req.id
    broadcastToDrivers('requestAdded', publicRequest(req))
    broadcastWaiting()
    for username, d in pairs(online) do
        if not driverActive[username] then
            notifyRyde(d.cid, ('Pesanan baru dari %s di dekat %s (Rp %d)'):format(rdr.name, req.pickup.label, req.fare))
        end
    end
    return ok({ requestId = req.id, fare = req.fare, distance = req.distance })
end

---Goes on/off duty. Going online registers/refreshes the driver's vehicle card and hands back
---the current board; going offline is blocked mid-trip and returns the live waiting count.
---@param src integer player server id
---@param payload table { online: boolean, vehicle?: string, plate?: string, color?: string }
---@return table result
function actions.setOnline(src, payload)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    local p = type(payload) == 'table' and payload or {}

    if p.online then
        local veh   = tostring(p.vehicle or 'Vehicle'):sub(1, 64)
        local plate = tostring(p.plate or ''):sub(1, 16)
        local color = tostring(p.color or '#111111'):sub(1, 16)
        store.upsertDriver(acc.username, acc.name, veh, plate, color)
        local d = store.getDriver(acc.username)
        local rating = (d and d.rating_count > 0) and (d.rating_sum / d.rating_count) or 5.0
        online[acc.username] = {
            cid = acc._cid, name = acc.name,
            vehicle = veh, plate = plate, color = color, rating = rating, since = os.time() * 1000,
        }
        local pending = {}
        for _, r in pairs(requests) do pending[#pending + 1] = publicRequest(r) end
        print(('^3[f_phone:ryde]^0 %s went on duty (%d pending request(s) on the board)'):format(acc.name, #pending))
        return ok({ online = true, requests = pending, waiting = #pending })
    end

    if driverActive[acc.username] then return fail('ryde.finishCurrentTripBeforeGoing', 'Finish your current trip before going offline.') end
    online[acc.username] = nil
    return ok({ online = false, waiting = waitingCount() })
end

---Returns how many riders are waiting right now, for any signed-in account. Read-only.
---@param src integer player server id
---@return table result { count }
function actions.waitingCount(src)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    return ok({ count = waitingCount() })
end

---Snapshot of the open requests board (dashboard refresh). On-duty drivers only; anyone else
---gets an empty board rather than an error. Read-only.
---@param src integer player server id
---@return table result { requests }
function actions.requestsBoard(src)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    if not online[acc.username] then return ok({ requests = {} }) end
    local pending = {}
    for _, r in pairs(requests) do pending[#pending + 1] = publicRequest(r) end
    return ok({ requests = pending })
end

---Driver takes a pending request at its fixed fare, first come first served: the gates are
---re-checked after the DB awaits, then the request is pulled off the board in the same
---non-yielding block that creates the trip, so two drivers can never both win it.
---@param src integer player server id
---@param payload table { requestId: string }
---@return table result { tripId } on success
function actions.accept(src, payload)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    if not online[acc.username] then return fail('ryde.goOnlineAcceptRides', 'Go online to accept rides.') end
    if driverActive[acc.username] then return fail('ryde.alreadyHaveActiveTrip', 'You already have an active trip.') end

    local p = type(payload) == 'table' and payload or {}
    local req = p.requestId and requests[p.requestId] or nil
    if not req then return fail('ryde.rideNoLongerAvailable', 'That ride is no longer available.') end
    if req.riderCid == acc._cid then return fail('ryde.cannotAcceptOwnRequest', 'You cannot accept your own request.') end

    local driverNumber = settings.ensurePhoneNumber(acc._cid)
    local riderNumber  = settings.ensurePhoneNumber(req.riderCid)
    -- Re-check after the awaits; from here to the end nothing yields, so the first driver wins.
    local drv = online[acc.username]
    if not drv then return fail('ryde.goOnlineAcceptRides', 'Go online to accept rides.') end
    if driverActive[acc.username] then return fail('ryde.alreadyHaveActiveTrip', 'You already have an active trip.') end
    if requests[req.id] ~= req then return fail('ryde.rideTakenByOther', 'Pesanan ini sudah diambil supir lain.') end

    requests[req.id] = nil
    local trip = {
        id = store.newId(), requestId = req.id,
        riderUsername = req.riderUsername, riderName = req.riderName, riderCid = req.riderCid,
        driverUsername = acc.username, driverName = drv.name, driverCid = acc._cid,
        driverNumber = driverNumber,
        riderNumber  = riderNumber,
        vehicle = drv.vehicle, plate = drv.plate, color = drv.color, driverRating = drv.rating,
        pickup = req.pickup, dropoff = req.dropoff, distance = req.distance,
        payment = req.payment, fare = req.fare, status = 'enroute_pickup',
    }
    trips[trip.id]                  = trip
    driverActive[acc.username]      = trip.id
    riderActive[trip.riderUsername] = trip.id
    broadcastToDrivers('requestRemoved', { id = req.id })
    broadcastWaiting()

    pushTo(trip.riderCid, 'matched', publicTrip(trip, 'rider'))
    local driverView = publicTrip(trip, 'driver')
    driverView.waypoint = trip.pickup
    pushTo(trip.driverCid, 'tripUpdate', driverView)

    local riderSrc = srcOf(trip.riderCid)
    if riderSrc then
        TriggerClientEvent('f_phone:client:notify', riderSrc, {
            app = 'ryde', appId = 'ryde', quietInApp = true, time = 'now', title = 'Ryde',
            body = ('%s menuju lokasimu (%s, %s)'):format(trip.driverName, trip.vehicle, trip.plate),
        })
    end
    print(('^3[f_phone:ryde]^0 %s took request %s at Rp %d (trip %s)'):format(acc.name, req.id, trip.fare, trip.id))
    return ok({ tripId = trip.id, fare = trip.fare })
end

---Driver advances an accepted trip to 'arriving' or 'in_progress'; only the trip's own driver,
---never from 'offered', and starting requires rider and driver to share a vehicle.
---@param src integer player server id
---@param payload table { tripId: string, status: 'arriving'|'in_progress' }
---@return table result { status }
function actions.tripStatus(src, payload)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    local p = type(payload) == 'table' and payload or {}
    local trip = p.tripId and trips[p.tripId] or nil
    if not (trip and trip.driverUsername == acc.username) then return fail('ryde.noActiveTrip', 'No active trip.') end
    if trip.status == 'offered' then return fail('ryde.noActiveTrip', 'No active trip.') end
    if trip.offline then return fail('ryde.partyDisconnected', 'Penumpang sedang terputus. Tunggu dia kembali.') end

    local nextStatus = p.status
    if nextStatus ~= 'arriving' and nextStatus ~= 'in_progress' then return fail('ryde.invalidStatus', 'Invalid status.') end
    if nextStatus == 'in_progress' and not inSameVehicle(trip) then
        return fail('ryde.riderNeedsVehicleStartTrip', 'Your rider needs to be in your vehicle to start the trip.')
    end
    trip.status = nextStatus

    pushTo(trip.riderCid, 'tripUpdate', publicTrip(trip, 'rider'))
    local driverView = publicTrip(trip, 'driver')
    if nextStatus == 'in_progress' then driverView.waypoint = trip.dropoff end
    pushTo(trip.driverCid, 'tripUpdate', driverView)
    if nextStatus == 'arriving' then
        notifyRyde(trip.riderCid, 'Pengemudimu sudah tiba. Silakan naik kalau sudah siap.')
    else
        notifyRyde(trip.riderCid, ('Perjalanan dimulai. Menuju %s.'):format(trip.dropoff.label))
    end
    return ok({ status = nextStatus })
end

---Driver UI poll: returns whether rider and driver share a vehicle right now. Read-only.
---@param src integer player server id
---@param payload table { tripId: string }
---@return table result { same }
function actions.sameVehicle(src, payload)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    local p = type(payload) == 'table' and payload or {}
    local trip = p.tripId and trips[p.tripId] or nil
    if not (trip and trip.driverUsername == acc.username) then return fail('ryde.noActiveTrip', 'No active trip.') end
    return ok({ same = inSameVehicle(trip) })
end

---Driver completes an 'in_progress' trip within 250m of the drop-off: charges the rider bank ->
---bank, pays the driver the fare minus TaxRate (tax -> TaxAccount + f_tax "Pajak Warga"),
---persists the ride and bumps stats; unpaid rides record paid = false.
---@param src integer player server id
---@param payload table { tripId: string }
---@return table result { rideId, fare, paid }
function actions.complete(src, payload)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    local p = type(payload) == 'table' and payload or {}
    local trip = p.tripId and trips[p.tripId] or nil
    if not (trip and trip.driverUsername == acc.username) then return fail('ryde.noActiveTrip', 'No active trip.') end
    if trip.status ~= 'in_progress' then return fail('ryde.pickUpRiderBeforeCompleting', 'Pick up your rider before completing the trip.') end
    -- Never charge a rider who is offline; the trip is held until they return or the grace ends.
    if trip.offline then return fail('ryde.partyDisconnected', 'Penumpang sedang terputus. Tunggu dia kembali.') end

    -- At the drop-off: full fare. Anywhere else: metered from pickup to here, capped at full fare.
    local early = not withinOf(src, trip.dropoff.x, trip.dropoff.y, config.ArriveRadius or 250.0)
    if early then
        local c = GetEntityCoords(GetPlayerPed(src))
        trip.fullFare = trip.fare
        trip.fare     = math.min(trip.fare, calcFare(roadKm(trip.pickup, { x = c.x, y = c.y })))
    end

    trips[trip.id] = nil
    riderActive[trip.riderUsername]   = nil
    driverActive[trip.driverUsername] = nil

    local riderSrc  = srcOf(trip.riderCid)
    local driverSrc = srcOf(trip.driverCid)
    local tax        = math.floor(trip.fare * (config.TaxRate or 0) + 0.5)
    local driverEarn = trip.fare - tax

    local paid = false
    if riderSrc and money.get(riderSrc, 'bank') >= trip.fare then
        money.remove(riderSrc, 'bank', trip.fare, 'Ryde fare')
        if driverSrc then money.add(driverSrc, 'bank', driverEarn, 'Pendapatan Ryde') end
        paid = true
        if tax > 0 then
            local okT, added = pcall(function() return exports['Renewed-Banking']:addAccountMoney(config.TaxAccount or 'government', tax) end)
            if okT and added then
                pcall(function() exports.f_tax:AddCitizenTax(tax) end)
            else
                print(('^1[f_phone:ryde]^0 pajak Ryde Rp %d (trip %s) gagal masuk ke rekening %s'):format(tax, trip.id, config.TaxAccount or 'government'))
            end
        end
    end

    if paid then
        bank.addExternal(trip.riderCid, { label = 'Perjalanan Ryde', amount = -trip.fare, category = 'ryde', counterparty = trip.driverName })
        notifyBank(trip.riderCid, ('Dipotong Rp %d untuk perjalanan Ryde-mu'):format(trip.fare))
        if driverSrc then
            bank.addExternal(trip.driverCid, { label = 'Pendapatan Ryde', amount = driverEarn, category = 'ryde', counterparty = trip.riderName })
            notifyBank(trip.driverCid, ('Kamu mendapat Rp %d dari perjalanan Ryde'):format(driverEarn))
        end
    end

    trip.status = 'completed'
    trip.paid   = paid
    store.insertRide(trip)
    store.bumpDriverStats(trip.driverUsername, paid and driverEarn or 0)

    pushTo(trip.riderCid, 'tripUpdate', {
        id = trip.id, rideId = trip.id, status = 'completed', role = 'rider',
        fare = trip.fare, paid = paid, driverName = trip.driverName,
    })
    pushTo(trip.driverCid, 'tripUpdate', {
        id = trip.id, status = 'completed', role = 'driver',
        fare = trip.fare, earn = paid and driverEarn or 0, paid = paid,
    })
    if early then
        notifyRyde(trip.riderCid, ('Perjalanan selesai sebelum tujuan. Tarif sesuai argo Rp %d. Ketuk untuk menilai pengemudimu.'):format(math.floor(trip.fare)))
    else
        notifyRyde(trip.riderCid, ('Perjalanan selesai. Tarif Rp %d. Ketuk untuk menilai pengemudimu.'):format(math.floor(trip.fare)))
    end
    return ok({ rideId = trip.id, fare = trip.fare, paid = paid })
end

---Cancels whatever the caller is currently in, derived from their own live state: a pending
---request, an un-accepted offer, or an engaged trip, with the counterpart notified.
---@param src integer player server id
---@return table result
function actions.cancel(src)
    local cid      = player.getIdentifier(src)
    local riderId  = cid and riderActive[cid] or nil
    if riderId then
        if requests[riderId] then
            requests[riderId] = nil
            riderActive[cid]  = nil
            broadcastToDrivers('requestRemoved', { id = riderId })
            broadcastWaiting()
            clearOffersFor(riderId, nil, 'cancelled')
            return ok({})
        end
        local trip = trips[riderId]
        if trip then
            -- Once riding, the rider ends the trip by asking the driver to finish (metered fare);
            -- only a vanished driver lets them walk away free.
            if trip.status == 'in_progress' and not (trip.offline and trip.offline.role == 'driver') then
                return fail('ryde.cannotCancelInTrip', 'Perjalanan sudah dimulai. Minta supir menekan Selesai untuk turun.')
            end
            cancelTrip(trip, 'rider')
            return ok({})
        end
    end

    local acc   = account(src)
    local drvId = acc and driverActive[acc.username] or nil
    local trip  = drvId and trips[drvId] or nil
    if trip then
        if trip.status == 'offered' then
            dropOffer(trip)
            pushTo(trip.riderCid, 'offerRemoved', { id = trip.id, requestId = trip.requestId })
        else
            cancelTrip(trip, 'driver')
        end
        return ok({})
    end
    return fail('ryde.nothingCancel', 'Nothing to cancel.')
end

---Rider rates their own finished ride 1-5 stars, optionally tipping rider bank -> driver bank;
---the rating is single-shot at the DB level and the driver gets a live update + notification.
---@param src integer player server id
---@param payload table { rideId: string, stars: number, tip?: number }
---@return table result { rated, tipPaid }
function actions.rate(src, payload)
    local cid = player.getIdentifier(src)
    if not cid then return fail('ryde.couldNotResolveCharacter', 'Could not resolve your character.') end
    local p = type(payload) == 'table' and payload or {}
    local stars = finite(p.stars)
    stars = stars and math.floor(stars) or 0
    if stars < 1 or stars > 5 then return fail('ryde.pick15Stars', 'Pick 1 to 5 stars.') end

    local ride = type(p.rideId) == 'string' and store.getRide(p.rideId) or nil
    if not (ride and ride.rider_username == cid) then return fail('ryde.rideNotFound', 'Ride not found.') end
    if ride.rating ~= nil then return fail('ryde.alreadyRatedTrip', 'You already rated this trip.') end

    local affected = store.setRideRating(ride.id, stars)
    if not (affected and affected > 0) then return fail('ryde.couldNotSaveRating', 'Could not save your rating.') end

    local drvUser = ride.driver_username
    if drvUser and drvUser ~= '' then store.addRating(drvUser, stars) end

    local drv       = drvUser and online[drvUser] or nil
    local driverSrc = drv and srcOf(drv.cid) or nil

    local tip = finite(p.tip)
    tip = tip and math.floor(tip) or 0
    local tipPaid = 0
    if tip > 0 and driverSrc then
        if money.get(src, 'bank') >= tip then
            money.remove(src, 'bank', tip, 'Tip Ryde')
            money.add(driverSrc, 'bank', tip, 'Tip Ryde')
            tipPaid = tip
        end
    end

    if tipPaid > 0 then
        bank.addExternal(cid, { label = 'Tip Ryde', amount = -tipPaid, category = 'ryde', counterparty = ride.driver_name })
        notifyBank(cid, ('Kamu memberi tip Rp %d'):format(tipPaid))
        if drv then
            bank.addExternal(drv.cid, { label = 'Tip Ryde', amount = tipPaid, category = 'ryde', counterparty = ride.rider_name })
            notifyBank(drv.cid, ('Kamu menerima tip Rp %d'):format(tipPaid))
        end
    end

    if driverSrc then
        pushTo(drv.cid, 'ratingReceived', { id = ride.id, stars = stars, tip = tipPaid })
        local who  = (ride.rider_name and ride.rider_name ~= '') and ride.rider_name or 'Your rider'
        local body = ('%s rated you %d★'):format(who, stars)
        if tipPaid > 0 then body = ('%s dan memberi tip Rp %d'):format(body, tipPaid) end
        TriggerClientEvent('f_phone:client:notify', driverSrc, {
            app = 'ryde', appId = 'ryde', time = 'now', title = 'Ryde', body = body,
        })
    end

    return ok({ rated = stars, tipPaid = tipPaid })
end

---Driver-info block for a trip, as the rider's UI expects it.
---@param t table trip record
---@return table
local function tripDriverInfo(t)
    return { name = t.driverName, car = t.vehicle, plate = t.plate, color = t.color, rating = t.driverRating, number = t.driverNumber }
end

---Returns the rider's live ride right now: a pending request with any open offers folded in, or
---an engaged trip.
---@param cid string rider citizenid
---@return table|nil
local function riderActivePayload(cid)
    local id  = riderActive[cid]
    local req = id and requests[id] or nil
    if req then
        local offers = {}
        for tid, t in pairs(trips) do
            if t.requestId == id and t.status == 'offered' then
                offers[#offers + 1] = { tripId = tid, fare = t.fare, driver = tripDriverInfo(t) }
            end
        end
        return {
            id = req.id, status = (#offers > 0) and 'offered' or 'finding',
            pickup = req.pickup, dropoff = req.dropoff, distance = req.distance,
            payment = req.payment, fare = req.fare, createdAt = req.createdAt, riderName = req.riderName,
            offers = offers,
        }
    end
    local t = id and trips[id] or nil
    if t then
        return {
            id = t.id, tripId = t.id, status = t.status,
            pickup = t.pickup, dropoff = t.dropoff, distance = t.distance,
            payment = t.payment, fare = t.fare, riderName = t.riderName,
            driver = tripDriverInfo(t),
        }
    end
    return nil
end

---The driver's live engaged trip (offered -> in_progress), driver perspective.
---@param username string|nil driver account username
---@return table|nil
local function driverActivePayload(username)
    local id = username and driverActive[username] or nil
    local t  = id and trips[id] or nil
    if not t then return nil end
    return {
        id = t.id, tripId = t.id, status = t.status,
        pickup = t.pickup, dropoff = t.dropoff, distance = t.distance,
        payment = t.payment, fare = t.fare, riderName = t.riderName, riderNumber = t.riderNumber,
    }
end

---Re-syncs the caller's live Ryde state on app open: rider/driver live payloads, the most recent
---persisted ride when nothing is live rider-side, and the open board for on-duty drivers. Read-only.
---@param src integer player server id
---@return table result { rider, driver, lastEnded, requests }
function actions.sync(src)
    local cid = player.getIdentifier(src)
    if not cid then return fail('ryde.couldNotResolveCharacter', 'Could not resolve your character.') end
    local acc    = account(src)
    local rider  = riderActivePayload(cid)
    local driver = acc and driverActivePayload(acc.username) or nil
    local lastEnded
    if not rider then
        local row = store.latestRiderRide(cid)
        if row then lastEnded = { id = row.id, status = row.status, fare = tonumber(row.fare) or 0 } end
    end
    local board
    if acc and online[acc.username] then
        board = {}
        for _, r in pairs(requests) do board[#board + 1] = publicRequest(r) end
    end
    return ok({ rider = rider, driver = driver, lastEnded = lastEnded, requests = board })
end

---Starts/stops the live peer-location stream while the caller looks at a trip map; only the
---trip's own rider or driver may watch, with the role fixed server-side.
---@param src integer player server id
---@param payload table { tripId: string, on: boolean }
---@return table result
function actions.watchTrip(src, payload)
    local p = type(payload) == 'table' and payload or {}
    if not p.on then tripViewers[src] = nil; return ok({}) end
    local trip = p.tripId and trips[p.tripId] or nil
    if not trip then tripViewers[src] = nil; return fail('ryde.noSuchTrip', 'No such trip.') end
    local cid = player.getIdentifier(src)
    local acc = account(src)
    local isRider  = trip.riderCid == cid
    local isDriver = acc and trip.driverUsername == acc.username
    if not (isRider or isDriver) then return fail('ryde.notTrip', 'Not your trip.') end
    tripViewers[src] = { tripId = p.tripId, role = isDriver and 'driver' or 'rider' }
    return ok({})
end

-- Live peer-location push loop: every 500ms, pushes each watcher's counterpart position
-- (server-side coords); watchers whose trip ended or who disconnected are dropped.
CreateThread(function()
    if not util.appEnabled('ryde') then return end

    while true do
        Wait(500)
        for vsrc, w in pairs(tripViewers) do
            if not GetPlayerName(vsrc) then
                tripViewers[vsrc] = nil
            else
                local trip = w.tripId and trips[w.tripId] or nil
                if not trip then
                    tripViewers[vsrc] = nil
                else
                    local otherCid  = (w.role == 'driver') and trip.riderCid or trip.driverCid
                    local otherRole = (w.role == 'driver') and 'rider' or 'driver'
                    local osrc = otherCid and srcOf(otherCid) or nil
                    if osrc then
                        local ped = GetPlayerPed(osrc)
                        if ped and ped ~= 0 then
                            local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
                            local last = w.last
                            local moved = not last or #(c - last.c) > 1.0 or math.abs(h - last.h) > 5.0
                            if moved then
                                w.last = { c = c, h = h }
                                TriggerClientEvent(EV .. 'peerLocation', vsrc, {
                                    tripId = w.tripId, role = otherRole,
                                    x = c.x, y = c.y, h = h,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end)

---Returns every ride the caller took part in, split into rider/driver entries; riders keyed by
---citizenid, drivers by account username. Read-only.
---@param src integer player server id
---@return table result { asRider, asDriver }
function actions.history(src)
    local cid = player.getIdentifier(src)
    if not cid then return fail('ryde.couldNotResolveCharacter', 'Could not resolve your character.') end
    local acc = account(src)
    local driverKey = (acc and acc.username) or cid
    local rows = store.ridesForUser(cid, driverKey)
    local asRider, asDriver = {}, {}
    for _, r in ipairs(rows) do
        local entry = {
            id = r.id, status = r.status, fare = r.fare, paid = r.paid == true or r.paid == 1 or r.paid == '1', payment = r.payment,
            pickup   = { label = r.pickup_label,  x = r.pickup_x,  y = r.pickup_y },
            dropoff  = { label = r.dropoff_label, x = r.dropoff_x, y = r.dropoff_y },
            distance = r.distance, rating = r.rating, createdAt = r.created_at,
            riderName = r.rider_name, driverName = r.driver_name,
        }
        if r.rider_username  == cid       then asRider[#asRider + 1]   = entry end
        if r.driver_username == driverKey then asDriver[#asDriver + 1] = entry end
    end
    return ok({ asRider = asRider, asDriver = asDriver })
end

---Returns the top drivers server-wide (confidence-weighted rating), with avg_rating coerced and
---rounded to two decimals. Read-only.
---@return table result { leaders }
function actions.leaderboard()
    local rows = store.leaderboard(50, config.LeaderboardPriorRating or 4.5, config.LeaderboardWeight or 10)
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = {
            username = r.username,
            name   = (r.display_name and r.display_name ~= '') and r.display_name or r.username,
            rating = lib.math.round((tonumber(r.avg_rating) or 5), 2),
            trips  = tonumber(r.trips) or 0,
            color  = r.color,
        }
    end
    return ok({ leaders = out })
end

---Returns the caller's own Ryde profile: account identity, driver card + lifetime stats,
---current duty state, and whatever ride/trip they're active in. Read-only.
---@param src integer player server id
---@return table result
function actions.me(src)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end
    local d = store.getDriver(acc.username)
    local rating = (d and d.rating_count > 0) and (d.rating_sum / d.rating_count) or 5.0
    return ok({
        username = acc.username,
        name     = acc.name,
        driver   = d and {
            vehicle = d.vehicle, plate = d.plate, color = d.color,
            rating = lib.math.round(rating, 2),
            trips = d.trips, earnings = d.earnings_total,
        } or nil,
        online = online[acc.username] ~= nil,
        active = riderActive[acc._cid] or driverActive[acc.username] or nil,
    })
end

---Permanently deletes the caller's own Ryde account: pulls them off duty, withdraws an
---un-accepted offer or cancels an engaged trip, then drops the driver record and the account.
---@param src integer player server id
---@return table result
function actions.deleteAccount(src)
    local acc = account(src)
    if not acc then return fail('ryde.signRydeFirst', 'Sign in to Ryde first.') end

    online[acc.username] = nil
    local tripId = driverActive[acc.username]
    local trip   = tripId and trips[tripId] or nil
    if trip then
        if trip.status == 'offered' then
            dropOffer(trip)
            pushTo(trip.riderCid, 'offerRemoved', { id = trip.id, requestId = trip.requestId })
        else
            cancelTrip(trip, 'driver')
        end
    end

    store.deleteDriver(acc.username)
    acctStore.deleteAccount(acc.id)
    return ok({})
end

---Client-facing slice of configs/ryde.lua: quick-pick destinations, the driver's cut, and the
---leaderboard weighting. Read-only.
---@return table result
function actions.config()
    return ok({
        locations    = config.Locations or {},
        driverCut    = 1.0 - (config.TaxRate or 0),
        baseFare     = config.BaseFare or 0,
        perKm        = config.PerKm or 0,
        roadFactor   = config.RoadFactor or 1.0,
        minFare      = config.MinFare or 0,
        maxFare      = config.MaxFare or 0,
        leaderPrior  = config.LeaderboardPriorRating or 4.5,
        leaderWeight = config.LeaderboardWeight or 10,
    })
end

---Handles a player leaving: clears the per-src caches, drops them from the duty board, bins
---their pending request and its bids, withdraws an offered trip, and cancels an engaged trip.
---@param src number player server id
function actions.onPlayerDropped(src)
    local cid = srcCid[src] or player.getIdentifier(src)
    srcCid[src] = nil
    tripViewers[src] = nil
    if not cid then return end
    for username, d in pairs(online) do
        -- A driver on a held trip stays registered so they are back on duty if they return.
        if d.cid == cid and not driverActive[username] then online[username] = nil; break end
    end
    for id, r in pairs(requests) do
        if r.riderCid == cid then
            requests[id] = nil
            riderActive[r.riderUsername] = nil
            broadcastToDrivers('requestRemoved', { id = id })
            broadcastWaiting()
            clearOffersFor(id, nil, 'cancelled')
        end
    end
    for id, t in pairs(trips) do
        if t.riderCid == cid or t.driverCid == cid then
            if t.status == 'offered' then
                dropOffer(t)
                if t.driverCid == cid then
                    pushTo(t.riderCid, 'offerRemoved', { id = id, requestId = t.requestId })
                end
            elseif t.offline then
                -- Both sides gone: nothing left to hold.
                cancelTrip(t, 'disconnect')
            else
                holdTrip(t, cid)
            end
        end
    end
end

---Hands a held trip back to a player who reconnected within the grace window and tells the
---other side the trip continues.
---@param src number player server id
function actions.onPlayerLoaded(src)
    local cid = player.getIdentifier(src)
    if not cid then return end
    srcCid[src] = cid
    for _, t in pairs(trips) do
        if t.offline and t.offline.cid == cid then
            t.offline = nil
            local other = (t.riderCid == cid) and t.driverCid or t.riderCid
            local who   = (t.riderCid == cid) and 'Penumpang' or 'Supir'
            notifyRyde(other, ('%s sudah kembali. Perjalanan dilanjutkan.'):format(who))
        end
    end
end

return actions
