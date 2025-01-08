--- The internal logger - Use the supported dependency or our own.
---
---@module 'mega.vimdoc._vendors.logging'
---

local success, logging = pcall(function()
    return require("mega.logging")
end)

if not success then
    logging = require("mega.vimdoc._vendors._logging")
end

if not logging then
    error("Can't continue - no logging module could be found!")
end

local M = {}

M.get_logger = logging.get_logger

return M
