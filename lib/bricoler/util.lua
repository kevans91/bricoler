-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Fs = require 'lfs'
local Posix = require 'posix'

local function basename(path)
    return Posix.libgen.basename(path)
end

local function dirname(path)
    return Posix.libgen.dirname(path)
end

local function fsvisit(dir, cb)
    local attr = Fs.attributes(dir)
    if not attr then
        error("Root path '" .. dir .. "' does not exist.")
    elseif Fs.attributes(dir).mode ~= "directory" then
        error("Root path '" .. dir .. "' is not a directory.")
    end

    for file in Fs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local path = dir .. "/" .. file
            attr = Fs.attributes(path)
            cb(dir, file, attr)
            if attr.mode == "directory" then
                fsvisit(path, cb)
            end
        end
    end
end

local function sysctl(name)
    local f = io.popen("sysctl -n " .. name)
    if not f then
        error("Failed to popen('sysctl -n " .. name .. "').")
    end
    local val = f:read()
    f:close()
    return val
end

-- Create an array from the keys of a table.
local function tablekeys(t)
    local ret = {}
    for k, _ in pairs(t) do
        table.insert(ret, k)
    end
    return ret
end

-- Same as tablekeys() but the resulting array is sorted.
local function tablekeys_s(t, comp)
    local ret = tablekeys(t)
    table.sort(ret, comp)
    return ret
end

local function err(code, msg)
    warn(msg)
    os.exit(code)
end

local function warn(msg)
    io.stderr:write(msg)
end

return {
    basename = basename,
    dirname = dirname,
    fsvisit = fsvisit,

    sysctl = sysctl,

    tablekeys = tablekeys,
    tablekeys_s = tablekeys_s,

    err = err,
    warn = warn,
}
