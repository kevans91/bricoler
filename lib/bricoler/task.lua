-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local Task = Class({
    inputs = {},        -- Inputs defined by the task.
    outputs = {},       -- Outputs defined by the task.
    params = {},        -- Parameters defined by the task.
    env = {},           -- Environment in which the task definition is loaded.
}, {
    Class.property("path", "string")
})

local TaskInput = Class({
    descr = "",                 -- Human readable description for help messages.
}, {
    Class.property("descr", "string"),
    Class.property("task", "string"),
    Class.property("params", "table"),
})

local TaskOutput = Class({
    descr = "",                 -- Human readable description for help messages.
}, {
    Class.property("descr", "string"),
})

local TaskParam = Class({
    descr = "",                 -- Human readable description for help messages.
    required = false,           -- Is it an error to run without a binding?
}, {
    Class.property("descr", "string"),
    Class.property("required", "boolean"),
    Class.property("default"),
})

function Task:_ctor(args)
    if not args.path then
        error("No task definition was provided.")
    end

    assert(loadfile(args.path, "t", self.env))()

    if not self.env.Run or type(self.env.Run) ~= "function" then
        error("Task '" .. args.path .. "' does not define an action (Run()).")
    end
    self.action = self.env.Run

    for _, p in ipairs{
        {self.env.Inputs,  self.inputs,  TaskInput},
        {self.env.Outputs, self.outputs, TaskOutput},
        {self.env.Params,  self.params,  TaskParam},
    } do
        for k, v in pairs(p[1] or {}) do
            p[2][k] = p[3](v)
        end
    end
    return self
end

function Task:run()
    self.env.print = print
    self.action()
end

return Task
