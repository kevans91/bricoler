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

    local c = {}
    c.__index = c

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
    -- checked and set.  Finally the object-specific constructor is called.
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

local function property(field, t)
    return {field, function (v)
        if not t or type(v) == t then
            return v
        else
            error("A value for property '" .. field .. "' must have type " .. t)
        end
    end}
end

local m = {
    class = class,
    property = property
}

local mt = {
    __call = function (_, ...) return class(...) end
}

-- A bit of magic to allow
--     Class = require 'lib.bricoler.class'
--     T = Class(...)
-- to work while also defining other things in the module "Class".
return setmetatable(m, mt)
