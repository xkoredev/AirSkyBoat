-----------------------------------
-- func: gardenstage
-- desc: Advances all planted flowerpots to the next stage
-----------------------------------

require("scripts/globals/status")

cmdprops =
{
    permission = 1,
    parameters = ""
}

function onTrigger(player)
    moveToNextStage(player, xi.inv.MOGSAFE)
    moveToNextStage(player, xi.inv.MOGSAFE2)

end

function moveToNextStage(target, inv_location)
    local items = target:getItems(xi.itemType.FURNISHING, inv_location)
end