-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local scriptdir = (require 'posix').libgen.dirname(arg[0])
local oldcpath = package.cpath
package.cpath = oldcpath .. ";" .. scriptdir .. "/lib/freebsd/sys/?/?.so"

local M = {
    execve = require 'execve',
    sysctl = require 'sysctl',
}

package.cpath = oldcpath

return M
