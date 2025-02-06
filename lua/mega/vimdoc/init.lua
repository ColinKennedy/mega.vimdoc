--- The file that auto-creates documentation for `mega.vimdoc`.

local M = {}

--- Convert the files in this plug-in from Lua docstrings to Vimdoc documentation.
---
---@param paths mega.vimdoc.AutoDocumentationEntry[]
---    All of the source + destination pairs to process.
---@param options mega.vimdoc.AutoDocumentationOptions?
---    Customize the output using these settings, if needed.
---
function M.make_documentation_files(paths, options)
    local core = require("mega.vimdoc._core")

    core.make_documentation_files(paths, options)
end

return M
