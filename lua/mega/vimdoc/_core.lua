--- The file that auto-creates documentation for `mega.vimdoc`.

local logging = require("mega.vimdoc._vendors.logging")

local success, doc = pcall(require, "mini.doc")

if not success then
    error("mini.doc is required to run mega.vimdoc. Please clone + source https://github.com/echasnovski/mini.doc", 0)
end

local _P = {}

---@diagnostic disable-next-line: undefined-field
if _G.MiniDoc == nil then
    doc.setup()
end

local _LOGGER = logging.get_logger("mega.vimdoc._core")

local M = {}

--- Check if `text` starts with whitespace.
---
---@param line string An text to check.
---@return boolean # If `"   foo"`, return `true`.
---
function _P.has_indent(line)
    if not line[1] then
        return false
    end

    return line[1]:gmatch("^%s") == nil
end

--- Check if `text` is the start of a function's parameters.
---
---@param text string Some text. e.g. `"Parameters ~"`.
---@return boolean # If it's a section return `true`.
---
function _P.is_field_section(text)
    return text:match("%s*Fields%s*~%s*")
end

--- Check if `text` is the start of a function's parameters.
---
---@param text string Some text. e.g. `"Parameters ~"`.
---@return boolean # If it's a section return `true`.
---
function _P.is_parameter_section(text)
    return text:match("%s*Parameters%s*~%s*")
end

function _P.is_section_header(section)
    return section[1]:match("~$") ~= nil
end

--- Check if `text` is the start of a function's parameters.
---
---@param text string Some text. e.g. `"Return ~"`.
---@return boolean # If it's a section return `true`.
---
function _P.is_return_section(text)
    return text:match("%s*Return%s*~%s*")
end

--- Check if `text` contains only spaces / tabs.
---
---@param text string Some text to check. e.g. `"   foo   "`.
---@return boolean # If there is any non-whitespace, return `true`.
---
function _P.is_whitespace(text)
    return text:match("^%s*$") ~= nil
end

--- Find every line in `section` that has non-whitespace.
---
--- Important:
---     It's assumed that `section` starts with a non-whitespace line. If it
---     doesn't, this function returns nothing.
---
---@param section string[] The text to checkj.
---@return string[] # The found lines, if any.
---
function _P.get_consecutive_lines_with_text(section)
    ---@type string[]
    local output = {}

    for _, line in ipairs(section) do
        if _P.is_whitespace(line) then
            break
        end

        table.insert(output, line)
    end

    return output
end

--- Get the last (contiguous) key in `data` that is numbered.
---
--- `data` might be a combination of number or string keys. The first key is
--- expected to be numbered. If so, we get the last key that is a number.
---
--- Raises:
---     If `data` isn't a numeric table.
---
---@param data table<integer | string, any> The data to check.
---@return number # The last found key.
---
function _P.get_last_numeric_key(data)
    local found = nil

    for key, _ in pairs(data) do
        if type(key) ~= "number" then
            if not found then
                error("No number key could be found.")
            end

            return found
        end

        found = key
    end

    return found
end

