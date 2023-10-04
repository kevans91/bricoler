-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local PL = require 'pl.import_into'()

local Class = require 'lib.bricoler.class'
local Task = require 'lib.bricoler.task'
local Util = require 'lib.bricoler.util'
local Workdir = require 'lib.bricoler.workdir'

local TaskSched = Class({
    schedule = {},              -- Tree of tasks to run.
    target = "",                -- Name of the target task to run.
    universe = {},              -- Set of all known tasks, keyed by task name.
}, {
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
    return self
end

function TaskSched:_mksched(taskname)
    if not self.universe[taskname] then
        error("Unknown task '" .. taskname .. "'.")
    end
    local task = self.universe[taskname]
    local sched = {Task{path = task.path}, taskname}
    for name, input in pairs(task.inputs) do
        sched[name] = self:_mksched(input.task)
    end
    return sched
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
            f(sched[1], sched, name)
        end
        for k, v in pairs(sched) do
            if type(k) == "string" then
                table.insert(name, k)
                _visitsched(v, f, name)
                table.remove(name)
            end
        end
        if order == "postorder" then
            f(sched[1], sched, name)
        end
    end
    _visitsched(self.schedule, cb, {})
end

-- Bind parameters for a task schedule.  "params" is an array of strings of the
-- form [<name>:]<param>=<value>.  These values override default parameter
-- values.
--
-- XXX-MJ this should be done as a part of the ctor
function TaskSched:bind(params)
    -- XXX-MJ need some more formalism here.  What happens if the same parameter
    -- is overridden from multiple tasks?
    local function bindval(sched, name, val)
        if type(val) == "function" then
            return
        elseif type(val) == "table" then
            if not sched[name] then
                error("Unmatched task input '" .. name .. "'")
            end
            for pname, pval in pairs(val) do
                bindval(sched[name], pname, pval)
            end
        else
            sched[1]:bind(name, val)
        end
    end

    -- First bind default and input values for scheduled task parameters.
    -- "Input values" are those set in an input definition, wherein a parent
    -- task specifies parameters for a direct dependency.
    self:_visit(function (task, sched)
        for name, param in pairs(task.params) do
            task:bind(name, param:defaultvalue())
        end

        for iname, input in pairs(task.inputs) do
            for pname, param in pairs(input.params) do
                bindval(sched[iname], pname, param)
            end
        end
    end)

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

    -- Then apply any bindings from the job definition, if one was provided.
    -- XXX-MJ

    -- Finally go through user-provided parameters and bind those.
    for _, v in ipairs(params) do
        -- XXX-MJ don't want to use "userbindings" here since we want to
        -- preserve the parameter order specified by the user.

        -- XXX-MJ ":" and "=" cannot appear in task names.
        local task, param, val = v:match("^([^=:]+):([^=]+)=(.*)$")
        if not task then
            task, param, val = "", v:match("^([^=:]+)=(.*)$")
        end

        local sched = self.schedule
        -- XXX-MJ "." cannot appear in task names.
        for child, _ in task:gmatch("([^%.]+)") do
            sched = sched[child]
            if not sched then
                error("Unmatched parameter name '" .. task .. "'.")
            end
        end

        sched[1]:bind(param, val)
    end

    -- Now handle lazy inter-task parameter bindings.
    -- XXX-MJ what happens if the user overrode one of these?
    self:_visit(function (task, sched)
        params = task:paramvals()
        for iname, input in pairs(task.inputs) do
            for pname, param in pairs(input.params) do
                -- XXX-MJ doesn't handle parameters for anything other than
                -- direct descendants.
                if type(param) == "function" then
                    param = param(params)
                    sched[iname][1]:bind(pname, param)
                end
            end
        end
    end, "preorder")
end

function TaskSched:run(ctx)
    if self.job then
        Workdir.push("tasks/" .. self.schedule[2] .. "/" .. self.job)
    else
        Workdir.push("runtask")
    end

    if ctx.clean then
        Workdir.clean()
    end

    -- Do we have any unbound required parameters?  Raise an error if so.
    self:_visit(function (task)
        for k, v in pairs(task.params) do
            if v.required and not v:value() then
                -- XXX-MJ error message needs to name the task too.
                error("Required parameter '" .. k .. "' is unbound.")
            end
        end
    end)

    self:_visit(function (task, sched, name)
        local dir = table.concat(name, "/")
        if dir == "" then
            dir = "."
        end

        local inputs = {}
        for k, v in pairs(sched) do
            if type(k) == "string" then
                local input = {}
                for outputname, _ in pairs(v[1].outputs) do
                    local val = v[3][outputname]
                    -- XXX-MJ this is too magical.
                    if val == outputname then
                        val = k .. "/" .. outputname
                    end
                    input[outputname] = val
                end
                inputs[k] = input
            end
        end
        Workdir.push(dir)
        local outputs = task:run(ctx, inputs)
        Workdir.pop()
        sched[3] = outputs
    end)

    -- XXX-MJ want to do this as part of a "finally" clause.
    Workdir.pop()
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

        for _, name in PL.tablex.sortv(PL.tablex.keys(task.params)) do
            local param = task.params[name]
            local val = param:value()
            if val == nil then
                -- It would be nice to use other colours to denote how the
                -- parameter was derived (e.g., user-provided, default, etc.).
                if param.required then
                    val = "???"
                    name = Util.ansicolor(name, "red")
                else
                    val = ""
                end
            end
            print(prefix(level + 1) .. "P " .. name .. "=" .. tostring(val))
        end

        for _, name in PL.tablex.sortv(PL.tablex.keys(task.outputs)) do
            print(prefix(level + 1) .. "O " .. name)
        end

        -- XXX-MJ this should use _visit, but needs preorder traversal.
        for k, v in pairs(sched) do
            if type(k) == "string" then
                dump(k, v, level + 1)
            end
        end
    end

    dump(nil, self.schedule, 0)
end

return TaskSched
