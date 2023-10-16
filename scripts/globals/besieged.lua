-----------------------------------
--
--     Functions for Besieged system
--
-----------------------------------
require('scripts/globals/besieged_data')
require('scripts/globals/extravaganza')
require('scripts/globals/npc_util')
require('scripts/globals/teleports')
-----------------------------------

xi = xi or {}
xi.besieged = xi.besieged or {}
xi.besieged.zoneData = {}

------------------------------------
--  Disclaimer: This file contains a few methods that are ToAU related but
--  not Besieged only. These methods will be moved to a more appropriate
--  file upstream.
--  In the meantime, they are moved to the bottom.
------------------------------------

--------------------------------------
--  Besieged related methods
--------------------------------------

-----------------------------------
--  Forces Advancing
-----------------------------------

local spawnMob = function(npcId, zoneId)
    local zoneData = xi.besieged.zoneData[zoneId]
    if zoneData == nil then
        print("Zone data not initialized for zone: " .. zoneId)
        return
    end

    local mob = SpawnMob(npcId)
    if mob ~= nil then
        table.insert(zoneData.mobs, npcId)
        print("Spawned Besieged mob: " .. npcId .. " in zone: " .. zoneId)
    else
        print("Failed to spawn Besieged mob: " .. npcId .. " in zone: " .. zoneId)
    end
end

local sendForcesAdvancingMsg = function(strongholdId, zoneId)
    -- local stronghold = GetBeastmenStrongholdInfo(strongholdId)
    -- local zoneId = zone:getID()
    -- local msg = string.format("The %s forces are advancing!", stronghold["name"])
    -- zone:sendText(0, msg)

    print("Sending forces advancing message to zone: " .. zoneId)

    local zone = GetZone(zoneId)
    local playersInZone = zone:getPlayers()
    for _, player in pairs(playersInZone) do
        print("Sending message to: " .. player:getName())
        player:messageText(player, 40888, 65285)
    end
end

local spawnBeastmenIfNecessary = function(zone)
    local zoneId = zone:getID()

    if xi.besieged.zoneData[zoneId].beastmenSpawned then
        return
    end

    -- For all beastmen strongholds (1 to 3),
    -- check their besieged info and spawn beastmen
    -- if in the advancing stage.
    for strongholdId = 1, 3 do
        if xi.besieged.waves[strongholdId].zone == zone:getID() then
            local stronghold = GetBeastmenStrongholdInfo(strongholdId)
            if stronghold["orders"] == xi.besieged.BEASTMEN_ORDERS.ADVANCE then
                xi.besieged.spawnBeastmen(strongholdId, zoneId)
            end
        end
    end
end

xi.besieged.spawnBeastmen = function(strongholdId, zoneId)
    local stronghold = GetBeastmenStrongholdInfo(strongholdId)
    local waves = xi.besieged.waves[strongholdId]
    local npcOffset = waves.npcOffset
    local npcCount = waves.npcCount
    local zoneData = xi.besieged.zoneData[zoneId]

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
        spawnMob(npcId, zoneId)
    end

    -- Update state and send zone message
    zoneData.beastmenSpawned = true
    sendForcesAdvancingMsg(strongholdId, zoneId)
end

xi.besieged.despawnBeastmen = function(zoneId)
    local zoneData = xi.besieged.zoneData[zoneId]

    if zoneData == nil then
        return
    end

    if not zoneData.beastmenSpawned then
        return
    end

    local zone = GetZone(zoneId)
    for _, npcId in pairs(zoneData.mobs) do
        print("Despawn mob: " .. npcId .. " in zone: " .. zoneId)
        DespawnMob(npcId, zone)
    end

    zoneData.mobs = {}
    zoneData.beastmenSpawned = false
end

-----------------------------------
--  Zone Lifecycle methods
-----------------------------------

