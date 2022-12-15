-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local Task = Class({
    inputs = {},
    outputs = {},
    params = {},
    env = {}
})

function Task:_ctor(...)
    local count = select("#", ...)
    if count ~= 1 then
        error("Task constructor given " .. count .. " params, expected 1.")
    end
    local path = select(1, ...)
    if type(path) ~= "string" then
        error("Task constructor parameter type must be 'string'.")
    end
    assert(loadfile(path, "t", self.env))()
    return self
end

return Task
