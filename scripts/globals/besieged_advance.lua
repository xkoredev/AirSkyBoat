require('scripts/globals/besieged_types')
require('scripts/globals/besieged_utils')

xi = xi or {}
xi.besieged = xi.besieged or {}

local advance = {}
local zoneDataLookup = {}

-----------------------------------
--        Static Data            --
-----------------------------------

advance.waves =
{
    [xi.besieged.STRONGHOLD.MAMOOL] =
    {
        npcOffset = 16986432,
        npcCount = 78,
        zone = xi.zone.WAJAOM_WOODLANDS,
    },
    [xi.besieged.STRONGHOLD.HALVUNG] =
    {
        npcOffset = 16986511,
        npcCount = 75,
        zone = xi.zone.WAJAOM_WOODLANDS,
    },
    [xi.besieged.STRONGHOLD.ARRAPAGO] =
    {
        npcOffset = 16990508,
        npcCount = 82,
        zone = xi.zone.BHAFLAU_THICKETS,
    },
}

advance.paths =
{
    [xi.zone.WAJAOM_WOODLANDS] =
    {
        spawn = { x = -642, y = -7.7, z = -511, rot = 206 },
        nodes =
        {
            { x = -619.0587, y = -18.675, z = -399.8357 },
            { x = -525.5234, y = -7.906416, z = -363.3283 },
            { x = -479.8322, y = -7.527113, z = -464.4076 },
            { x = -441.8868, y = -20.03747, z = -417.2119 },
            { x = -378.1036, y = -9.5, z = -423.2526 },
            { x = -381.6880, y = -9.344501, z = -500.4346 },
            { x = -303.5308, y = -10, z = -506.9288 },
            { x = -260.7479, y = -9.322526, z = -499.6752 },
            { x = -250.1563, y = -18, z = -413.6047 },
            { x = -181.2190, y = -18.0786, z = -424.5765 },
            { x = -173.1068, y = -19.08762, z = -572.7558 },
            { x = -107.1889, y = -19.39359, z = -570.5305 },
            { x = -99.94523, y = -18.675, z = -521.3529 },
            { x = -97.87173, y = -17.50202, z = -459.3636 },
            { x = -59.00119, y = -17.2, z = -459.4464 },
            { x = -54.88820, y = -18.92977, z = -372.9678 },
            { x = -37.25807, y = -16, z = -318.4255 },
            { x = -15.66920, y = -18, z = -284.912 },
            { x = 43.27002, y = -18.4552, z = -261.7623 },
            { x = 109.0369, y = -18.63555, z = -261.2961 },
            { x = 152.8055, y = -19.8563, z = -227.8405 },
            { x = 172.6012, y = -20.25, z = -222.6397 },
            { x = 185.5435, y = -20.25, z = -200.3795 },
            { x = 180.8445, y = -17.33609, z = -140.9823 },
            { x = 218.5847, y = -17.51233, z = -141.0017 },
            { x = 231.6042, y = -19.35, z = -57.68763 },
            { x = 373.6007, y = -15.65175, z = -42.42706 },
            { x = 415.3802, y = -26, z = 23.12399 },
            { x = 423.0103, y = -25.5, z = 61.49006 },
            { x = 460.9417, y = -25.3508, z = 58.40694 },
            { x = 467.4962, y = -28.25, z = 197.9016 },
            { x = 488.6336, y = -26.07941, z = 252.1663 },
            { x = 501.6299, y = -25.50484, z = 340.083 },
            { x = 583.1116, y = -26, z = 349.4377 },
            { x = 610.0000, y = -23, z = 356 },
        },
    },
    [xi.zone.BHAFLAU_THICKETS] =
    {
        spawn = { x = 68.3, y = -33.8, z = 625, rot = 80 },
        nodes =
        {
            { x = 61.29055, y = -34.86802, z = 532.2369 },
            { x = 99.87259, y = -33.41819, z = 538.6082 },
            { x = 98.68553, y = -33.32568, z = 498.3203 },
            { x = 188.4592, y = -33.30118, z = 504.7366 },
            { x = 239.6945, y = -32, z = 481.5654 },
            { x = 284.2296, y = -23.89091, z = 445.7726 },
            { x = 326.214, y = -16.28328, z = 397.0236 },
            { x = 355.0127, y = -18.85539, z = 379.1394 },
            { x = 420.5651, y = -17.53827, z = 378.1592 },
            { x = 433.076, y = -15.81889, z = 277.2386 },
            { x = 426.9081, y = -19.69058, z = 248.9769 },
            { x = 418.7162, y = -9.515398, z = 178.7158 },
            { x = 311.712, y = -11.50318, z = 177.7691 },
            { x = 300.4769, y = -9.272595, z = 100.4119 },
            { x = 339.5098, y = -9.324105, z = 99.23538 },
            { x = 348.0887, y = -11.18476, z = 17.03856 },
            { x = 380.5456, y = -9.452579, z = 18.72308 },
            { x = 382.252, y = -10, z = -27.24173 },
            { x = 410.0709, y = -7.75, z = -37.67746 },
            { x = 431.0000, y = -7.74, z = -38.90000 },
        },
    },
}

