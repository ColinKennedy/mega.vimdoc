--- The internal logger - Use the supported dependency or our own.

local success, logging = pcall(function()
    return require("mega.logging")
end)

if not success then
    logging = require("mega.vimdoc._vendors._logging")
end

if not logging then
    error("Can't continue - no logging module could be found!")
end

return logging
