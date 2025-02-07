--- All types needed for `mega.vimdoc` to work as expected.

---@class mega.vimdoc.AutoDocumentationEntry
---    The simple source/destination of "Lua file that we want to auto-create
---    documentation from + the .txt file that we want auto-create to".
---@field source string
---    An absolute path to a Lua file on-disk. e.g. `"/path/to/foo.lua"`.
---@field destination string
---    An absolute path for the auto-created documentation.
---    e.g. `"/out/mega_vimdoc.txt"`.

---@class mega.vimdoc.AutoDocumentationOptions
---    Customize the documentation output using these settings, if needed.
---@field enable_module_in_signature boolean?
---    If `true`, a function signature like `M.bar(value)` will have its "M"
---    replaced with the actual module name like `foo.bar(value)`.
