-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local SQLite3 = require 'lsqlite3'

local Class = require 'lib.bricoler.class'

local JobDB = Class({
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
        end
        if not sqlh then
            error(msg)
        end
    end

    self.sqlh = sqlh
end

return JobDB
