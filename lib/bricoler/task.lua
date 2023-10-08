-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local PL = require 'pl.import_into'()

local Class = require 'lib.bricoler.class'

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

local function always_valid()
    return true
end

local TaskParam = Class({
    descr = "",                 -- Human readable description for help messages.
    required = false,           -- Is it an error to run without a binding?
    type = "string",
    valid = always_valid,
}, {
    Class.property("default"),
    Class.property("descr", "string"),
    Class.property("required", "boolean"),
    Class.property("type", "string"),
    Class.property("valid"),
})

function TaskParam:_ctor()
    -- Infer a (Lua) type from the default value, if any.  If the default is a
    -- bool, then make sure the value is a bool.
    local default = rawget(self, "default")
    if default then
        if self.valid == always_valid then
            if type(default) == "boolean" then
                self.valid = function (val)
                    return type(val) == "boolean" or
                            (type(val) == "string" and (val == "true" or val == "false"))
                end
            else
                self.valid = function (val) return type(val) == type(default) end
            end
        end
        self.type = type(default)
    end
    return self
end

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
}, {
    Class.property("path", "string"),
    Class.property("env", "table"),
})

function Task:_ctor(args)
    if not args.path then
        error("No task definition was provided.")
    end

    self.env = PL.tablex.copy(self.env)
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
            assert(not k:match("[%.:=]"), "Invalid character in name '" .. k .. "'")
            p[2][k] = p[3](v)
        end
    end
    return self
end

function Task:bind(paramname, val)
    if not self.params[paramname] then
        error("Binding non-existent parameter '" .. paramname .. "'")
    end
    local param = self.params[paramname]
    local validator = param.valid
    if val ~= nil then
        local f
        if type(validator) == "function" then
            f = validator
        elseif type(validator) == "table" then
            f = function (v)
                for _, candidate in ipairs(validator) do
                    if candidate == v then
                        return true
                    end
                end
                return false
            end
        else
            error("Invalid validator type '" .. type(validator) .. "'")
        end

        if not f(val) then
            error("Validation of parameter '" .. paramname .. "' value '" .. tostring(val) .. "' failed")
        end
    end
    if param.type == "boolean" and type(val) == "string" then
        assert(val == "true" or val == "false")
        val = val == "true" and true or false
    end
    param.val = val
end

function Task:paramvals()
    local params = {}
    for k, v in pairs(self.params) do
        params[k] = v:value()
    end
    return params
end

-- Define the outputs table passed to a task's Run() function.
function Task:outputtab()
    local outputs = {}
    for k, _ in pairs(self.outputs) do
        outputs[k] = k
    end

    -- Catch attempts to access undefined outputs.
    local outputsmt = {
        __index = function (_, k)
            error("Task '" .. self.path .. "' does not define output '" .. k .. "'")
        end
    }
    return setmetatable(outputs, outputsmt)
end

function Task:run(ctx, inputs)
    -- Let actions access parameters directly instead of going through the
    -- "val" field.
    local params = self:paramvals()
    local outputs = self:outputtab()
    self.action(ctx, params, inputs, outputs)
    return outputs
end

return Task
