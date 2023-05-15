-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

-- Interface to the job database, implemented using SQLite3.  This is the only
-- module that should contain SQL statements.

local SQLite3 = require 'lsqlite3'

local Class = require 'lib.bricoler.class'

local Job = Class({
    bindings = {}, -- Map task name -> dictionary of parameter bindings.
}, {
    Class.property("name", "string"),
    Class.property("bindings", "table"),
})

local JobDB = Class({
    sqlh = {},
}, {
    Class.property("path", "string"),
    Class.property("tasks", "table"),
})

local function sqlok(err)
    return err == SQLite3.OK
end

function JobDB:_ctor(args)
    if not args.path then
        error("No database path was provided.")
    end

    local sqlh, err, msg = SQLite3.open(args.path, SQLite3.OPEN_READWRITE)
    if not sqlh then
        if err == SQLite3.CANTOPEN then
            sqlh, _, msg = SQLite3.open(args.path, SQLite3.OPEN_READWRITE + SQLite3.OPEN_CREATE)
            if not sqlh then
                error(msg)
            end
            self.sqlh = sqlh
            self:_init(1) -- XXX-MJ hard-coded version
        else
            error(msg)
        end
    end
    self.sqlh = sqlh

    -- Create a row in the "tasks" table for each task in the universe that
    -- isn't already present.
    local tasks = {}
    for task, _ in pairs(args.tasks) do
        local id = self:_taskid(task)
        if not id then
            err = self:_exec([[
INSERT INTO tasks (name) VALUES (']] .. task .. [[');
            ]])
            if not sqlok(err) then
                error("Failed to insert task '" .. task .. "' into tasks table: " .. self:_errmsg())
            end
            id = self:_taskid(task)
        end
        tasks[task] = id
    end
    self.tasks = tasks

    return self
end

function JobDB:_init(version)
    local err = self:_exec([[
CREATE TABLE meta (
    schema_version INTEGER PRIMARY KEY CHECK (schema_version >= 1)
);

CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    next_id INTEGER, -- Initially zero.
    task_id REFERENCES tasks(id) ON DELETE CASCADE,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE param_bindings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id REFERENCES jobs(id) ON DELETE CASCADE,
    param_task TEXT NOT NULL,
    param_name TEXT NOT NULL,
    param_value TEXT NOT NULL
);

-- XXX-MJ start/stop timestamps
-- XXX-MJ completion status
CREATE TABLE task_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_name TEXT NOT NULL
);
        ]])
    if not sqlok(err) then
        error("Failed to initialize jobs database: " .. self:_errmsg())
    end

    err = self:_exec(([[
INSERT INTO meta VALUES (%d);
        ]]):format(version))
    if not sqlok(err) then
        error("Failed to initialize jobs database: " .. self:_errmsg())
    end
end

function JobDB:_exec(...)
    return self.sqlh:exec(...)
end

function JobDB:_errmsg()
    return self.sqlh:errmsg()
end

function JobDB:_jobid(jobname, taskname)
    local job = nil
    local err = self:_exec(([[
SELECT jobs.id FROM jobs
  INNER JOIN tasks ON jobs.task_id = tasks.id
  WHERE jobs.name = '%s' AND tasks.name = '%s';
]]):format(jobname, taskname),
    function (_, _, values, _)
        job = values[1]
        return 0
    end)
    if not sqlok(err) then
        error("Failed to query jobs table: " .. self:_errmsg())
    end
    return job
end

-- Look up a task's ID.
function JobDB:_taskid(taskname)
    local task = nil
    local err = self:_exec(("SELECT id FROM tasks WHERE tasks.name = '%s';")
                           :format(taskname),
    function (_, _, values, _)
        task = values[1]
        return 0
    end)
    if not sqlok(err) then
        error("Failed to query tasks table: " .. self:_errmsg())
    end
    return task
end

function JobDB:add(jobname, taskname, bindings)
    local taskid = self.tasks[taskname]
    if not taskid then
        error("Task '" .. taskname .. "' is not known")
    end
    local err = self:_exec(([[
INSERT INTO jobs (name, task_id)
  VALUES ('%s', '%d');
]]):format(jobname, taskid))
    if not sqlok(err) then
        error("Failed to add job '" .. jobname .. "': " .. self:_errmsg())
    end
    local jobid = self:_jobid(jobname, taskname)

    for task, params in pairs(bindings) do
        for param, value in pairs(params) do
            print(param, value)
            err = self:_exec(([[
INSERT INTO param_bindings (job_id, param_task, param_name, param_value)
  VALUES (%d, '%s', '%s', '%s');
]]):format(jobid, task, param, value))
        end
    end
end

function JobDB:lookup(jobname, taskname)
    return self:_jobid(jobname, taskname)
end

return JobDB
