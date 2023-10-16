-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local PL = require 'pl.import_into'()

local Class = require 'lib.bricoler.class'
local Task = require 'lib.bricoler.task'
local Util = require 'lib.bricoler.util'
local Workdir = require 'lib.bricoler.workdir'

local TaskSchedNode = Class({
    outputs = {},
}, {
    Class.property("task", "table"),
    Class.property("name", "string"),
    Class.property("inputs", "table"),
})

local TaskSched = Class({
    schedule = {},              -- Tree of tasks to run.
    target = "",                -- Name of the target task to run.
    universe = {},              -- Set of all known tasks, keyed by task name.
}, {
    Class.property("env", "table"),
    Class.property("params", "table"),
    Class.property("universe", "table"),
    Class.property("target", "string"),
    Class.property("job", "string"), -- Can be nil.
    Class.property("jobdb"),
})

function TaskSched:_ctor()
    if not self.universe[self.target] then
        error("Unknown task '" .. self.target .. "'.")
    end
    self.schedule = self:_mksched(self.target)
    self:_bind(self.params)
    return self
end

function TaskSched:_mksched(taskname)
    if not self.universe[taskname] then
        error("Unknown task '" .. taskname .. "'.")
    end
    local task = Task{
        env = self.env,
        path = self.universe[taskname],
    }
    local inputs = {}
    for name, input in pairs(task.inputs) do
        inputs[name] = self:_mksched(input.task)
    end
    return TaskSchedNode{
        task = task,
        name = taskname,
        inputs = inputs,
    }
end

-- Invoke a callback on all tasks in a schedule in post-order, i.e., children
-- are visited before parents.
function TaskSched:_visit(cb, order)
    if order == nil then
        order = "postorder"
    end
    assert(order == "preorder" or order == "postorder")

    local function _visitsched(sched, f, name)
        if order == "preorder" then
            f(sched, name)
        end
        for k, v in pairs(sched.inputs) do
            table.insert(name, k)
            _visitsched(v, f, name)
            table.remove(name)
        end
        if order == "postorder" then
            f(sched, name)
        end
    end
    _visitsched(self.schedule, cb, {})
end

-- Same as _visit, but also changes to the task's working directory before.
-- invoking the callback.
function TaskSched:_visitcd(cb, ...)
    self:_visit(function (sched, id, ...)
        local dir = table.concat(id, "/")
        if dir == "" then
            dir = "."
        end
        Workdir.push(dir)
        cb(sched, id, ...)
        Workdir.pop()
    end, ...)
end

-- Bind parameters for a task schedule.  "params" is an array of strings of the
-- form [<name>:]<param>=<value>.  These values override default parameter
-- values.
function TaskSched:_bind(params)
    -- Normalize user-specified parameters.
    local normal = {}
    for _, v in ipairs(params) do
        local task, param, val = v:match("^([^=:]+):([^=]+)=(.*)$")
        if not task then
            task, param, val = self.target, v:match("^([^=:]+)=(.*)$")
        end
        local tparams = normal[task] or {}
        tparams[param] = {
            val = val,
            src = "cmdline: " .. v,
        }
        normal[task] = tparams
    end
    params = normal

    -- XXX-MJ need some more formalism here.  What happens if the same parameter
    -- is overridden from multiple tasks?
    local function bindval(sched, name, val, src)
        if type(val) == "function" then
            return
        elseif type(val) == "table" then
            if not sched.inputs[name] then
                error("Unmatched task input '" .. name .. "'")
            end
            for pname, pval in pairs(val) do
                bindval(sched.inputs[name], pname, pval, src)
            end
        else
            sched.task:bind(name, val, src)
        end
    end

    -- First bind default and input values for scheduled task parameters.
    -- "Input values" are those set in an input definition, wherein a parent
    -- task specifies parameters for a direct dependency.
    self:_visit(function (sched)
        local task = sched.task
        for name, param in pairs(task.params) do
            task:bind(name, param:defaultvalue(), "default")
        end

        for iname, input in pairs(task.inputs) do
            for pname, param in pairs(input.params) do
                bindval(sched.inputs[iname], pname, param, "parent: " .. sched.name)
            end
        end
    end)

    --[[
    if self.job then
        if not self.jobdb:lookup(self.job, self.schedule[2]) then
            local userbindings = {}
            for _, v in ipairs(params) do
                local task, param, val = v:match("^([^=:]+):([^=]+)=(.*)$")
                if not task then
                    task, param, val = self.target, v:match("^([^=:]+)=(.*)$")
                end

                if not userbindings[task] then
                    userbindings[task] = {}
                end
                userbindings[task][param] = val
            end
            self.jobdb:add(self.job, self.schedule[2], userbindings)
        end
    end
    -- Then apply any bindings from the job definition, if one was provided. XXX-MJ
    ]]

    -- Finally go through user-provided parameters and bind those.
    for task, v in pairs(params) do
        local sched = self.schedule

        if task ~= self.target then
            for child, _ in task:gmatch("([^%.]+)") do
                sched = sched.inputs[child]
                if not sched then
                    error("Unmatched parameter name '" .. task .. "'.")
                end
            end
        end

        for param, val in pairs(v) do
            sched.task:bind(param, val.val, val.src)
        end
    end

    -- Now handle lazy inter-task parameter bindings.
    -- XXX-MJ what happens if the user overrode one of these? need to print a warning at minimum
    self:_visit(function (sched)
        local task = sched.task
        params = task:paramvals()
        for iname, input in pairs(task.inputs) do
            for pname, param in pairs(input.params) do
                -- XXX-MJ doesn't handle parameters for anything other than
                -- direct descendants.
                if type(param) == "function" then
                    param = param(params)
                    sched.inputs[iname].task:bind(pname, param, sched.name)
                end
            end
        end
    end, "preorder")
