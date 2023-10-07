-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

local MTreeEntry = Class({
}, {
    Class.property("path", "string"),
    Class.property("type", "string", {"file", "dir"}),
    Class.property("uname", "string"),
    Class.property("gname", "string"),
    Class.property("mode", "string", function (v)
        if v:match("^0[0-7][0-7][0-7]$") then
            return v
        end
        error("Mode '" .. v .. "' must be a 4-digit octal number")
    end),
})

function MTreeEntry:print(f)
    local line = self.path
    if self.type then
        line = line .. " type=" .. self.type
    end
    if self.uname then
        line = line .. " uname=" .. self.uname
    end
    if self.gname then
        line = line .. " gname=" .. self.gname
    end
    if self.mode then
        line = line .. " mode=" .. self.mode
    end
    f:write(line .. "\n")
end

local MTree = Class({
    entries = {},
    defaults = {},
}, {
    Class.property("path", "string"),
    Class.property("defaults", "table"), -- Indexed by entry type.
})

function MTree:add(path, attrs, contents)
    if not attrs.type then
        error("mtree entries must have a file type")
    end
    if self.defaults[attrs.type] then
        for k, v in pairs(self.defaults[attrs.type]) do
            if not attrs[k] then
                attrs[k] = v
            end
        end
    end

    attrs.path = path
    local entry = MTreeEntry(attrs)
    table.insert(self.entries, entry)
    if contents then
        local f = io.open(path, "w")
        if not f then
            error("Failed to open file '" .. path .. "' for writing")
        end
        f:write(contents)
        f:close()
    end
end

function MTree:_write(f)
    for _, v in ipairs(self.entries) do
        v:print(f)
    end
end

function MTree:write()
    local f = io.open(self.path, "a")
    if not f then
        error("Failed to open mtree file '" .. self.path .. "' for writing")
    end
    self:_write(f)
    f:close()
end

return MTree
