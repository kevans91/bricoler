-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'
local orch = require 'orch'

local VM = Class({
    _expect = {},
}, {
    Class.property("cmd", "string"),
    Class.property("image", "string"),
    Class.property("log", "string"),
    Class.property("ssh_key", "string"),
    Class.property("interactive", "boolean"),
})

function VM:_ctor(args)
    self.interactive = args.interactive
    return self
end

function VM:cfg(cfg)
    if self.interactive then
        error("VM is interactive")
    end

    self.process:cfg(cfg)
end
function VM:eof()
    if self.interactive then
        error("VM is interactive")
    end

    self.process:eof()
end
function VM:match(text)
    if self.interactive then
        error("VM is interactive")
    end

    self.process:match(text)
end
function VM:write(text)
    if self.interactive then
        error("VM is interactive")
    end

    self.process:write(text)
end

function VM:boot()
    local cmdtable = {}

    for word in self.cmd:gmatch("([^%s]+)") do
        cmdtable[#cmdtable + 1] = word
    end

    local process = orch.spawn(cmdtable)
    process.timeout = nil
    if self.log then
        process:log(self.log)
    end

    process:match("login")
    process:write("root\n")
    process:match("root@.*#")
    self.process = process
end

return VM
