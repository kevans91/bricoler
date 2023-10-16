-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

-- XXX-MJ this file should just use posix
local Fs = require 'lfs'

local Util = require 'lib.bricoler.util'

local dirstack = {}

local function clean()
    local cwd = Fs.currentdir()
    assert(cwd:sub(1, 1) == "/")
    if not cwd:match("bricoler") then
        error("Cowardly refusing to run 'rm -rf *' in " .. cwd)
    end
    if #dirstack == 0 then
        error("Cannot clean without having entered a workdir")
    end
    os.execute("rm -rf *")
end

local function init(dir, tasks)
    local ok, err = Util.mkdirp(dir)
    if not ok then
        error("Failed to initialize workdir: " .. err)
    end
    for _, subdir in ipairs({"tasks", "runtask", "tmp"}) do
        ok, err = Util.mkdirp(dir .. "/" .. subdir)
        if not ok then
            error("Failed to create '" .. subdir .. "' subdir: " .. err)
        end
    end
    for task, _ in pairs(tasks) do
        ok, err = Util.mkdirp(dir .. "/tasks/" .. task)
        if not ok then
            error("Failed to create task subdir '" .. task .. "': " .. err)
        end
    end
    ok, err = Fs.chdir(dir)
    if not ok then
        error("Failed to enter workdir: " .. err)
    end
end

local function push(dir)
    -- No absolute paths.
    assert(dir:sub(1, 1) ~= "/")

    local ok, err = Util.mkdirp(dir)
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
