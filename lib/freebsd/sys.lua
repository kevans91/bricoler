-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local oldcpath = package.cpath
package.cpath = package.cpath .. ";./lib/freebsd/sys/?/?.so"

local M = {
    execve = require 'execve',
    sysctl = require 'sysctl',
}

package.cpath = oldcpath

return M
