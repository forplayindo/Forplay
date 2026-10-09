
Framework = {}
Framework.PlayerData = {}

if Config.Framework == "auto" then
    if GetResourceState('qb-core') == 'started' then
        Config.Framework = 'qb'
    elseif GetResourceState('es_extended') == 'started' then
        Config.Framework = 'esx'
    else
        print("No se pudo detectar automáticamente el framework. Asegúrate de que 'qb-core' o 'es_extended' esté iniciado.")
        return
    end
end

if Config.Framework == "qb" then
	if not GetResourceState('qb-core') == 'started' then
        print("No se pudo detectar el framework. Asegúrate de que 'qb-core' esté iniciado.")
        return
    end

    QBCore = exports['qb-core']:GetCoreObject()
	Framework.GetPlayer = function(source)
        return QBCore.Functions.GetPlayer(source)
    end

    function getJobInf(xPlayer)
        return xPlayer.PlayerData.job.name
    end

    Framework.GetIdentifier = function(source)
        return QBCore.Functions.GetIdentifier(source, 'license')
    end

    Framework.GetGroup = function(source)
        return QBCore.Functions.GetPermission(source)
    end

    Framework.GetName = function(source)
        xPlayer = QBCore.Functions.GetPlayer(source)
        return xPlayer.PlayerData.charinfo.firstname..' '..xPlayer.PlayerData.charinfo.lastname
    end

    Framework.GetNamePlayer = function(source)
        return Framework.GetPlayer(source).PlayerData.charinfo.firstname..' '..Framework.GetPlayer(source).PlayerData.charinfo.lastname
    end

elseif Config.Framework == "esx" then
	if not GetResourceState('es_extended') == 'started' then
        print("No se pudo detectar el framework. Asegúrate de que 'es_extended' esté iniciado.")
        return
    end

	ESX = exports["es_extended"]:getSharedObject()
	Framework.GetPlayer = function(source)
        return ESX.GetPlayerFromId(source)
    end

    function getJobInf(source)
        return Framework.GetPlayer(source).job.name
    end

    Framework.GetIdentifier = function(source)
        return Framework.GetPlayer(source).getIdentifier()
    end

    Framework.GetGroup = function(source)
        return Framework.GetPlayer(source).getGroup()
    end

    Framework.GetNamePlayer = function(source)
        return Framework.GetPlayer(source).getName()
    end
end


--[[     S T A N D L O N E     ]]

-- GetIdentifiers
function GetPlayerGX(source, idType)
    local identifiers = GetPlayerIdentifiers(source)
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, idType .. ":") then
            return string.sub(identifier, #idType + 2)
        end
    end
    return 'Not Found'
end

-- GetIP
function GetPlayerIPGX(source)
    return GetPlayerEndpoint(source)
end
