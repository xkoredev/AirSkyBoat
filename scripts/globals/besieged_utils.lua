xi = xi or {}
xi.besieged = xi.besieged or {}

-- Prints the given message if DEBUG_BESIEGED is enabled
xi.besieged.debugLog = function(msg)
    if xi.settings.logging.DEBUG_BESIEGED then
        print("[Besieged]: " .. msg)
    end
end

-- Prints the given message with printf if DEBUG_BESIEGED is enabled
xi.besieged.debugLogf = function(msg, ...)
    if xi.settings.logging.DEBUG_BESIEGED then
        printf("[Besieged]: " .. msg, ...)
    end
end

-- Sends a message packet to all players in relevant zones
xi.besieged.broadcastBesiegedUpdate = function(offset)
    for _, zoneId in pairs(xi.besieged.msgZones) do
        SendLuaFuncStringToZone(zoneId, string.format([[
            local zoneId = %i
            local offset = %i
            local zone = GetZone(zoneId)
            local playersInZone = zone:getPlayers()
            for _, player in pairs(playersInZone) do
                player:messageText(player, zones[zoneId].text.BESIEGED_UPDATES_BASE + offset, 1)
            end
        ]], zoneId, offset))
    end
end
