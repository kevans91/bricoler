-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

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
    task = self.universe[taskname]
    local sched = {task}
    for name, input in pairs(task.inputs) do
        table.insert(sched, self:_mksched(input.task))
    end
    return sched
end

function TaskSched:bind()
end

function TaskSched:run()
    self.universe[self.target]:run()
end

return TaskSched
