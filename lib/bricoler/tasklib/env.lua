-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local Posix = require 'posix'
local PL = require 'pl.import_into'()

local Sys = require 'lib.freebsd.sys'
local Util = require 'lib.bricoler.util'

local function execp(ctx, cmd)
    if not ctx.quiet then
        print(("Running command '%s'")
              :format(Util.ansicolor(table.concat(cmd, " "), "green")))
    end

    local child, err = Posix.unistd.fork()
    if child == nil then
        error("Failed to fork: " .. err)
    elseif child == 0 then
        local prog = cmd[1]
        table.remove(cmd, 1)
        _, err = Posix.unistd.execp(prog, cmd)
        Util.err(42, "Failed to exec '" .. prog .. "': " .. err)
    else
        local _, how, status = Posix.sys.wait.wait(child)
        if how == "exited" and status == 0 then
            return
        elseif how == "exited" then
            error(("Command '%s' exited with status %d")
                  :format(Util.ansicolor(cmd[1], "red"), status))
        else
            error(("Command '%s' terminated by signal %d")
                  :format(Util.ansicolor(cmd[1], "red"), status))
        end
    end
end

local function system(ctx, cmd)
    if not ctx.quiet then
        print(("Running command '%s'"):format(Util.ansicolor(cmd, "green")))
    end

    local res, how, status = os.execute(cmd)
    if res then
        return
    elseif how == "exit" then
        error(("Command '%s' exited with status %d")
              :format(Util.ansicolor(cmd, "red"), status))
    else
        error(("Command '%s' terminated by signal %d")
              :format(Util.ansicolor(cmd, "red"), status))
    end
end

local function writefile(file, str)
    local f, err = io.open(file, "w")
    if not f then
        error("Failed to open '" .. file .. "': " .. err)
    end
    _, err = f:write(str)
    if err then
        error("Failed to write to '" .. file .. "': " .. err)
    end
    f:close()
end

-- Generate a checked wrapper for function "f" that takes one parameter and
-- returns at least two values: a value which is non-nil if and only if the
-- call succeeds, and an error message if the call fails.  The parameter must
-- representable as a string.
local function wrapcheck(f, name)
    return function (param)
        local res, errmsg = f(param)
        if res then
            return res
        end
        error(("%s(%s) failed: %s"):format(name, param, errmsg))
    end
end

local function uname_m()
    local utsname = Posix.sys.utsname.uname()
    return utsname.machine
end

local function uname_p()
    return os.getenv("UNAME_p") or Sys.sysctl.sysctlbyname("hw.machine_arch")
end

return function (ctx)
    -- XXX-MJ make this table immutable
    return {
        -- lua builtins.
        error = error,
        ipairs = ipairs,
        pairs = pairs,
        print = print,
        table = table,
        type = type,

        -- Command runners.
        execp = function (cmd)
            return execp(ctx, cmd)
        end,
        system = function (cmd)
            return system(ctx, cmd)
        end,

        -- I/O helpers.
        mkdirp = wrapcheck(PL.dir.makepath, "makepath"), -- XXX-MJ deprecate
        makepath = wrapcheck(PL.dir.makepath, "makepath"),
        mkdtemp = function (template)
            local res, errmsg = Posix.stdlib.mkdtemp(
                ("%s/%s.XXXXXX"):format(ctx.tmpdir, template))
            if res then
                return res
            end
            error("Failed to create temporary directory: " .. errmsg)
        end,
        writefile = writefile,

        -- Path handling.
        cd = wrapcheck(Posix.unistd.chdir, "chdir"),
        basename = wrapcheck(Posix.libgen.basename, "basename"),
        dirname = wrapcheck(Posix.libgen.dirname, "dirname"),
        isdir = PL.path.isdir,
        isfile = PL.path.isfile,
        pwd = function ()
            local res, errmsg = Posix.unistd.getcwd()
            if res then
                return res
            end
            error("Failed to get current working directory: " .. errmsg)
        end,
        realpath = wrapcheck(Posix.stdlib.realpath, "realpath"),

        -- FreeBSD system stuff.
        sysctl = Util.sysctl,
        uname_m = uname_m,
        uname_p = uname_p,
        zfs_property = function (prop, dataset)
            -- XXX-MJ yuck
            local f, err = io.popen(("zfs get -H -o value %s %s")
                                    :format(prop, dataset))
            if not f then
                error(("failed to find property '%s' for '%s': %s")
                      :format(prop, dataset, err))
            end
            local val = f:read()
            f:close()
            return val
        end,

        -- Libraries.
        MTree = require 'lib.bricoler.tasklib.mtree',
        VM = require 'lib.bricoler.tasklib.vm',
    }
end
