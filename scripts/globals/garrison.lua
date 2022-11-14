-----------------------------------
-- Garrison
-----------------------------------
require('scripts/globals/mobs')
require('scripts/globals/common')
require('scripts/globals/items')
require('scripts/globals/npc_util')
require('scripts/globals/status')
require('scripts/globals/utils')
require('scripts/globals/zone')
require('scripts/globals/pathfind')
require('scripts/globals/garrison_data')
-----------------------------------
xi = xi or {}
xi.garrison = xi.garrison or {}
xi.garrison.lookup = xi.garrison.lookup or {}

xi.garrison.state =
{
    SPAWN_NPCS          = 0,
    BATTLE              = 1,
    CHECK_WAVE_PROGRESS = 2,
    SPAWN_MOBS          = 3,
    SPAWN_BOSS          = 4,
    GRANT_LOOT          = 5,
    ENDED               = 6,
}

-----------------------------------
-- Helpers
-----------------------------------

-- Prints the given message if DEBUG_GARRISON is enabled
local debugLog = function(msg)
    if xi.settings.main.DEBUG_GARRISON then
        print(msg)
    end
end

-- Prints the given message with printf if DEBUG_GARRISON is enabled
local debugLogf = function(msg, ...)
    if xi.settings.main.DEBUG_GARRISON then
        printf(msg, ...)
    end
end

-- Shows the given server message to all players if DEBUG_GARRISON is enabled
local debugPrintToPlayers = function(zoneData, msg)
    if xi.settings.main.DEBUG_GARRISON then
        for _, entityId in pairs(zoneData.players) do
            local entity = GetPlayerByID(entityId)
            if entity ~= nil then
                entity:PrintToPlayer(msg)
            end
        end
    end
end

-- Add level restriction effect
-- If a party member is KO'd during the Garrison, they're out.
-- Any players that are KO'd lose their level restriction and will be unable to help afterward.
-- Giving this the CONFRONTATION flag hooks into the target validation systme and stops outsiders
-- participating, for mobs, allies, and players.
local addLevelCap = function(entity, cap)
    entity:addStatusEffectEx(
        xi.effect.LEVEL_RESTRICTION,
        xi.effect.LEVEL_RESTRICTION,
        cap,
        0,
        0,
        0,
        0,
        0,
        xi.effectFlag.DEATH + xi.effectFlag.ON_ZONE + xi.effectFlag.CONFRONTATION)
end

-- Randomly assigns aggro between the given groups of entity IDs
local aggroGroups = function(group1, group2)
    for _, entityId1 in pairs(group1) do
        for _, entityId2 in pairs(group2) do
            local entity1 = GetMobByID(entityId1)
            local entity2 = GetMobByID(entityId2)

            if entity1 == nil or entity2 == nil then
                printf("[warning] Could not apply aggro because either %i or %i are not valid entities", entityId1, entityId2)
            else
                entity1:addEnmity(entity2, math.random(1, 5), math.random(1, 5))
                entity2:addEnmity(entity1, math.random(1, 5), math.random(1, 5))
            end
        end
    end
end

-- Spawns and npc for the given zone and with the given name, look, pose
-- Uses dynamic entities
local spawnNPC = function(zone, x, y, z, rot, name, look)
    local mob = zone:insertDynamicEntity({
        objtype = xi.objType.MOB,
        allegiance = xi.allegiance.PLAYER,
        name = name,
        x = x,
        y = y,
        z = z,
        rotation = rot,
        look = look,

        -- TODO: Make relevant group and pool entries for NPCs
        groupId = 35,
        groupZoneId = xi.zone.NORTH_GUSTABERG,

        releaseIdOnDeath = true,
        specialSpawnAnimation = true,
    })

    -- Use the mob object as you normally would
    mob:setSpawn(x, y, z, rot)
    mob:setDropID(0)
    mob:setRoamFlags(xi.roamFlag.SCRIPTED)

    mob:spawn()

    DisallowRespawn(mob:getID(), true)
    mob:setSpeed(25)
    mob:setAllegiance(1)

    -- NPCs don't cast spells or use TP skills
    mob:SetMagicCastingEnabled(false)
    mob:SetMobAbilityEnabled(false)

    return mob
end

