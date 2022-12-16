-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local Task = Class({
    inputs = {},        -- Inputs defined by the task.
    outputs = {},       -- Outputs defined by the task.
    params = {},        -- Parameters defined by the task.
    env = {},           -- Environment in which the task definition is loaded.
})

function Task:_ctor(args)
    self.env = args.env
    if args.path then
        assert(loadfile(args.path, "t", self.env))()
    else
        error("No task definition was provided.")
    end
    return self
end

return Task
