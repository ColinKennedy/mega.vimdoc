--- The file that auto-creates documentation for `mega.vimdoc`.
---
---@module 'mega.vimdoc'
---

local M = {}

--- Convert the files in this plug-in from Lua docstrings to Vimdoc documentation.
---
---@param paths mega.vimdoc.AutoDocumentationEntry[]
---    All of the source + destination pairs to process.
---
function M.make_documentation_files(paths)
    local core = require("mega.vimdoc._core")

    core.make_documentation_files(paths)
end

return M
