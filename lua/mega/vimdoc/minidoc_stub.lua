--- Fake documentation for 'mini.doc', which doesn't have explicit types.
---
---@module 'mini.doc'
---

---@class MiniDoc.Hooks
---    Customization options during documentation generation. It can control
---    section headers, newlines, etc.
---@field sections table<string, fun(data: any): nil>
---    When a section is visited by the documentation generator, this table is
---    consulted to decide what to do with that section.

---@class MiniDoc.SectionInfo
---    A description of what this section is meant to display / represent.
---@field id string
---    The section label. e.g. `"@param"`, `"@return"`, etc.

---@class MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---    This class is from mini.doc. We're just type-annotating it so `llscheck` is happy.
---@see https://github.com/echasnovski/mini.doc
---@field info MiniDoc.SectionInfo
---    A description of what this section is meant to display / represent.
---@field parent MiniDoc.Section?
---    The section that includes this instance as one of its children, if any.
---@field parent_index integer?
---    If a `parent` is defined, this is the position of this instance in `parent`.
---@field type string
---    A description about what this object is. Is it a section or a block or
---    something else? Stuff like that.
---
local _Section = {} -- luacheck: ignore 241 -- variable never accessed

--- Add `child` to this instance at `index`.
---
---@param index integer The 1-or-more position to add `child` into.
---@param child string The text to add.
---
function _Section:insert(index, child) end -- luacheck: ignore 212 -- unused argument

--- Remove a child from this instance at `index`.
---
---@param index integer? The 1-or-more position to remove `child` from.
---
function _Section:remove(index) end -- luacheck: ignore 212 -- unused argument