-- Spawns all npcs for the zone in the given garrison starting npc
local spawnNPCs = function(zone, zoneData)
    local xPos     = zoneData.xPos
    local yPos     = zoneData.yPos
    local zPos     = zoneData.zPos
    local rot      = zoneData.rot

    -- xi.nation starts at 0. Since we use it as index, add off by 1
    local regionIndex = GetRegionOwner(zone:getRegionID()) + 1
    local allyName    = xi.garrison.allyNames[zoneData.levelCap][regionIndex]
    local allyLooks   = xi.garrison.allyLooks[zoneData.levelCap][regionIndex]

    -- Spawn 1 npc per player in alliance
    for i = 1, #zoneData.players do
        local mob = spawnNPC(zone, xPos, yPos, zPos, rot, allyName, utils.randomEntry(allyLooks))
        mob:setMobLevel(zoneData.levelCap - math.floor(zoneData.levelCap / 5))
        addLevelCap(mob, zoneData.levelCap)
        table.insert(zoneData.npcs, mob:getID())

        if i == 6 then
            xPos = zoneData.xPos - zoneData.xSecondLine
            zPos = zoneData.zPos - zoneData.zSecondLine
        elseif i == 12 then
            xPos = zoneData.xPos - zoneData.xThirdLine
            zPos = zoneData.zPos - zoneData.zThirdLine
        else
            xPos = xPos - zoneData.xChange
            zPos = zPos - zoneData.zChange
        end
    end
end

