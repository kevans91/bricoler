-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'
local Util = require 'lib.bricoler.util'

local TaskSched = Class({
    schedule = {},              -- Tree of tasks to run.
    universe = {},              -- Set of all known tasks, keyed by task name.
    target = "",                -- Name of the target task to run.
}, {
    Class.property("universe", "table"),
    Class.property("target", "string"),
})

function TaskSched:_ctor(props)
    if not self.universe[self.target] then
        error("Unknown task '" .. self.target .. "'.")
    end
    self.schedule = self:_mksched(self.target)
    return self
end

function TaskSched:_mksched(taskname)
    if not self.universe[taskname] then
        error("Unknown task '" .. taskname .. "'.")
    end
    local task = self.universe[taskname]
    local sched = {task}
    for name, input in pairs(task.inputs) do
        sched[name] = self:_mksched(input.task)
    end
    return sched
end

local function visitsched(schedule, f)
    for k, v in pairs(schedule) do
        if k ~= 1 then
            visitsched(v, f)
        end
    end
    f(schedule[1])
end

-- Arguments:
--   params: an array of strings of the form <task>:<name>=<val>
function TaskSched:bind(params)
    -- First bind default values for scheduled task parameters.
    visitsched(self.schedule, function (task)
        for _, v in pairs(task.params) do
            if v.default then
                v.val = v.default
            end
        end
    end)

    -- Now go through user-specific parameters and bind those.
    for _, v in ipairs(params) do
        local task, param, val = v:match("^([^:]*):([^=]*)=(.*)$")
        if not task then
            error("Invalid parameter '" .. v .. "'.")
        end

        self.universe[task]:bind(param, val)
    end
end

function TaskSched:run()
    local ctx = {
        maxjobs = Util.sysctl("hw.ncpu"),
    }

    visitsched(self.schedule, function (task)
        task:run(ctx)
    end)
end

return TaskSched
