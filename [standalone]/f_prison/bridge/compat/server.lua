local resources     = require 'bridge.compat.resources'

-- When setJailTime is called, compat for other resources is called
function syncJailCompatibility(src, time)
    if resources.randol_medical then
        exports.randol_medical:SetJailState(src, (time > 0))
    end

    -- Add other compat here (Medical, etc)
end

-- Removed: 'prison:server:SetJailStatus' (any client could set its own sentence to 0) and
-- 'police:server:JailPlayer' (jailing without an MDT report). Jailing goes through the MDT, which
-- calls exports['f_prison']:JailPlayer (server/sv_sentence.lua).