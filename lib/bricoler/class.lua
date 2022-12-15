-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local function class(proto)
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

return class