xi.besieged.initZone = function(zone)
    local zoneId = zone:getID()
    print("Init zone: " .. zoneId)

    -- Init empty zone data
    xi.besieged.zoneData[zoneId] = {
        beastmenSpawned = false,
        mobs = {},
    }
end

xi.besieged.onZoneTick = function(zone)
    -- If the zone is not a besieged zone, or it has not been initialized,
    -- do nothing
    if (xi.besieged.zoneData[zone:getID()] == nil) then
        return
    end

    -- This is a relatively cheap call since all besieged info
    -- is cached on the map servers
    spawnBeastmenIfNecessary(zone)
end

-----------------------------------
--  Legacy methods 
--  (TODO: Revisit these and where they are used)
-----------------------------------

-----------------------------------
-- function getImperialDefenseStats() returns:
-- *how many successive times Al Zahbi has been defended
-- *Imperial Defense Value
-- *Total number of imperial victories
-- *Total number of beastmen victories.
-- hardcoded constants for now until we have a Besieged system.
-----------------------------------
local function getImperialDefenseStats()
    -- TODO: get successiveWins, imperialWins and beastmanWins from
    -- besieged_battle_history table once implemented
    local successiveWins = 0
    local defenseBonus = GetImperialDefenseLevel()
    local imperialWins = 0
    local beastmanWins = 0
    return { successiveWins, defenseBonus, imperialWins, beastmanWins }
end

-----------------------------------
-- function getAstralCandescence() returns 1 if Alzhbi has the AC, 0 otherwise.
-----------------------------------
xi.besieged.getAstralCandescence = function()
    local candescenceOwner = GetAstralCandescenceOwner()
    if candescenceOwner == xi.besieged.STRONGHOLD.ALZHABI then
        return 1
    else
        return 0
    end
end

-----------------------------------
-- ToAU related methods (Not besieged)
-----------------------------------

xi.besieged.cipherValue = function()
    local active = xi.extravaganza.campaignActive()

    if
        active == xi.extravaganza.campaign.SUMMER_NY or
        active == xi.extravaganza.campaign.BOTH
    then
        return 65536 * 16384
    else
        return 0
    end
end

local function getMapBitmask(player)
    local mamook   = player:hasKeyItem(xi.ki.MAP_OF_MAMOOK) and 1 or 0 -- Map of Mammok
    local halvung  = player:hasKeyItem(xi.ki.MAP_OF_HALVUNG) and 2 or 0 -- Map of Halvung
    local arrapago = player:hasKeyItem(xi.ki.MAP_OF_ARRAPAGO_REEF) and 4 or 0 -- Map of Arrapago Reef
    local astral   = bit.lshift(xi.besieged.getAstralCandescence(), 31) -- Include astral candescence in the top byte

    return bit.bor(mamook, halvung, arrapago, astral)
end

