---------------------------------------------------------------------------------------------------
-- func: garrison <command> (player)
-- commands:
-- !garrison start (player) starts the garrison for the given player (or targetted one). This bypasses requirements like lockout
-- !besieged stop  (player) stops the besieged (if any) currently running in the player's zone
-- !garrison win (player) win the garrison (if any) currently running in the player's zone
---------------------------------------------------------------------------------------------------

require("scripts/globals/common")
require("scripts/globals/besieged_data")
require("scripts/globals/besieged")

cmdprops =
{
    permission = 1,
    parameters = "sii"
}

function error(player, msg)
    local usage = "Usage: !besieged <command>"
    player:PrintToPlayer(msg .. "\n" .. usage)
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
        ["start"] = function()
          if not validateStrongholdId(player, strongholdId) then
            return
          end

          local zoneId = xi.besieged.advance.waves[strongholdId].zone
          local zone = GetZone(zoneId)

          player:PrintToPlayer("Starting besieged in zone: " .. zone:getName(), xi.msg.channel.SYSTEM_2, "")
          xi.besieged.spawnBeastmen(strongholdId, zoneId)
        end,
        ["speed"] = function()
          if not validateStrongholdId(player, strongholdId) then
            return
          end

          player:PrintToPlayer("Setting besieged speed in zone: " .. zone:getName() .. " to " .. speed, xi.msg.channel.SYSTEM_2, "")
          local zoneId = xi.besieged.advance.waves[strongholdId].zone
          xi.besieged.setMobSpeed(zoneId, speed)
        end,
        ["stop"] = function()
          if not validateStrongholdId(player, strongholdId) then
            return
          end

          player:PrintToPlayer("Stopping besieged in zone: " .. zone:getName(), xi.msg.channel.SYSTEM_2, "")
          local zoneId = xi.besieged.advance.waves[strongholdId].zone
          xi.besieged.despawnBeastmen(zoneId)
        end,
    }
end

function validateStrongholdId(player, strongholdId)
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
