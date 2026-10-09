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
        print("No se pudo detectar automáticamente el framework. Asegúrate de que 'qb-core' esté iniciado.")
        return
    end

    QBCore = exports['qb-core']:GetCoreObject()
    Framework.GetPlayerData = function()
        return QBCore.Functions.GetPlayerData()
    end

elseif Config.Framework == "esx" then
    if not GetResourceState('es_extended') == 'started' then
        print("No se pudo detectar automáticamente el framework. Asegúrate de que 'es_extended' esté iniciado.")
        return
    end

	ESX = exports["es_extended"]:getSharedObject()
    Framework.GetPlayerData = function()
        return ESX.GetPlayerData()
    end
end
