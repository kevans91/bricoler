-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local TaskSched = Class({
    universe = {},              -- Set of all known tasks, keyed by task name.
    target = "",                -- Name of the target task to run.
})

-- Arguments:
--   a set of task definitions, keyed by task name
--   a target task that will be executed
function TaskSched:_ctor(...)
    local count = select("#", ...)
    if count ~= 2 then
        error("TaskSched constructor given " .. count .. " params, expected 2.")
    end
    self.universe = select(1, ...)
    if type(self.universe) ~= "table" then
        error("TaskSched constructor first parameter type must be 'table'.")
    end
    self.target = select(2, ...)
    if type(self.target) ~= "string" then
        error("TaskSched constructor second parameter type must be 'string'.")
    end
    return self
end

function TaskSched:bind(params)
end

function TaskSched:run()
end

return TaskSched
