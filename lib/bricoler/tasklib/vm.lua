-- Copyright (c) Mark Johnston <markj@FreeBSD.org>

local Class = require 'lib.bricoler.class'

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
    if not args.interactive then
        local expect, err = io.popen("expect", "w")
        if not expect then
            error(err)
        end
        self._expect = expect
        self:expect("set timeout -1")
        if self.log then
            self:expect("log_file " .. self.log)
        end
    else
        self.expect = nil
    end
    return self
end

function VM:expect(cmd)
    if not self._expect then
        error("VM is interactive")
    end
    self._expect:write(cmd .. "\n")
end

function VM:boot()
    self:expect("spawn " .. self.cmd)
    self:expect("expect login:")
    self:expect("send -- root\\n")
    self:expect("expect -re root@.*#")
end

return VM