-----------------------------------
--      Helper Methods           --
-----------------------------------

local spawnMob = function(npcId, zoneId, strongholdId, pos, path)
    local zone = GetZone(zoneId)
    local zoneData = zoneDataLookup[zoneId]
    if zoneData == nil then
        xi.besieged.debugLogf("Zone data not initialized for zone: %s", zone:getName())
        return
    end

    -- Spawn the mob
    local mob = SpawnMob(npcId)
    if mob == nil then
        xi.besieged.debugLogf("Failed to spawn mob: %i in zone: %s", npcId, zone:getName())
        return
    end

    -- Set initial pos and add to zone data state
    -- Make sure mobs don't aggro or link.
    mob:setMobMod(xi.mobMod.NO_LINK, 1)
    mob:setMobMod(xi.mobMod.NO_AGGRO, 1)
    mob:setPos(pos.x, pos.y, pos.z, pos.rot)

    -- Start path, and set to despawn on arrival
    -- Script flag is necessary for the callback. Coords to pass a set of coords.
    mob:pathThrough(path, bit.bor(xi.path.flag.COORDS, xi.path.flag.SCRIPT))
    mob:addListener("PATH_COMPLETE", "PATH_COMPLETE_BESIEGED", function(mobArg)
        local mobId = mobArg:getID()

        -- Mark the mob as having reached alzhabi. It will be removed from the table on despawn
        xi.besieged.debugLogf("%s (%i) reached Al Zahbi from %s", mobArg:getName(), mobId, zone:getName())
        zoneData.numReachedAlzhabi = zoneData.numReachedAlzhabi + 1

        -- Actually despawn the mob
        DespawnMob(mobId, zone)
    end)

    -- On mob despawn, if that was the last one,
    -- trigger advance phase end
    mob:addListener("DESPAWN", "DESPAWN_BESIEGED", function(mobArg)
        -- Remove the mob from mobs table
        local index = utils.find(zoneData.mobs, mobArg:getID())
        table.remove(zoneData.mobs, index)
        xi.besieged.debugLogf("Mob despawn: %s (%i). Mobs remaining: %i", mobArg:getName(), mobArg:getID(), #zoneData.mobs)

        -- Check if all mobs have arrived or been killed
        if #zoneData.mobs == 0 then
            -- Mark phase complete
            xi.besieged.debugLog("All mobs despawned. Ending advance phase.")

            -- Either advance to attackin alzhabi or retreat, based on the mobs that have
            -- reached alzhabi
            if zoneData.numReachedAlzhabi == 0 then
                -- The Mamool Ja Savages have retreated.
                BesiegedAdvancePhaseEnded(strongholdId, true)
                xi.besieged.broadcastBesiegedUpdate(9 + strongholdId - 1)
                xi.besieged.debugLog("Advance phase intercepted")
            else
                -- The Mamool Ja Savages have breached the Balrahn Defense Line! Intercept their forces in Al Zahbi's Bastion!
                BesiegedAdvancePhaseEnded(strongholdId, false)
                xi.besieged.broadcastBesiegedUpdate(3 + strongholdId - 1)
                xi.besieged.debugLog("Advance phase complete. Starting Besieged battle.")
            end

            -- Reset zone data
            zoneData.beastmenSpawned = false
            zoneData.numReachedAlzhabi = 0
        end
    end)

    table.insert(zoneData.mobs, npcId)
    xi.besieged.debugLogf("Spawn %s (%i) in %s", mob:getName(), npcId, zone:getName())
end

-----------------------------------
--      Public Methods           --
-----------------------------------

advance.initZone = function(zone)
    local zoneId = zone:getID()

    -- Init empty zone data
    zoneDataLookup[zoneId] =
    {
        beastmenSpawned = false,
        mobs = {},
        numReachedAlzhabi = 0,
    }
end

advance.onZoneTick = function(zone)
    local zoneId = zone:getID()

    if zoneDataLookup[zoneId] == nil then
        return
    end

    if zoneDataLookup[zoneId].beastmenSpawned then
        return
    end

    -- For all beastmen strongholds (1 to 3),
    -- check their besieged info and spawn beastmen
    -- if in the advancing stage.
    for strongholdId = 1, 3 do
        if advance.waves[strongholdId].zone == zone:getID() then
            local stronghold = GetBeastmenStrongholdInfo(strongholdId)
            if stronghold["orders"] == xi.besieged.BEASTMEN_ORDERS.ADVANCE then
                advance.spawnBeastmen(strongholdId, zoneId)
            end
        end
    end
end

advance.spawnBeastmen = function(strongholdId, zoneId)
    local zoneData = zoneDataLookup[zoneId]
    local zone = GetZone(zoneId)
    if zoneData == nil then
        xi.besieged.debugLogf("Zone data not initialized for zone: %s", zone:getName())
        return
    end

    local stronghold = GetBeastmenStrongholdInfo(strongholdId)
    local wave = advance.waves[strongholdId]
    local npcOffset = wave.npcOffset
    local npcCount = wave.npcCount
    local path = advance.paths[zoneId]

    -- % of mobs spawned is based on the stronghold forces
    -- Forces can range from 100 to 200. With 100 spawning the minimum amount
    -- of mobs, and 200 spawning all of npcCount
    local minSpawns = 15
    local spawnRatio = (stronghold["forces"] - 100) / 100
    local numSpawns = math.floor((npcCount - minSpawns) * spawnRatio + minSpawns)
    numSpawns = utils.clamp(numSpawns, minSpawns, npcCount)

    -- Spawn mobs
    for i = 1, numSpawns do
        local npcId = npcOffset + i - 1
        spawnMob(npcId, zoneId, strongholdId, path.spawn, path.nodes)
    end

    -- Update state and send zone message
    -- Note: strongholdId - 1 because the first beastmen stronghold is indexed at 1
    zoneData.beastmenSpawned = true
    xi.besieged.broadcastBesiegedUpdate(strongholdId - 1)
end

advance.despawnBeastmen = function(zoneId)
    local zoneData = zoneDataLookup[zoneId]

    if zoneData == nil then
        return
    end

    if not zoneData.beastmenSpawned then
        return
    end

    local zone = GetZone(zoneId)
    for _, npcId in pairs(zoneData.mobs) do
        xi.besieged.debugLogf("Despawn mob: %i in zone: %s", npcId, zone:getName())
        DespawnMob(npcId, zone)
    end
end

advance.setMobSpeed = function(zoneId, speed)
    local zoneData = zoneDataLookup[zoneId]
    -- Iterate through all mobs, and jack up their movement speed
    for _, npcId in pairs(zoneData.mobs) do
        local mob = GetMobByID(npcId)
        if mob ~= nil then
            mob:setSpeed(speed)
        end
    end
end

return advance