--- Create the callbacks that we need to create our documentation.
---
---@param module_identifier string?
---    If provided, any reference to this identifier (e.g. `"M"`) will be
---    replaced with the real import path.
---@return MiniDoc.Hooks
---    All of the generated callbacks.
---
function _P.get_module_enabled_hooks(module_identifier)
    local module_name = nil

    local hooks = vim.deepcopy(doc.default_hooks)

    hooks.sections["@class"] = function(section)
        if #section == 0 or section.type ~= "section" then
            return
        end

        section[1] = _P.add_tag(section[1])
    end

    local original_field_hook = hooks.sections["@field"]

    hooks.sections["@field"] = function(section)
        original_field_hook(section)

        for index, line in ipairs(section) do
            section[index] = _P.indent(line)
        end
    end

    hooks.sections["@module"] = function(section)
        module_name = _P.strip_quotes(section[1])

        section:clear_lines()
    end

    local original_param_hook = hooks.sections["@param"]

    hooks.sections["@param"] = function(section)
        original_param_hook(section)

        for index, line in ipairs(section) do
            section[index] = _P.indent(line)
        end
    end

    local original_return_hook = hooks.sections["@return"]

    -- NOTE: The mini.doc has no indentation by default. Add it.
    hooks.sections["@return"] = function(section)
        original_return_hook(section)

        for index = 2, #section do
            local line = section[index]

            if not _P.has_indent(line) then
                section[index] = _P.indent(line)
            end
        end
    end

    local original_signature_hook = hooks.sections["@signature"]

    hooks.sections["@signature"] = function(section)
        if module_identifier and module_name then
            _P.replace_function_name(section, module_identifier, module_name)
        end

        _P.add_before_after_whitespace(section)

        original_signature_hook(section)

        -- NOTE: Remove the leading whitespace caused by MiniDoc
        for index, text in ipairs(section) do
            section[index] = (text:gsub("^%s+", ""))
        end
    end

    local original_tag_hook = hooks.sections["@tag"]

    hooks.sections["@tag"] = function(section)
        if module_identifier and module_name then
            _P.replace_function_name(section, module_identifier, module_name)
        end

        original_tag_hook(section)
    end

    local original_block_post_hook = hooks.block_post

    hooks.block_post = function(block)
        original_block_post_hook(block)

        if not block:has_lines() then
            return
        end

        _P.apply_recursively(function(section)
            if not (type(section) == "table" and section.type == "section") then
                return
            end

            if
                section.info.id == "@field" and _P.is_field_section(section[1])
                or section.info.id == "@param" and _P.is_parameter_section(section[1])
            then
                local previous_section = _P.get_previous_sibling(section)

                if previous_section then
                    _P.strip_trailing_newlines(previous_section)
                    _P.set_leading_newline(section)
                end
            end

            if section.info.id == "@return" and _P.is_return_section(section[1]) then
                local previous_section = section.parent[section.parent_index - 1]

                if previous_section then
                    _P.set_leading_newline(section)
                end
            end
        end, block)
    end

    hooks.section_pre = function(section)
        if section.info.id == "@return" then
            local count = _P.get_consecutive_lines_with_text(section)

            if #count ~= 1 then
                return
            end

            section[1] = _P.strip_inline_return_escape_character(section[1])
        end
    end

    hooks.write_pre = function(lines)
        table.insert(lines, #lines, "WARNING: This file is auto-generated. Do not edit it!")
        table.insert(lines, #lines, "")

        return lines
    end

    return hooks
end

--- Parse `path` to find the source code that refers to the user's Lua file, if any.
---
--- Raises:
---     If `path` is not readable.
---
---@param path string
---    The absolute path to a Lua file on-disk that we assume may have a line
---    like `return M` at the bottom which exports 0-or-more Lua classes / functions.
---@return string?
---    The found identifier. By convention it's usually `"M"` or nothing.
---
function _P.get_module_identifier(path)
    local buffer = _P.make_temporary_buffer(path)
    local node = _P.get_return_node(buffer)

    if not node then
        _LOGGER:fmt_debug('Path "%s" has no return statement.', path)

        return nil
    end

    local count = node:named_child_count() - 1

    for index = 0, count do
        local child = node:named_child(index)

        if not child then
            local text = vim.treesitter.get_node_text(node, buffer)
            error(string.format('Bug: Node "%s" somehow has no "%s" index.', text, index), 0)
        end

        if child:type() == "expression_list" then
            return vim.treesitter.get_node_text(child, buffer)
        end
    end

    _LOGGER:fmt_debug(
        'This could be a bug or "%s" file actually has an empty return statement. ' .. "Please double-check",
        path
    )

    return nil
end

-- local function _P.get_module_identifier(path) -- luacheck: ignore 212 -- unused argument
--     local file = io.open(path, "w")
--
--     if not file then
--         error(string.format('Path "%s" is not readable.', path), 0)
--     end
--
--     for line in file:lines() do
--         local match = line:match("---@module ['\"]([^'\"]+)['\"]")
--
--         if match then
--             return match
--         end
--
--         if not line:match("^%s*$") then
--             return nil
--         end
--     end
--
--     return nil
-- end

--- Find the sibling that comes before `section`, if any.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---@return MiniDoc.Section?
---    The found sibling, if any.
---
function _P.get_previous_sibling(section)
    return section.parent[section.parent_index - 1]
end

--- Find the bottom `return ...` statement in the Lua `buffer`.
---
---@param buffer integer A 0-or-more Vim data buffer. 0 == the current buffer.
---@return TSNode? # The found node, if any.
---
function _P.get_return_node(buffer)
    local parser = vim.treesitter.get_parser(buffer, "lua")

    if not parser then
        return nil
    end

    local tree = parser:parse()[1]
    local root = tree:root()
    local return_node = root:named_child(root:named_child_count() - 1)

    if not return_node then
        return nil
    end

    if return_node:type() ~= "return_statement" then
        return nil
    end

    return return_node
end

--- Ensure there is one blank space around `section` by modifying it.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---
function _P.add_before_after_whitespace(section)
    section:insert(1, "")
    local last = _P.get_last_numeric_key(section)
    section:insert(last + 1, "")
end

--- Run `caller` on `section` and all of its children recursively.
---
---@param caller fun(section: MiniDoc.Section): nil A callback used to modify its given `section`.
---@param section MiniDoc.Section The starting point to traverse underneath.
---
function _P.apply_recursively(caller, section)
    caller(section)

    if type(section) == "table" then
        for _, t in ipairs(section) do
            _P.apply_recursively(caller, t)
        end
    end
end

--- Add the text that Vimdoc uses to generate doc/tags (basically surround the text with *s).
---
---@param text string Any text, e.g. `"mega.vimdoc.ClassName"`.
---@return string # The wrapped text, e.g. `"*mega.vimdoc.ClassName*"`.
---
function _P.add_tag(text)
    return (text:gsub("(%S+)", "%*%1%*"))
end

--- Add leading whitespace to `text`, if `text` is not an empty line.
---
---@param text string The text to modify, maybe.
---@return string # The modified `text`, as needed.
---
function _P.indent(text)
    if not text or text == "" then
        return text
    end

    return "    " .. text
end

--- Change the function name in `section` from `module_identifier` to `module_name`.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---    We assume this `section` represents a Lua function.
---@param module_identifier string
---    Usually a function in Lua is defined with `function M.foo`. In this
---    example, `module_identifier` would be the `M` part.
---@param module_name string
---    The real name for the module. e.g. `"mega.vimdoc"`.
---
function _P.replace_function_name(section, module_identifier, module_name)
    local prefix = string.format("^%s%%.", module_identifier)
    local replacement = string.format("%s.", module_name)

    for index, line in ipairs(section) do
        line = line:gsub(prefix, replacement)
        section[index] = line
    end
end

--- Remove trailing whitespace from `text`.
---
---@param text string The user text, e.g. `"   foo "`.
---@return string # `"   foo"`.
---
function _P.rstrip(text)
    return (text:gsub("%s+$", ""))
end

--- Add newlines to the start of `section` if needed.
---
---@param section MiniDoc.Section
---    The object to possibly modify.
---@param count integer?
---    The number of lines to put before `section` if needed. If the section
---    has more newlines than `count`, it is converted back to `count`.
---
function _P.set_leading_newline(section, count)
    count = count or 1
    local lines = 0

    for _, line in ipairs(section) do
        if not _P.is_whitespace(line) then
            break
        end

        lines = lines + 1
    end

    if count > lines then
        for _ = 1, count - lines do
            section:insert(1, "")
        end
    else
        for _ = 1, lines - count do
            section:remove(1)
        end
    end
end

--- Remove the `"# "` prefix from return `text` if there is some.
---
--- LuaCATs annotations expects a `#` if you add a comment on the `@return`
--- block. e.g. `---@return string # foo bar.` But we don't want the `"# "` in
--- the Vimdoc, so remove it.
---
--- https://luals.github.io/wiki/annotations/#return
---
---@param text string A return description (note: This might be empty).
---@return string # The returned, modified text.
---
function _P.strip_inline_return_escape_character(text)
    local before, after = text:match("(.*)#%s*(.*)")

    if before and after then
        return _P.rstrip(before) .. " " .. after
    end

    return text
end

--- Remove all whitespace at the end of `section`, if any.
---
---@param section MiniDoc.Section The documentation to modify.
---
function _P.strip_trailing_newlines(section)
    ---@type integer[]
    local found = {}

    for index = #section, 1, -1 do
        local line = section[index]

        if not _P.is_whitespace(line) then
            break
        end

        table.insert(found, index)
    end

    for _, index in ipairs(found) do
        section[index] = nil
    end
end

--- Remove any quotes around `text`.
---
---@param text string
---    Text that might have prefix / suffix quotes. e.g. `'foo'`.
---@return string
---    The `text` but without the quotes. Inner quotes are retained. e.g.
---    `'foo"bar'` becomes `foo"bar`.
---
function _P.strip_quotes(text)
    return (text:gsub("^['\"](.-)['\"]$", "%1"))
end

--- Remove the prefix identifier (usually `"M"`, from `"M.get_foo"`).
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---@param module_identifier string
---    If provided, any reference to this identifier (e.g. `M`) will be
---    replaced with the real import path.
---
function _P.strip_function_identifier(section, module_identifier)
    local prefix = string.format("^%s%%.", module_identifier)

    for index, line in ipairs(section) do
        line = line:gsub(prefix, "")
        section[index] = line
    end
end

--- Make a temporary Vim buffer and fill it with the data from `path`.
---
---@param path string A file on-disk to read as temporary buffer data.
---@return integer # A 1-or-more value. The created Vim buffer.
---
function _P.make_temporary_buffer(path)
    local lines = vim.fn.readfile(path)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)

    return buffer
end

--- Make sure `paths` can be processed by this script.
---
--- Raises:
---     If `paths` has unreadable paths.
---
---@param paths mega.vimdoc.AutoDocumentationEntry[]
---    The source/destination pairs to check.
---
function _P.validate_paths(paths)
    for _, entry in ipairs(paths) do
        local source = entry.source

        if vim.fn.filereadable(source) ~= 1 then
            error(string.format('Source "%s" is not readable.', vim.inspect(entry.source)))
        end
    end
end

--- Convert the files in this plug-in from Lua docstrings to Vimdoc documentation.
---
---@param paths mega.vimdoc.AutoDocumentationEntry[]
---    All of the source + destination pairs to process.
---
function M.make_documentation_files(paths)
    _P.validate_paths(paths)

    for _, entry in ipairs(paths) do
        local source = entry.source
        local destination = entry.destination

        local module_identifier = _P.get_module_identifier(source)
        local hooks = _P.get_module_enabled_hooks(module_identifier)

        doc.generate({ source }, destination, { hooks = hooks })
    end
end

return M
