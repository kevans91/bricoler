-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

-- XXX-MJ this file should just use posix
local Fs = require 'lfs'

local Util = require 'lib.bricoler.util'

local function mkdirp(dir)
    local attr = Fs.attributes(dir)
    if attr then
        if attr.mode ~= "directory" then
            return nil, "Path exists"
        end
        return true
    end
    local parent = Util.dirname(dir)
    if parent ~= "." then
        local res, err = mkdirp(parent)
        if not res then
            return res, err
        end
    end
    return Fs.mkdir(dir)
end

local function clean()
    local cwd = Fs.currentdir()
    if not cwd:match("bricoler") then
        error("Cowardly refusing to run 'rm -rf *' in " .. cwd)
    end
    os.execute("rm -rf *")
end

local function init(dir)
    local ok, err = mkdirp(dir)
    if not ok then
        error("Failed to initialize workdir: " .. err)
    end
    for _, subdir in ipairs({"jobs", "runtask"}) do
        ok, err = mkdirp(dir .. "/" .. subdir)
        if not ok then
            error("Failed to create '" .. subdir .. "' subdir: " .. err)
        end
    end
    ok, err = Fs.chdir(dir)
    if not ok then
        error("Failed to enter workdir: " .. err)
    end
end

local dirstack = {}

local function push(dir)
    -- No absolute paths.
    assert(dir:sub(1, 1) ~= "/")

    local ok, err = mkdirp(dir)
    if not ok then
        error("Failed to create subdirectory '" .. dir .. "': " .. err)
    end
    table.insert(dirstack, Fs.currentdir())
    ok, err = Fs.chdir(dir)
    if not ok then
        error("Failed to enter subdirectory '" .. dir .. "': " .. err)
    end
end

local function pop()
    local dir = table.remove(dirstack)
    local ok, err = Fs.chdir(dir)
    if not ok then
        error("Failed to enter subdirectory '" .. dir .. "': " .. err)
    end
end

return {
    clean = clean,
    init = init,
    push = push,
    pop = pop,
}
