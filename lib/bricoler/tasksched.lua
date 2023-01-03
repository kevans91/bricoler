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

function TaskSched:_ctor()
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
    local sched = {task, taskname}
    for name, input in pairs(task.inputs) do
        sched[name] = self:_mksched(input.task)
    end
    return sched
end

-- Invoke a callback on all tasks in a schedule in postorder, i.e., children are
-- visited before parents.
local function visitsched(schedule, cb)
    local function _visitsched(sched, f, name)
        for k, v in pairs(sched) do
            if type(k) == "string" then
                table.insert(name, k)
                _visitsched(v, f, name)
                table.remove(name)
            end
        end
        f(sched[1], name)
    end
    _visitsched(schedule, cb, {})
end

-- Bind parameters for a task schedule.  "params" is an array of strings of the
-- form [<name>:]<param>=<value>.  These values override default parameter
-- values.
function TaskSched:bind(params)
    -- First bind default values for scheduled task parameters.
    visitsched(self.schedule, function (task)
        for name, param in pairs(task.params) do
            task:bind(name, param:defaultvalue())
        end
    end)

    -- Now go through user-specific parameters and bind those.
    for _, v in ipairs(params) do
        local task, param, val = v:match("^([^=:]+):([^=]+)=(.*)$")
        if not task then
            task, param, val = "", v:match("^([^=:]+)=(.*)$")
        end

        local sched = self.schedule
        for child, _ in task:gmatch("([^%.]+)") do
            sched = sched[child]
            if not sched then
                error("Unmatched parameter name '" .. task .. "'.")
            end
        end

        sched[1]:bind(param, val)
    end
end

function TaskSched:run()
    local ctx = {
        maxjobs = Util.sysctl("hw.ncpu"),
    }

    -- Do we have any unbound required parameters?  Raise an error if so.
    visitsched(self.schedule, function (task)
        for k, v in pairs(task.params) do
            if v.required and not v:value() then
                -- XXX-MJ error message needs to name the task too.
                error("Required parameter '" .. k .. "' is unbound.")
            end
        end
    end)

    visitsched(self.schedule, function (task)
        task:run(ctx)
    end)
end

function TaskSched:print()
    local function dump(input, sched, level)
        local task, taskname = sched[1], sched[2]

        local function prefix(count)
            local str = "  "
            return str:rep(count)
        end

        if input then
            print(prefix(level) .. input .. " (" .. taskname .. ")")
        else
            print(prefix(level) .. taskname)
        end
        for name, param in pairs(task.params) do
            local val = param:value() or (param.required and "???") or ""
            print(prefix(level + 1) .. "P " .. name .. "=" .. val)
        end
        for name, _ in pairs(task.outputs) do
            print(prefix(level + 1) .. "O " .. name)
        end

        -- XXX-MJ this should use visitsched, but needs preorder traversal.
        for k, v in pairs(sched) do
            if type(k) == "string" then
                dump(k, v, level + 1)
            end
        end
    end

    dump(nil, self.schedule, 0)
end

return TaskSched
