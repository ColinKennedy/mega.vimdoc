--- The file that auto-creates documentation for `aggro.vimdoc`.

local success, doc = pcall(require, "mini.doc")

if not success then
    error("mini.doc is required to run aggro.vimdoc. Please clone + source https://github.com/echasnovski/mini.doc", 0)
end

local _P = {}

---@diagnostic disable-next-line: undefined-field
if _G.MiniDoc == nil then
    doc.setup()
end

local M = {}

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

--- Check if `text` is the start of a function's parameters.
---
---@param text string Some text. e.g. `"Return ~"`.
---@return boolean # If it's a section return `true`.
---
function _P.is_return_section(text)
    return text:match("%s*Return%s*~%s*")
end

--- Get the last (contiguous) key in `data` that is numbered.
---
---`data` might be a combination of number or string keys. The first key is
---expected to be numbered. If so, we get the last key that is a number.
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
---    If provided, any reference to this identifier (e.g. `M`) will be
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

    local original_signature_hook = hooks.sections["@signature"]

    hooks.sections["@signature"] = function(section)
        if module_identifier then
            _P.strip_function_identifier(section, module_identifier)
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

            if section.info.id == "@field" and _P.is_field_section(section[1]) then
                local previous_section = section.parent[section.parent_index - 1]

                if previous_section then
                    _P.set_trailing_newline(section)
                end
            end

            if section.info.id == "@param" and _P.is_parameter_section(section[1]) then
                local previous_section = section.parent[section.parent_index - 1]

                if previous_section then
                    _P.set_trailing_newline(previous_section)
                end
            end

            if section.info.id == "@return" and _P.is_return_section(section[1]) then
                local previous_section = section.parent[section.parent_index - 1]

                if previous_section then
                    _P.set_trailing_newline(section)
                end
            end
        end, block)
    end

    hooks.section_pre = function()
    end

    hooks.write_pre = function(lines)
        table.insert(lines, #lines - 1, "WARNING: This file is auto-generated. Do not edit it!")

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
        -- TODO: Add logging
        -- _LOGGER:fmt_debug('Path "%s" has no return statement.', path)
        return nil
    end

    for index=1,node.named_child do
        local child = node.named_child(index)

        if child.type == "expression_list" then
            return child
        end
    end

    -- local text = vim.treesitter.get_node_text(child, buffer)
    --
    -- TODO: Add logging here
    -- _LOGGER:fmt_debug('Bug found. Got "%s / %s" node from "%s" file but could not find an expression.', child.type, text, path)
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

function _P.get_return_node(buffer)
    local parser = vim.treesitter.get_parser(buffer, "lua")
    local tree = parser:parse()[1]
    local root = tree:root()
    local return_node = root.named_child(root.child_count)
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
---@param text string Any text, e.g. `"aggro.vimdoc.ClassName"`.
---@return string # The wrapped text, e.g. `"*aggro.vimdoc.ClassName*"`.
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
---    The real name for the module. e.g. `"aggro.vimdoc"`.
---
function _P.replace_function_name(section, module_identifier, module_name)
    local prefix = string.format("^%s%%.", module_identifier)
    local replacement = string.format("%s.", module_name)

    for index, line in ipairs(section) do
        line = line:gsub(prefix, replacement)
        section[index] = line
    end
end

--- Add newlines around `section` if needed.
---
---@param section MiniDoc.Section
---    The object to possibly modify.
---@param count integer?
---    The number of lines to put before `section` if needed. If the section
---    has more newlines than `count`, it is converted back to `count`.
---
function _P.set_trailing_newline(section, count)
    local function _is_not_whitespace(text)
        return text:match("%S+")
    end

    count = count or 1
    local found_text = false
    local lines = 0

    for _, line in ipairs(section) do
        if not found_text then
            if _is_not_whitespace(line) then
                found_text = true
            end
        elseif _is_not_whitespace(line) then
            lines = 0
        else
            lines = lines + 1
        end
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

-- TODO: Docstring
function _P.make_temporary_buffer(path)
    local lines = vim.fn.readfile(path)
    local buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
end

--- Make sure `paths` can be processed by this script.
---
---@param paths aggro.vimdoc.AutoDocumentationEntry[]
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
---@param paths aggro.vimdoc.AutoDocumentationEntry[]
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
