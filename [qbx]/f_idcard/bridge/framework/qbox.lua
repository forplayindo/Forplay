if GetResourceState('qbx_core') ~= 'started' then return end

local sharedConfig = require 'config.shared'
local ox_inventory = exports.ox_inventory

--- Masa berlaku kartu (detik): expiryDays per kartu, kalau tidak ada pakai licenseExpiryDays
---@param itemName string
---@return integer
function LicenseExpirySeconds(itemName)
    local license = sharedConfig.licenses[itemName]
    return ((license and license.expiryDays) or sharedConfig.licenseExpiryDays) * 86400
end

--- Convert sex number to string M or F
---@param sex number
---@return string
local function GetStringSex(sex)
    return sex == 1 and 'F' or 'M'
end

--- Get badge for license
---@param src number Source number
---@param itemName string
---@return string | table
local function GetBadge(src, itemName)
    if not sharedConfig.licenses[itemName].badge then return 'none' end

    local player = exports.qbx_core:GetPlayer(src)
    return {
        img = sharedConfig.licenses[itemName].badge,
        grade = player.PlayerData.job.grade.name
    }
end

--- Create metadata for license
---@param src number Source number
---@param itemTable string | table Item name or table of item names
local function CreateMetaLicense(src, itemTable)
    local player = exports.qbx_core:GetPlayer(src)

    if type(itemTable) == "string" then
        itemTable = {itemTable}
    end

    if type(itemTable) == "table" then
        for _, v in pairs(itemTable) do
            local metadata = {
                cardtype = v,
                citizenid = player.PlayerData.citizenid,
                firstname = player.PlayerData.charinfo.firstname,
                lastname = player.PlayerData.charinfo.lastname,
                birthdate = player.PlayerData.charinfo.birthdate,
                sex =  GetStringSex(player.PlayerData.charinfo.gender),
                nationality = player.PlayerData.charinfo.nationality,
                badge = GetBadge(src, v),
                expireDate = os.time() + LicenseExpirySeconds(v)
            }

            exports.ox_inventory:AddItem(src, v, 1, metadata)
        end
    else
        print("Invalid parameter type")
    end
end

exports('CreateMetaLicense', CreateMetaLicense)

--- Renew an existing license's expiry date, or issue a brand new one if the
--- player doesn't already have it (so requesting a license twice extends it
--- instead of creating a duplicate item)
---@param src number Source number
---@param itemName string
---@return 'renewed' | 'created'
local function RenewOrCreateLicense(src, itemName)
    local found = ox_inventory:Search(src, 1, itemName)
    for _, v in pairs(found) do --luacheck: ignore
        v.metadata.expireDate = os.time() + LicenseExpirySeconds(itemName)
        ox_inventory:SetMetadata(src, v.slot, v.metadata)
        return 'renewed'
    end

    CreateMetaLicense(src, itemName)
    return 'created'
end

exports('RenewOrCreateLicense', RenewOrCreateLicense)

--- Extend the expiry of the license the player carries by licenseExpiryDays, counted from
--- whichever is later: now or the current expiry (early renewals don't lose days)
---@param src number Source number
---@param itemName string
---@return number? newExpiry nil when the player doesn't carry the license
local function ExtendLicense(src, itemName)
    local found = ox_inventory:Search(src, 1, itemName)
    for _, v in pairs(found or {}) do --luacheck: ignore
        local base = math.max(os.time(), tonumber(v.metadata.expireDate) or 0)
        v.metadata.expireDate = base + LicenseExpirySeconds(itemName)
        ox_inventory:SetMetadata(src, v.slot, v.metadata)
        return v.metadata.expireDate
    end
end

exports('ExtendLicense', ExtendLicense)

--- Get metadata for license
---@param src number Source number
---@param itemTable string | table Item name or table of item names
local function GetMetaLicense(src, itemTable)
    local player = exports.qbx_core:GetPlayer(src)

    if type(itemTable) == "string" then
        itemTable = {itemTable}
    end

    if type(itemTable) == "table" then
        for _, v in pairs(itemTable) do --luacheck: ignore
            local metadata = {
                cardtype = v,
                citizenid = player.PlayerData.citizenid,
                firstname = player.PlayerData.charinfo.firstname,
                lastname = player.PlayerData.charinfo.lastname,
                birthdate = player.PlayerData.charinfo.birthdate,
                sex =  GetStringSex(player.PlayerData.charinfo.gender),
                nationality = player.PlayerData.charinfo.nationality,
                badge = GetBadge(src,v),
                -- dihitung sejak kartu diberikan (KTP sementara: 1 hari sejak pertama masuk kota)
                expireDate = os.time() + LicenseExpirySeconds(v)
            }
            return metadata
        end
    else
        print("Invalid parameter type")
    end
end

exports('GetMetaLicense', GetMetaLicense)