-----------------------------------
-- function getISPItem(i) returns the item ID and cost of the imperial standing
-- points item indexed by i (the same value  as that used by the vendor event.)
-- TODO: Format table, use xi.items enum, and descriptive parameter name
-----------------------------------
local function getISPItem(i)
    local imperialStandingItems =
    {
        -- Common Items
        [1] = { id = 4182, price = 7 }, -- scroll of Instant Reraise
        [4097] = { id = 4181, price = 10 }, -- scroll of Instant Warp
        [8193] = { id = 2230, price = 100 }, -- lambent fire cell
        [12289] = { id = 2231, price = 100 }, -- lambent water cell
        [16385] = { id = 2232, price = 100 }, -- lambent earth cell
        [20481] = { id = 2233, price = 100 }, -- lambent wind cell
        [24577] = { id = 19021, price = 20000 }, -- katana strap
        [28673] = { id = 19022, price = 20000 }, -- axe grip
        [32769] = { id = 19023, price = 20000 }, -- staff strap
        [36865] = { id = 3307, price = 5000 }, -- heat capacitor
        [40961] = { id = 3308, price = 5000 }, -- power cooler
        [45057] = { id = 3309, price = 5000 }, -- barrage turbine
        [53249] = { id = 3311, price = 5000 }, -- galvanizer
        [57345] = { id = 6409, price = 50000 },
        [69633] = { id = xi.items.CIPHER_OF_MIHLIS_ALTER_EGO, price = 5000 }, -- mihli
        -- Private Second Class
        -- Map Key Items (handled separately)
        -- Private First Class
        [33] = { id = 18689, price = 2000 }, -- volunteer's dart
        [289] = { id = 18690, price = 2000 }, -- mercenary's dart
        [545] = { id = 18691, price = 2000 }, -- Imperial dart
        -- Superior Private
        [49] = { id = 18692, price = 4000 }, -- Mamoolbane
        [305] = { id = 18693, price = 4000 }, -- Lamiabane
        [561] = { id = 18694, price = 4000 }, -- Trollbane
        [817] = { id = 15810, price = 4000 }, -- Luzaf's ring
        -- Lance Corporal
        [65] = { id = 15698, price = 8000 }, -- sneaking boots
        [321] = { id = 15560, price = 8000 }, -- trooper's ring
        [577] = { id = 16168, price = 8000 }, -- sentinel shield
        -- Corporal
        [81] = { id = 18703, price = 16000 }, -- shark gun
        [337] = { id = 18742, price = 16000 }, -- puppet claws
        [593] = { id = 17723, price = 16000 }, -- singh kilij
        -- Sergeant
        [97] = { id = 15622, price = 24000 }, -- mercenary's trousers
        [353] = { id = 15790, price = 24000 }, -- multiple ring
        [609] = { id = 15981, price = 24000 }, -- haten earring
        -- Sergeant Major
        [113] = { id = 15623, price = 32000 }, -- volunteer's brais
        [369] = { id = 15982, price = 32000 }, -- priest's earring
        [625] = { id = 15983, price = 32000 }, -- chaotic earring
        -- Chief Sergeant
        [129] = { id = 17741, price = 40000 }, -- perdu hanger
        [385] = { id = 18943, price = 40000 }, -- perdu sickle
        [641] = { id = 18850, price = 40000 }, -- perdu wand
        [897] = { id = 18717, price = 40000 }, -- perdu bow
        -- Second Lieutenant
        [145] = { id = 16602, price = 48000 }, -- perdu sword
        [401] = { id = 18425, price = 48000 }, -- perdu blade
        [657] = { id = 18491, price = 48000 }, -- perdu voulge
        [913] = { id = 18588, price = 48000 }, -- perdu staff
        [1169] = { id = 18718, price = 48000 }, -- perdu crossbow
        -- First Lieutenant
        [161] = { id = 16271, price = 56000 }, -- lieutenant's gorget
        [417] = { id = 15912, price = 56000 }, -- lieutenant's sash
        [673] = { id = 16230, price = 56000 } -- lieutenant's cape
    }
    local item = imperialStandingItems[i]
    if item then
        return item.id, item.price
    end

    return nil
end