end

-- Execute a task schedule, having bound paramter values.
-- "ctx" provides global parameters that get passed to each task's Run().
function TaskSched:run(clean, ctx)
    if self.job then
        Workdir.push("tasks/" .. self.schedule[2] .. "/" .. self.job)
    else
        Workdir.push("runtask")
    end

    -- Do we have any unbound required parameters?  Raise an error if so.
    self:_visit(function (sched)
        for k, v in pairs(sched.task.params) do
            if v.required and not v:value() then
                -- XXX-MJ error message needs to name the task too.
                error("Required parameter '" .. k .. "' is unbound.")
            end
        end
    end)

    -- Clean working directories if asked to do so.
    if clean ~= nil then
        if #clean == 0 then
            Workdir.clean()
        else
            -- Before doing anything destructive, make sure that all of the
            -- task directories we were asked to clean actually exist.
            local toclean = PL.tablex.copy(clean)
            self:_visit(function (_, id)
                local name = table.concat(id, ".")
                if toclean[name] then
                    toclean[name] = nil
                end
            end)
            if next(toclean) then
                local list = table.concat(PL.tablex.keys(toclean), ", ")
                error("Asked to clean unknown tasks " .. list)
            end
            -- Seems ok, go ahead and clean.
            self:_visitcd(function (_, id)
                local name = table.concat(id, ".")
                if clean[name] then
                    Workdir.clean()
                end
            end)
        end
    end

    self:_visitcd(function (sched)
        local inputs = {}
        for k, v in pairs(sched.inputs) do
            local input = {}
            for outputname, _ in pairs(v.task.outputs) do
                local val = v.outputs[outputname]
                if val == outputname then
                    val = k .. "/" .. outputname
                end
                input[outputname] = val
            end
            inputs[k] = input
        end
        sched.outputs = sched.task:run(ctx, inputs)
    end)

    Workdir.pop()
end

function TaskSched:print()
    local function dump(input, sched, level)
        local task, taskname = sched.task, sched.name

        local function indent(count, str)
            return ("  "):rep(count) .. str
        end

        if input then
            print(indent(level, ("T %s (%s)"):format(input, taskname)))
        else
            print(indent(level, taskname))
        end

        for _, paramname in PL.tablex.sortv(PL.tablex.keys(task.params)) do
            local param = task.params[paramname]
            local val = param:value()
            if val == nil then
                -- It would be nice to use other colours to denote how the
                -- parameter was derived (e.g., user-provided, default, etc.).
                if param.required then
                    val = "???"
                    paramname = Util.ansicolor(paramname, "red")
                else
                    val = ""
                end
            end
            local src = param:source()
            local toprint = ("P %s=%s"):format(paramname, tostring(val))
            toprint = toprint .. " (" .. src .. ")"
            print(indent(level + 1, toprint))
        end

        for _, name in PL.tablex.sortv(PL.tablex.keys(task.outputs)) do
            print(indent(level + 1, "-> " .. name))
        end

        -- XXX-MJ this should use _visit, but needs preorder traversal.
        for k, v in pairs(sched.inputs) do
            dump(k, v, level + 1)
        end
    end

    dump(nil, self.schedule, 0)
end

return TaskSched
