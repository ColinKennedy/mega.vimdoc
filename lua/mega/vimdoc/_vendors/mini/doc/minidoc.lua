--- Any class / function copied from [mini.doc](https://github.com/echasnovski/mini.doc).

local M = {}

--- Surround `"variable_name"` with `"{variable_name}"`.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---
function M.enclose_var_name(section)
    section[1] = section[1]:gsub("(%S+)", "{%1}", 1)
end

--- Prepend a Vimdoc header to `section`.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---@param heading string
---    A title for the heading. e.g. `"Return"`.
---
function M.add_section_heading(section, heading)
    section:insert(1, ("%s ~"):format(heading))
end

--- Treat question mark at end of first word as "optional" indicator. See:
---
--- https://github.com/sumneko/lua-language-server/wiki/EmmyLua-Annotations#optional-params
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---
function M.mark_optional(section)
    section[1] = section[1]:gsub("^(%s-%S-)%?", "%1 (optional)", 1)
end

return M
