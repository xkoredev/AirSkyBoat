---------------------------------------------------------------------------------------------------
-- func: garrison <command> (player)
-- commands:
-- !besieged advance <strongholdId> Starts the advancing phase of the given stronghold
-- !besieged retreat Ends the advancing phase of the stronghold advancing in the player's zone
-- !garrison speed <speed> Sets the speed of the advancing beastmen in the player's zone
---------------------------------------------------------------------------------------------------

-- Only commands should include this directly
local advance = require("scripts/globals/besieged_advance")
require("scripts/globals/common")

cmdprops =
{
    permission = 1,
    parameters = "sii"
}

function error(player, msg)
    local usage = "Usage: !besieged advance <strongholdId> | !besieged speed <speed> | !besieged retreat"
    player:PrintToPlayer(msg .. "\n" .. usage)
end

local validateStrongholdId = function(player, strongholdId)
    if strongholdId == nil then
        error(player, "Invalid stronghold id")
        return false
    end

    if strongholdId < 1 or strongholdId > 3 then
        error(player, "Invalid stronghold id. (Valid values are 1, 2, 3))")
        return false
    end

    return true
end

function onTrigger(player, command, strongholdId, speed)
    -- Validate command
    if command == nil then
        error(player, "Invalid command")
        return
    end

    local zone = player:getZone()
    switch(command): caseof
    {
        ["advance"] = function()
            if not validateStrongholdId(player, strongholdId) then
                return
            end

            local zoneId = advance.waves[strongholdId].zone
            player:PrintToPlayer("Advancing stronghold: " .. zone:getName(), xi.msg.channel.SYSTEM_2, "")
            advance.spawnBeastmen(strongholdId, zoneId)
        end,

        ["speed"] = function()
            player:PrintToPlayer("Setting advancing beastmen in zone: " .. zone:getName() .. " to " .. speed, xi.msg.channel.SYSTEM_2, "")
            advance.setMobSpeed(zone:getID(), speed)
        end,

        ["retreat"] = function()
            player:PrintToPlayer("Reatreating beastmen in zone: " .. zone:getName(), xi.msg.channel.SYSTEM_2, "")
            advance.despawnBeastmen(zone:getID())
        end,
    }
end
