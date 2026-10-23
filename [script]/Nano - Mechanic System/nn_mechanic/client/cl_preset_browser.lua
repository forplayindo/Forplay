communityBridge = communityBridge or exports.community_bridge.Bridge(exports.community_bridge)

local function triggerBridgeCallback(eventName, payload)
    return communityBridge.Callback.Trigger(eventName, payload)
end

local function handleNuiCallbackResponse(callback, result)
    if not result then
        callback({ success = false, error = "no_response" })
        return
    end
    callback(result)
end

local function registerNuiEventCallback(eventName, mapper)
    RegisterNUICallback(Events.Preset[eventName], function(data, callback)
        handleNuiCallbackResponse(callback, triggerBridgeCallback(Events.Preset[eventName], mapper and mapper(data) or data))
    end)
end

registerNuiEventCallback("Status", function(data)
    return data and data.forceRefresh == true
end)
registerNuiEventCallback("Browse")
registerNuiEventCallback("Get", function(data)
    return data and data.presetId
end)
registerNuiEventCallback("Submit")
registerNuiEventCallback("Apply")
registerNuiEventCallback("Vote", function(data)
    return data and data.presetId
end)
registerNuiEventCallback("Report")

RegisterNUICallback("nn_mechanic:preset:exportPreview", function(data, callback)
    handleNuiCallbackResponse(callback, triggerBridgeCallback("nn_mechanic:preset:exportPreview", data))
end)

RegisterNUICallback("nn_mechanic:preset:config", function(_, callback)
    local presetServiceConfig = Config and Config.PresetService
    callback({
        enabled = presetServiceConfig and presetServiceConfig.enabled == true,
        supportContact = presetServiceConfig and presetServiceConfig.supportContact or "",
    })
end)