-- Given a starting mobID, return the list of randomly selected
-- mob ids. The amount of mobs selected is determined by numMobs.
-- The ids in the given excludedMobs table will not be included in the result.
-- This method assumes that the mob pool is composed by mobIDs
-- that are sequential between firstMobID and lastMobID
-- e.g: If firstMobId = 1, lastMobID = 4 and numMobs is 2,
-- Then 2 ids randomly selected between { 1, 2, 3, 4 } will be returned
-- without repetitions.
local pickMobsFromPool = function(firstMobID, lastMobID, numMobs, excludedMobIDs)
    -- unfiltered pool, from first to last mob id (inclusive)
    local unfilteredPool = utils.range(firstMobID, lastMobID)

    -- filter the pool, removing excludedMobIDs
    local pool = {}
    local excludedSet = set(excludedMobIDs)
    for i, v in ipairs(unfilteredPool) do
        if not excludedSet[v] then
            table.insert(pool, v)
        end
    end

    -- validate input
    local mobs = {}
    if numMobs > #pool then
        printf("[warning] pickMobsFromPool called with numMobs > mobIds. Num Mobs: %i. Pool size: %i", numMobs, #pool)
        numMobs = #pool
    end

    if numMobs <= 0 then
        printf("[error] Invalid numMobs picked. Should be > 0.")
        return {}
    end

    -- Now we can apply a common algorithm used to "shuffle a deck of cards"
    for i = 1, numMobs do
        -- Pick random index from J to pool end. Add the picked element to result
        local pickedIndex = math.random(i, #pool)
        table.insert(mobs, pool[pickedIndex])

        -- Now swap the picked element with the first element of the array.
        -- This effectively makes the picked element not elegible for future picks.
        pool[pickedIndex], pool[i] = pool[i], pool[pickedIndex]
    end

    return mobs
end

-----------------------------------
-- Main Functions
-----------------------------------

xi.garrison.tick = nil -- Prototype
xi.garrison.tick = function(npc)
    local zone     = npc:getZone()
    local zoneData = xi.garrison.zoneData[zone:getID()]

    switch (zoneData.state) : caseof
    {
        [xi.garrison.state.SPAWN_NPCS] = function()
            debugLog("State: Spawn NPCs")
            spawnNPCs(zone, zoneData)

            zoneData.stateTime = os.time()
            zoneData.state = xi.garrison.state.BATTLE
        end,

        [xi.garrison.state.BATTLE] = function()
            debugLog("State: Battle")

            -- TODO: Cache npcs / mobs dead
            local allNPCsDead = true
            for _, entityId in pairs(zoneData.npcs) do
                local entity = GetMobByID(entityId)
                if entity and entity:isAlive() then
                    allNPCsDead = false
                end
            end

            local allPlayersDead = true
            for _, entityId in pairs(zoneData.players) do
                local entity = GetPlayerByID(entityId)
                if entity and entity:isAlive() then
                    allPlayersDead = false
                end
            end

            local allMobsDead = true
            for _, entityId in pairs(zoneData.mobs) do
                -- A wave is considered complete when all mobs are done despawning
                -- and not just dead. This matters a lot because of spawn timings.
                -- I.e: If mob A dies on wave 1, and another instance of mob A is supposed
                -- to spawn on wave 2, it will not spawn as long as the previous mob is still
                -- despawning
                local entity = GetMobByID(entityId)
                if entity and entity:isSpawned() then
                    allMobsDead = false
                end
            end

            -- case 1: Either npcs or players are dead. End event.
            if allNPCsDead or allPlayersDead then
                debugPrintToPlayers(zoneData, "Mission failed")
                zoneData.state = xi.garrison.state.ENDED
                return
            end

            -- case 2: More mobs to spawn in this wave, and past next spawn time. Spawn Mobs.
            local shouldSpawnMobs = os.time() >= zoneData.nextSpawnTime
            local isLastGroup = zoneData.groupIndex > xi.garrison.waves.groupsPerWave[zoneData.waveIndex]
            if shouldSpawnMobs and not isLastGroup then
                zoneData.state = xi.garrison.state.SPAWN_MOBS
                return
            end

            -- case 3: All mobs spawned for last wave. Spawn boss
            local isLastWave = zoneData.waveIndex == #xi.garrison.waves.groupsPerWave
            if shouldSpawnMobs and isLastWave and isLastGroup and not zoneData.bossSpawned then
                zoneData.state = xi.garrison.state.SPAWN_BOSS
                return
            end

            -- case 4: All Mobs dead and this was last group. Check if we advance to next wave
            if allMobsDead and zoneData.groupIndex > xi.garrison.waves.groupsPerWave[zoneData.waveIndex] then
                zoneData.state = xi.garrison.state.CHECK_WAVE_PROGRESS
            end
        end,

        [xi.garrison.state.SPAWN_BOSS] = function()
            debugLog("State: Spawn Boss")
            debugPrintToPlayers(zoneData, "Spawning boss")

            local bossID = zone:queryEntitiesByName(zoneData.mobBoss)[1]:getID()
            local mob = SpawnMob(bossID)
            if mob == nil then
                print("[error] Could not spawn boss (%i). Ending garrison.", bossID)
                zoneData.state = xi.garrison.state.ENDED
                return
            end

            addLevelCap(mob, zoneData.levelCap)
            mob:setRoamFlags(xi.roamFlag.SCRIPTED)
            table.insert(zoneData.mobs, mob:getID())

            -- Once the boss is spawned, make it aggro whatever NPCs are already up
            aggroGroups({ mob:getID() }, zoneData.npcs)
            zoneData.bossSpawned = true
            zoneData.state = xi.garrison.state.BATTLE
        end,

        [xi.garrison.state.CHECK_WAVE_PROGRESS] = function()
            debugLog("State: Check Wave Progress")
            debugLogf("Wave Idx: %i. Waves: %i", zoneData.waveIndex, #xi.garrison.waves.groupsPerWave)

            -- Check if this was the last wave (and boss is dead)
            if zoneData.waveIndex >= #xi.garrison.waves.groupsPerWave and zoneData.bossSpawned then
                debugPrintToPlayers(zoneData, "Mission success")
                zoneData.state = xi.garrison.state.GRANT_LOOT
                return
            end

            -- Advance to next wave and back to battle state
            debugLogf("Next wave: %i", zoneData.waveIndex)
            debugPrintToPlayers(zoneData, "Wave " .. zoneData.waveIndex .. " cleared")
            zoneData.waveIndex = zoneData.waveIndex + 1
            zoneData.groupIndex = 1
            zoneData.nextSpawnTime = os.time() + xi.garrison.waves.delayBetweenGroups
            zoneData.state = xi.garrison.state.BATTLE
            zoneData.mobs = {}
        end,

        [xi.garrison.state.SPAWN_MOBS] = function()
            debugLog("State: Spawn Mobs")
            debugPrintToPlayers(zoneData, "Spawning mobs")

            -- There are always at most 8 mobs + 1 boss for Garrison, so we will look up the
            -- boss's ID using their name and then subtract 8 to get the starting mob ID.
            local firstMobID = zone:queryEntitiesByName(zoneData.mobBoss)[1]:getID() - 8
            local numMobs = xi.garrison.waves.mobsPerGroup
            local poolSize = xi.garrison.waves.mobsPerGroup * xi.garrison.waves.groupsPerWave[zoneData.waveIndex]
            local lastMobID = firstMobID + poolSize - 1

            local mobIDs = pickMobsFromPool(firstMobID, lastMobID, numMobs, zoneData.mobs)

            for _, mobID in ipairs(mobIDs) do
                local mob = SpawnMob(mobID)
                if mob ~= nil then
                    addLevelCap(mob, zoneData.levelCap)
                    mob:setRoamFlags(xi.roamFlag.SCRIPTED)
                    table.insert(zoneData.mobs, mob:getID())
                end
            end

            -- Once the mobs are spawned, make them aggro whatever NPCs are already up
            aggroGroups(zoneData.mobs, zoneData.npcs)

            zoneData.nextSpawnTime = os.time() + xi.garrison.waves.delayBetweenGroups
            zoneData.state = xi.garrison.state.BATTLE
            zoneData.groupIndex = zoneData.groupIndex + 1
        end,

        [xi.garrison.state.GRANT_LOOT] = function()
            debugLog("State: Grant Loot")
            xi.garrison.handleLootRolls(xi.garrison.loot[zoneData.levelCap], zoneData.players)

            zoneData.state = xi.garrison.state.ENDED
        end,

        [xi.garrison.state.ENDED] = function()
            debugLog("State: Ended")

            for _, entityId in pairs(zoneData.players) do
                local entity = GetPlayerByID(entityId)
                if entity ~= nil then
                    entity:delStatusEffect(xi.effect.LEVEL_RESTRICTION)
                end
            end

            for _, entityId in pairs(zoneData.npcs) do
                DespawnMob(entityId, zone)
            end

            for _, entityId in pairs(zoneData.mobs) do
                DespawnMob(entityId, zone)
            end

            zoneData.continue = false
        end,
    }

    if zoneData.continue then
        npc:timer(1000, function(npcArg)
            xi.garrison.tick(npcArg)
        end)
    end
end

xi.garrison.start = function(player, npc)
    -- TODO: Write lockout information to player

    local zone           = player:getZone()
    local zoneData       = xi.garrison.zoneData[zone:getID()]
    zoneData.players     = {}
    zoneData.npcs        = {}
    zoneData.mobs        = {}
    zoneData.state       = xi.garrison.state.SPAWN_NPCS
    zoneData.continue    = true
    zoneData.stateTime   = os.time()
    zoneData.waveIndex   = 1
    zoneData.groupIndex  = 1
    zoneData.bossSpawned = false
    -- First mob spawn takes xi.garrison.waves.delayBetweenGroups to start
    zoneData.nextSpawnTime = os.time() + xi.garrison.waves.delayBetweenGroups

    for _, member in pairs(player:getAlliance()) do
        addLevelCap(member, zoneData.levelCap)
        table.insert(zoneData.players, member:getID())
    end

    -- The starting NPC is the 'anchor' for all timers and logic for this Garrison
    xi.garrison.tick(npc)
end

xi.garrison.onTrade = function(player, npc, trade, guardNation)
    if not xi.settings.main.ENABLE_GARRISON then
        return false
    end

    -- TODO: If there is currently an active Garrison, bail out now

    local zoneData = xi.garrison.zoneData[player:getZoneID()]
    if npcUtil.tradeHasExactly(trade, zoneData.itemReq) then
        -- TODO: Check lockout

        -- Start CS
        player:startEvent(32753 + player:getNation())
        player:setLocalVar("GARRISON_NPC", npc:getID())
        return true
    end

    return false
end

xi.garrison.onTrigger = function(player, npc)
    if not xi.settings.main.ENABLE_GARRISON then
        return false
    end

    return false
end

xi.garrison.onEventFinish = function(player, csid, option, guardNation, guardType, guardRegion)
    if not xi.settings.main.ENABLE_GARRISON then
        return false
    end

    if csid == 32753 + player:getNation() and option == 0 then
        player:confirmTrade()
        local npc = GetNPCByID(player:getLocalVar("GARRISON_NPC"))
        xi.garrison.start(player, npc)
        return true
    end

    return false
end

-- Distributes loot amongst all players
-- TODO: Use a central loot system: https://github.com/LandSandBoat/server/issues/3188
xi.garrison.handleLootRolls = function(lootTable, players)
    local max = 0

    for i,entry in ipairs(lootTable) do
        max = max + entry.droprate
    end

    local roll = math.random(max)

    for _, entry in pairs(lootTable) do
        max = max - entry.droprate

        if roll > max then
            if entry.itemid ~= 0 then
                for _, entityId in ipairs(players) do
                    local player = GetPlayerByID(entityId)
                    if player ~= nil then
                        player:addTreasure(entry.itemid)
                        return
                    end
                end
            end

            break
        end
    end
end
