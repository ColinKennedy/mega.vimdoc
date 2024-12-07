--- The file that auto-creates documentation for `aggro.vimdoc`.
---
---@module 'aggro.vimdoc'
---

local M = {}

--- Convert the files in this plug-in from Lua docstrings to Vimdoc documentation.
---
---@param paths aggro.vimdoc.AutoDocumentationEntry[]
---    All of the source + destination pairs to process.
---
function M.make_documentation_files(paths)
    local core = require("aggro.vimdoc._core")

    core.make_documentation_files(paths)
end

return M
