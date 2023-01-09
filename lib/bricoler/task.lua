-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Fs = require 'lfs'

local Class = require 'lib.bricoler.class'
local Util = require 'lib.bricoler.util'

local TaskInput = Class({
    descr = "",                 -- Human readable description for help messages.
    params = {},
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
    valid = function () return true end
}, {
    Class.property("descr", "string"),
    Class.property("required", "boolean"),
    Class.property("default"),
    Class.property("valid"),
})

function TaskParam:defaultvalue()
    for k, v in pairs(self) do
        if k == "default" then
            if type(v) == "function" then
                return v()
            else
                return v
            end
        end
    end
end

function TaskParam:value()
    for k, v in pairs(self) do
        if k == "val" then
            return v
        end
    end
end

local Task = Class({
    inputs = {},        -- Inputs defined by the task.
    outputs = {},       -- Outputs defined by the task.
    params = {},        -- Parameters defined by the task.
    env = {},           -- Environment in which the task definition is loaded.
}, {
    Class.property("path", "string")
})

function Task:_ctor(args)
    if not args.path then
        error("No task definition was provided.")
    end

    -- XXX-MJ should we just initialize all of the env here, or...
    self.env.uname_m = function ()
        local f, err = io.popen("uname -m")
        if not f then
            error("Failed to popen('uname -m'): " .. err)
        end
        local val = f:read()
        f:close()
        return val
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

function Task:bind(param, val)
    if not self.params[param] then
        error("Binding non-existent parameter '" .. param .. "'")
    end
    local validator = self.params[param].valid
    if val ~= nil and validator then
        if type(validator) == "function" and not validator(val) then
            error("Validation of parameter '" .. param .. "' value '" .. tostring(val) .. "' failed")
        end
    end
    self.params[param].val = val
end

function Task:run(ctx, inputs)
    self.env.print = print
    self.env.system = function (cmd)
        local res, how, status = os.execute(cmd)
        if res then
            return
        end
        if how == "exit" then
            error("Command '" .. cmd .. "' exited with status " .. status .. ".")
        else
            error("Command '" .. cmd .. "' terminated by signal " .. status .. ".")
        end
    end
    self.env.writefile = function (file, str)
        local f, err = io.open(file, "w")
        if not f then
            error("Failed to open '" .. file .. "': " .. err)
        end
        _, err = f:write(str)
        if err then
            error("Failed to write to '" .. file .. "': " .. err)
        end
        f:close()
    end
    self.env.cd = function (dir)
        local ok, err = Fs.chdir(dir)
        if not ok then
            error("Failed to enter directory '" .. dir "': " .. err)
        end
    end
    self.env.realpath = function (path)
        local res, err = Util.realpath(path)
        if not res then
            error("realpath('" .. path .. "') failed: " .. err)
        end
        return res
    end
    self.env.dirname, self.env.basename = Util.dirname, Util.basename
    self.env.fs = Fs
    self.env.pairs, self.env.ipairs, self.env.type = pairs, ipairs, type

    -- Let actions access parameters directly instead of going through the
    -- "val" field.
    local params = {}
    for k, v in pairs(self.params) do
        params[k] = v:value()
    end

    local outputs = {}
    for k, _ in pairs(self.outputs) do
        outputs[k] = k
    end
    self.action(ctx, params, inputs, outputs)
end

return Task
