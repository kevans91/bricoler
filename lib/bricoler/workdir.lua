-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Fs = require 'lfs'

local workdir

local function mkdirp(dir)
    local attr = Fs.attributes(dir)
    if attr then
        if attr.mode ~= "directory" then
            return nil, "Path exists"
        end
        return true
    end
    return Fs.mkdir(dir)
end

local function init(dir)
    local ok, err = mkdirp(dir)
    if not ok then
        error("Failed to initialize workdir: " .. err)
    end
    ok, err = mkdirp(dir .. "/runtask")
    if not ok then
        error("Failed to initialize runtask workdir: " .. err)
    end
    ok, err = Fs.chdir(dir)
    if not ok then
        error("Failed to enter workdir: " .. err)
    end
    os.execute("rm -rf *") -- XXX-MJ
    workdir = dir
end

local function runtask()
    if not workdir then
        error("Working directory is not set.")
    end
    return workdir .. "/runtask"
end

return {
    init = init,
    runtask = runtask
}
