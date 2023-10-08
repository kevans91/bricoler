-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local Fs = require 'lfs'
local PL = require 'pl.import_into'()
local Posix = require 'posix'

local Sys = require 'lib.freebsd.sys'

local function ansicolor(str, color)
    local ctab = {
        green = "32m",
        red = "31m",
    }

    local esc = ctab[color]
    if not esc then
        error("ansicolor: unknown color '" .. color .. "'")
    end

    return "\x1b[" .. esc .. str .. "\x1b[0m"
end

local function basename(path)
    return Posix.libgen.basename(path)
end

local function dirname(path)
    return Posix.libgen.dirname(path)
end

-- Create the named directory and intermediate directories as required.
-- No error is raised if the directory already exists.
local function mkdirp(dir)
    return PL.dir.makepath(dir)
end

local function pwd()
    return Posix.unistd.getcwd()
end

local function realpath(path)
    return Posix.stdlib.realpath(path)
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
            if attr and attr.mode == "directory" then
                -- "attr" can be nil if the file is a dangling symlink.
                fsvisit(path, cb)
            end
        end
    end
end

local function sysctl(name)
    return Sys.sysctl.sysctlbyname(name)
end

local function err(code, msg)
    warn(msg)
    os.exit(code)
end

local function warn(msg)
    io.stderr:write(msg .. "\n")
end

return {
    ansicolor = ansicolor,
    basename = basename,
    dirname = dirname,
    mkdirp = mkdirp,
    pwd = pwd,
    realpath = realpath,
    fsvisit = fsvisit,

    sysctl = sysctl,

    err = err,
    warn = warn,
}
