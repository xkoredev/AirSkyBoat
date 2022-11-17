-----------------------------------
--
-- Functional
--
-- Functional methods provide a means to simplify logic that consists in
-- simple operations when iterating a table.
-- In general, they can make code much more concise and readable, but they
-- can also end up making it a cluttered mess, so use your judgement
-- when deciding if you want to use these methods
-----------------------------------

fn = {}

-- Given a table and a mapping function, returns a new table created by
-- applying the given mapping function to the given table elements
function fn.map(tbl, func)
    local t = {}
    for k,v in pairs(tbl) do
        t[k] = func(k, v)
    end
    return t
end

-- Given a table and a filter function, returns a new table composed of the
-- elements that pass the given filter.
-- e.g;
-- fn.filter({"a", "b", "c", "d"}, function(k, v) return v >= "c" end)  --> {"c","d"}
function fn.filter(tbl, func)
    local out = {}

    for k, v in pairs(tbl) do
        if func(k, v) then
            out[k] = v
        end
    end

    return out
end

-- Given a table and a filter function, returns a new table composed of the
-- elements that pass the given filter.
-- Unlike fn.filter, this method will return an iterable table.
-- e.g;
-- fn.filter({"a", "b", "c", "d"}, function(v) return v >= "c" end)  --> {1 => "c", 2 => "d"}
function fn.filterArray(tbl, func)
    local out = {}

    for k, v in pairs(tbl) do
        if func(k, v) then
            table.insert(out, v)
        end
    end

    return out
end

-- Returns true if any member of the given table passes the given
-- predicate function
function fn.any(tbl, predicate)
    for k, v in pairs(tbl) do
        if predicate(k, v) then
            return true
        end
    end

    return false
end

-- Returns the sum of applying the given function to each element of the given table
-- fn.sum({1, 2, 3}, function(k, v) return v end)  --> 6
function fn.sum(tbl, func)
    local sum = 0

    for k, v in pairs(tbl) do
        sum = sum + func(k, v)
    end

    return sum
end

-- To be used with fn.sum.
-- Used to count the number of times an element in a table
-- matches the given predicate
-- e.g: fn.sum({"a, "a", "b"}, fn.counter(function (k,v) return v == "a" end)) --> 2
function fn.counter(predicate)
    return function (k, v)
        if predicate(k, v) then
            return 1
        else
            return 0
        end
    end
end