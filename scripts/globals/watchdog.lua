xi.watchdog.lookup = {}

xi.watchdog.tick = nil -- Prototype
xi.watchdog.tick = function(entity, checkFunc, doneFunc, intervalMs)
    if not checkFunc(entity) then
        xi.watchdog.stop(entity)
        doneFunc(entity)
        return
    end

    local lookupKey = bit.rshift(entity:getID(), 16)
    if xi.watchdog.lookup[lookupKey] then
        entity:timer(intervalMs, function(entityArg)
            xi.watchdog.tick(entityArg, checkFunc, intervalMs)
        end)
    end
end

xi.watchdog.stop = function(entity)
    local lookupKey = bit.rshift(entity:getID(), 16)
    xi.watchdog.lookup[lookupKey] = nil
end