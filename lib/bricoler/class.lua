-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local function class(proto, props)
    local function deepcopy(from, to)
        for k, v in pairs(from) do
            if type(v) == "table" then
                v = deepcopy(v, {})
            end
            to[k] = v
        end
        return to
    end

    -- A class is its own metatable.  This __index metamethod ensures that
    -- any defined property can be accessed even if it hasn't been set.
    local c = {}
    c.__index = function (t, key)
        local mt = getmetatable(t)
        if rawget(mt, key) then
            return mt[key]
        elseif mt._props[key] then
            return nil
        end
        error("Unknown class property '" .. key .. "'")
    end

    c._proto = proto
    c._props = {}
    for _, v in ipairs(props or {}) do
        c._props[v[1]] = v[2]
    end

    -- Default constructor, can be overridden in the class implementation.
    c._ctor = function (self, _)
        return self
    end

    -- Instantiate a new object when the class is called.  The prototype is
    -- copied into the new object and properties given to the constructor are
    -- checked and set.  Finally the object-specific constructor, if any, is
    -- called.
    c.__call = function(self, ...)
        local object = deepcopy(self._proto, {})
        if select("#", ...) ~= 1 then
            error("Constructors take a single table parameter")
        end
        local t = select(1, ...)
        if type(t) ~= "table" then
            error("Constructor parameter must be a table")
        end
        for k, v in pairs(t) do
            if self._props[k] then
                object[k] = self._props[k](v)
            else
                error("Unknown class property '" .. k .. "'")
            end
        end
        return setmetatable(object, self):_ctor(t)
    end
    return setmetatable(c, c)
end

-- A property definition is a tuple of the property name and a function which
-- validates a value for the property.  "valid" is either a table of valid
-- values, or a function which returns true if the value is valid and false otherwise.
local function property(prop, t, valid)
    assert(valid == nil or type(valid) == "table" or type(valid) == "function")
    return {prop, function (v)
        if t and type(v) ~= t then
            error("Property '" .. prop .. "' must have type " .. t)
        end

        if valid then
            if type(valid) == "table" then
                for i, candidate in ipairs(valid) do
                    if v == candidate then
                        break
                    end
                    if i == #valid then
                        error("Property '" .. prop .. "' must be one of " .. table.concat(valid, ", "))
                    end
                end
            elseif not valid(v) then
                error("Property '" .. prop .. "' value '" .. "' is invalid")
            end
        end

        return v
    end}
end

local module = {
    class = class,
    property = property,
}

local modulemt = {
    __call = function (_, ...) return class(...) end
}

-- A bit of magic to allow
--     Class = require 'lib.bricoler.class'
--     T = Class(...)
-- to work while also exporting other things from the module.
return setmetatable(module, modulemt)
