-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

package.cpath = package.cpath .. ";./lib/freebsd/?.so"

return {
    sysctl = require 'sys.sysctl',
}
