-----------------------------------
-- Area: Fort Ghelsba
--   NM: Kegpaunch Doshgnosh
-----------------------------------
require("scripts/globals/hunts")
require("scripts/globals/mobs")
-----------------------------------
local entity = {}

entity.onMobInitialize = function(mob)
    mob:setMobMod(xi.mobMod.ADD_EFFECT, 1)
end

entity.onAdditionalEffect = function(mob, target, damage)
    return xi.mob.onAddEffect(mob, target, damage, xi.mob.ae.ENFIRE)
end

entity.onMobDeath = function(mob, player, optParams)
    xi.hunts.checkHunt(mob, player, 173)
end

entity.onMobDespawn = function(mob)
    xi.mob.nmTODPersist(mob, 3600) -- 1 hour
end

return entity
