-- Copyright (c) 2022 Mark Johnston <markj@FreeBSD.org>

local Fs = require 'lfs'

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
            if attr.mode == "directory" then
                fsvisit(path, cb)
            end
        end
    end
end

return {
    fsvisit = fsvisit,
}
