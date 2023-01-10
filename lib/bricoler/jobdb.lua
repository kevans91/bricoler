-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

-- Interface to the job database, implemented using SQLite3.  This is the only
-- module that should contain SQL statements.

local SQLite3 = require 'lsqlite3'

local Class = require 'lib.bricoler.class'

local JobDB = Class({
    sqlh = {},
}, {
    Class.property("path", "string"),
})

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
            self:_init()
        else
            error(msg)
        end
    end

    self.sqlh = sqlh
    return self
end

function JobDB:_init(version)
    local function sqlok(err)
        return err == SQLite3.OK
    end

    local err = self:_exec([[
CREATE TABLE meta (
    schema_version INTEGER PRIMARY KEY CHECK (schema_version >= 1)
);

CREATE TABLE jobs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    task TEXT NOT NULL
);

CREATE TABLE job_bindings (
    job_id REFERENCES jobs(id) ON DELETE CASCADE,
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
INSERT INTO schema_version VALUES (%d);
        ]]):format(version))
    if not sqlok(err) then
        error("Failed to initialize jobs database: " .. self:_errmsg())
    end
end

function JobDB:_exec(sql)
    return self.sqlh:exec(sql)
end

function JobDB:_errmsg()
    return self.sqlh:errmsg()
end

return JobDB
