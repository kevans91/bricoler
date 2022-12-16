-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local Task = Class{
    inputs = {},        -- Inputs defined by the task.
    outputs = {},       -- Outputs defined by the task.
    params = {},        -- Parameters defined by the task.
    env = {},           -- Environment in which the task definition is loaded.
}

local TaskInput = Class({
}, {
    Class.typecheck("descr", "string"),
})

function TaskInput:_ctor(args)
end

local TaskOutput = Class({
}, {
    Class.typecheck("descr", "string"),
})

function TaskOutput:_ctor(args)
end

local TaskParam = Class({
    descr = "",
    required = false,
}, {
    Class.typecheck("descr", "string"),
    Class.typecheck("required", "boolean"),
    Class.typecheck("default", "string")
})

function TaskParam:_ctor(args)
end

function Task:_ctor(args)
    if not args.path then
        error("No task definition was provided.")
    end

    assert(loadfile(args.path, "t", self.env))()

    -- XXX-MJ more validation
    if not self.env.Run or type(self.env.Run) ~= "function" then
        error("Task '" .. args.path .. "' does not define an action (Run()).")
    end
    self.action = self.env.Run

    for _, p in ipairs{
        {self.env.Inputs, self.inputs, TaskInput},
        {self.env.Outputs, self.outputs, TaskOutput},
        {self.env.Params, self.params, TaskParam},
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
