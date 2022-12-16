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
    c.__call = function(self, ...)
        local object = deepcopy(self.__proto, {})
        return setmetatable(object, self):_ctor(...)
    end
    c.__proto = proto
    return setmetatable(c, c)
end

local function typecheck(field, t)
    return field, function (v)
        if type(v) == t then
            return v
        else
            error("A value for property '" .. field .. "' must have type " .. t .. ".")
        end
    end
end

local m = {
    class = class,
    typecheck = typecheck
}

local mt = {
    __call = function (_, ...) return class(...) end
}

-- A bit of magic to allow
--     Class = require 'lib.bricoler.class'
--     T = Class(...)
-- to work.
return setmetatable(m, mt)
