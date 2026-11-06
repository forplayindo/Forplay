return {
    updateInterval = 5, -- how often to update player data in minutes

    money = {
        ---@alias MoneyType 'cash' | 'bank' | 'crypto'
        ---@alias Money {cash: number, bank: number, crypto: number}
        ---@type Money
        moneyTypes = { cash = 1000000, bank = 4000000, crypto = 0, dirty = 0 }, -- type = startamount - Add or remove money types for your server (for ex. blackmoney = 0), remember once added it will not be removed from the database!
        -- f_dirtymoney: 'dirty' = bagian kotor dari cash (bukan uang terpisah), dikelola f_dirtymoney
        dontAllowMinus = { 'cash', 'crypto', 'dirty' }, -- Money that is not allowed going in minus
        paycheckTimeout = 15, -- The time in minutes that it will give the paycheck
        paycheckSociety = false -- If true paycheck will come from the society account that the player is employed at
    },

    player = {
        hungerRate = 5.2, -- Rate at which hunger goes down.
        thirstRate = 5.2, -- Rate at which thirst goes down.

        ---@enum BloodType
        bloodTypes = {
            'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
        },

        ---@alias UniqueIdType 'citizenid' | 'AccountNumber' | 'PhoneNumber' | 'FingerId' | 'WalletId' | 'SerialNumber'
        ---@type table<UniqueIdType, {valueFunction: function}>
        identifierTypes = {
            citizenid = {
                valueFunction = function()
                    -- Forplay format: F + 7 random digits (e.g. F4829136). GenerateUniqueIdentifier
                    -- re-rolls until the DB has no match. Existing characters keep their old id.
                    return 'F' .. lib.string.random('1111111')
                end,
            },
            AccountNumber = {
                valueFunction = function()
                    return 'US0' .. math.random(1, 9) .. 'QBX' .. math.random(1111, 9999) .. math.random(1111, 9999) .. math.random(11, 99)
                end,
            },
            PhoneNumber = {
                valueFunction = function()
                    return math.random(100,999) .. math.random(1000000,9999999)
                end,
            },
            FingerId = {
                valueFunction = function()
                    return lib.string.random('...............')
                end,
            },
            WalletId = {
                valueFunction = function()
                    return 'QB-' .. math.random(11111111, 99999999)
                end,
            },
            SerialNumber = {
                valueFunction = function()
                    return math.random(11111111, 99999999)
                end,
            },
        }
    },

    ---@alias TableName string
    ---@alias ColumnName string
    ---@type [TableName, ColumnName][]
    characterDataTables = {
        {'properties', 'owner'},
        {'bank_accounts_new', 'id'},
        {'playerskins', 'citizenid'},
        {'player_mails', 'citizenid'},
        {'player_outfits', 'citizenid'},
        {'player_vehicles', 'citizenid'},
        {'player_groups', 'citizenid'},
        {'players', 'citizenid'},
    }, -- Rows to be deleted when the character is deleted

    server = {
        pvp = true, -- Enable or disable pvp on the server (Ability to shoot other players)
        closed = false, -- Set server closed (no one can join except people with ace permission 'qbadmin.join')
        closedReason = 'Server Closed', -- Reason message to display when people can't join the server
        whitelist = false, -- Enable or disable whitelist on the server
        whitelistPermission = 'admin', -- Permission that's able to enter the server when the whitelist is on
        discord = '', -- Discord invite link
        checkDuplicateLicense = true, -- Check for duplicate rockstar license on join
        ---@deprecated use cfg ACE system instead
        requireOptIn = false, -- Set to false to disable the requirement to use the /optin command before accessing admin commands
        permissions = { 'god', 'admin', 'mod' }, -- Add as many groups as you want here after creating them in your server.cfg
    },

    characters = {
        playersNumberOfCharacters = { -- Define maximum amount of player characters by rockstar license (you can find this license in your server's database in the player table)
            ['license2:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = 5,
        },

        defaultNumberOfCharacters = 1, -- Pemain biasa: 1 karakter
        adminNumberOfCharacters = 3, -- Pemain dengan ACE 'admin' (group.admin di server.cfg)
        allowDelete = false, -- Pemain tidak bisa menghapus karakter sendiri (ditolak di server)
        nationality = 'Indonesia', -- semua karakter baru dipaksa kewarganegaraan ini
        birthdate = { min = '1900-01-01', max = '2006-12-31' }, -- YYYY-MM-DD, dicek di server
    },

    -- this configuration is for core events only. putting other webhooks here will have no effect
    logging = {
        webhook = {
            ['default'] = nil, -- default
            ['joinleave'] = nil, -- default
            ['ooc'] = nil, -- default
            ['anticheat'] = nil, -- default
            ['playermoney'] = nil, -- default
        },
        role = {} -- Role to tag for high priority logs. Roles use <@%roleid> and users/channels are <@userid/channelid>
    },

    persistence = {
        lockState = 'lock', -- 'lock' : vehicle will be locked when spawned, 'unlock' : vehicle will be unlocked when spawned
    },

    giveVehicleKeys = function(src, plate, vehicle)
        return exports.f_vehiclekeys:GiveKeys(src, vehicle)
    end,

    setVehicleLock = function(vehicle, state)
        exports.f_vehiclekeys:SetLockState(vehicle, state)
    end,

    getSocietyAccount = function(accountName)
        return exports['Renewed-Banking']:getAccountMoney(accountName)
    end,

    removeSocietyMoney = function(accountName, payment)
        return exports['Renewed-Banking']:removeAccountMoney(accountName, payment)
    end,

    ---Paycheck function
    ---@param player Player Player object
    ---@param payment number Payment amount
    sendPaycheck = function (player, payment)
        -- f_paycheck: gaji disimpan, dicairkan di NPC Kantor Gaji (fallback langsung ke bank)
        if GetResourceState('f_paycheck') ~= 'started' or not exports.f_paycheck:Add(player.PlayerData.source, payment) then
            player.Functions.AddMoney('bank', payment)
            Notify(player.PlayerData.source, locale('info.received_paycheck', payment))
        end
        TriggerEvent('qbx_core:server:onPaycheck', player.PlayerData.source, payment)
    end,
}