-----------------------------------
-- function getSanctionDuration(player) returns the duration of the sanction effect
-- in seconds. Duration is known to go up with mercenary rank but data published on
-- ffxi wiki (http://wiki.ffxiclopedia.org/wiki/Sanction) is unclear and even
-- contradictory (the page on the AC http://wiki.ffxiclopedia.org/wiki/Astral_Candescence
-- says that duration is 3-8 hours with the AC, 1-3 hours without the AC while the Sanction
-- page says it's 3-6 hours with th AC.)
--
-- I decided to use the formula duration (with AC) = 3 hours + (mercenary rank - 1) * 20 minutes.
-----------------------------------
local function getSanctionDuration(player)
    local duration = 10800 + 1200 * (xi.besieged.getMercenaryRank(player) - 1)

    if xi.besieged.getAstralCandescence() == 0 then
        duration = duration / 2
    end

    return duration
end

xi.besieged.onTrigger = function(player, npc, eventBase)
    local mercRank = xi.besieged.getMercenaryRank(player)
    if mercRank == 0 then
        player:startEvent(eventBase + 1, npc)
    else
        local maps = getMapBitmask(player)
        player:startEvent(eventBase, player:getCurrency("imperial_standing"), (maps + xi.besieged.cipherValue()), mercRank, 0, unpack(getImperialDefenseStats()))
    end
end

xi.besieged.onEventUpdate = function(player, csid, option)
    local itemId = getISPItem(option)
    if itemId and option < 0x40000000 then
        local maps = getMapBitmask(player)
        player:updateEvent(player:getCurrency("imperial_standing"), (maps + xi.besieged.cipherValue()), xi.besieged.getMercenaryRank(player), player:canEquipItem(itemId) and 2 or 1, unpack(getImperialDefenseStats()))
    end
end

xi.besieged.onEventFinish = function(player, csid, option)
    local ID = zones[player:getZoneID()]
    if
        (option == 0 or option == 16 or option == 32 or option == 48) and
        player:hasCompletedMission(xi.mission.log_id.TOAU, 1)
    then
        -- Sanction
        if option ~= 0 then
            player:delCurrency("imperial_standing", 100)
        end

        player:delStatusEffectsByFlag(xi.effectFlag.INFLUENCE, true)
        local duration = getSanctionDuration(player)
        local subPower = 0 -- getImperialDefenseStats()
        player:addStatusEffect(xi.effect.SANCTION, option / 16, 0, duration, subPower)
        player:messageSpecial(ID.text.SANCTION)
    elseif bit.band(option, 0xFF) == 17 then
        -- Player bought a map
        local ki = xi.ki.MAP_OF_MAMOOK + bit.rshift(option, 8)
        npcUtil.giveKeyItem(player, ki)
        player:delCurrency("imperial_standing", 1000)
    elseif option < 0x40000000 then
        -- Player bought an item
        local item, price = getISPItem(option)
        if item then
            if npcUtil.giveItem(player, item) then
                player:delCurrency("imperial_standing", price)
            end
        end
    end
end

-----------------------------------
-- Variable for addTeleport and getRegionPoint
-----------------------------------
xi.besieged.addRunicPortal = function(player, portal)
    player:addTeleport(xi.teleport.type.RUNIC_PORTAL, portal)
end

xi.besieged.hasRunicPortal = function(player, portal)
    return player:hasTeleport(xi.teleport.type.RUNIC_PORTAL, portal)
end

xi.besieged.hasAssaultOrders = function(player)
    local event = 0
    local keyitem = 0

    for i = 0, 4 do
        local ki = xi.ki.LEUJAOAM_ASSAULT_ORDERS + i
        if player:hasKeyItem(ki) then
            event = 120 + i
            keyitem = ki
            break
        end
    end

    return event, keyitem
end

xi.besieged.badges =
{
    xi.ki.PSC_WILDCAT_BADGE,
    xi.ki.PFC_WILDCAT_BADGE,
    xi.ki.SP_WILDCAT_BADGE,
    xi.ki.LC_WILDCAT_BADGE,
    xi.ki.C_WILDCAT_BADGE,
    xi.ki.S_WILDCAT_BADGE,
    xi.ki.SM_WILDCAT_BADGE,
    xi.ki.CS_WILDCAT_BADGE,
    xi.ki.SL_WILDCAT_BADGE,
    xi.ki.FL_WILDCAT_BADGE,
    xi.ki.CAPTAIN_WILDCAT_BADGE
}

xi.besieged.getMercenaryRank = function(player)
    local rank = 0

    for k = #xi.besieged.badges, 1, -1 do
        if player:hasKeyItem(xi.besieged.badges[k]) then
            rank = k
            break
        end
    end

    return rank
end
