LeasingExtensionSettingsEvent = {}
local LeasingExtensionSettingsEvent_mt = Class(LeasingExtensionSettingsEvent, Event)
InitEventClass(LeasingExtensionSettingsEvent, "LeasingExtensionSettingsEvent")

function LeasingExtensionSettingsEvent.emptyNew()
    local self = Event.new(LeasingExtensionSettingsEvent_mt)
    return self
end

function LeasingExtensionSettingsEvent.new()
    return LeasingExtensionSettingsEvent.emptyNew()
end

function LeasingExtensionSettingsEvent:readStream(streamId, connection)
    if LeasingExtension ~= nil then
        LeasingExtension.suppressNetworkEvent = true
        LeasingExtension:readSettingsFromStream(streamId)
        LeasingExtension.suppressNetworkEvent = false
        LeasingExtension:updateMenuState()
    end

    self:run(connection)
end

function LeasingExtensionSettingsEvent:writeStream(streamId, connection)
    if LeasingExtension ~= nil then
        LeasingExtension:writeSettingsToStream(streamId)
    end
end

function LeasingExtensionSettingsEvent:run(connection)
    if g_server ~= nil and LeasingExtension ~= nil then
        local isFromServer = connection ~= nil and connection.getIsServer ~= nil and connection:getIsServer()
        if not isFromServer then
            LeasingExtension:saveSettings()
            LeasingExtension:broadcastSettings(connection)
        end
    end
end
