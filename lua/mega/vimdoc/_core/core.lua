--- The file that auto-creates documentation for `mega.vimdoc`.

local logging = require("mega.vimdoc._vendors.logging")
local minidoc = require("mega.vimdoc._vendors.mini.doc.minidoc")
local type_parse = require("mega.vimdoc._core.type_parse")

local success, doc = pcall(require, "mini.doc")

if not success then
    error("mini.doc is required to run mega.vimdoc. Please clone + source https://github.com/echasnovski/mini.doc", 0)
end

---@type mega.vimdoc.AutoDocumentationOptions
local _DEFAULT_OPTIONS = { enable_module_in_signature = true }

local _P = {}

---@diagnostic disable-next-line: undefined-field
if _G.MiniDoc == nil then
    doc.setup()
end

local _IS_WINDOWS = vim.fn.has("win32") or vim.fn.has("win64")

_P.REAL_BUILTIN_TYPES = {
    "any",
    "boolean",
    "function",
    "integer",
    "lightuserdata",
    "nil",
    "number",
    "string",
    "table",
    "thread",
    "userdata",
}

_P.BUILTIN_TYPES = vim.deepcopy(_P.REAL_BUILTIN_TYPES)
table.insert(_P.BUILTIN_TYPES, "...")

_P.BUILTIN_ARRAY_TYPES = {}

for _, name in ipairs(_P.BUILTIN_TYPES) do
    table.insert(_P.BUILTIN_ARRAY_TYPES, name .. "[]")
end

_P.TYPE_PATTERNS = {
    "table%b<>",
    "^%s*%b()",
    "fun%b():%s*%S+",
    "fun%b()",
    "^%s*%b{}",
    unpack(_P.REAL_BUILTIN_TYPES),
    "%.%.%.",
    "^%s*%b``",
}

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

--- Check if `name` is a built-in Lua type or something that a user made.
---
---@param name string The type name. e.g. `"number"`, `"something.Custom"`, etc.
---@return boolean # If `true`, it means that `name` is not built-in.
---
function _P.is_custom_type(name)
    if vim.tbl_contains(_P.BUILTIN_TYPES, name) then
        return false
    end

    if vim.tbl_contains(_P.BUILTIN_ARRAY_TYPES, name) then
        return false
    end

    return true
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

--- Find all matching `"foo.bar.fizz.buzz"` namespaces from some absolute `path`.
---
--- Assuming `package.path` is `"/root/here/foo/bar/fizz/?.lua;;"`, the return
--- would be `"buzz"`.
---
---@param path string Some Lua file. e.g. `"/root/here/foo/bar/fizz/buzz.lua"`.
---@return string[] # All found matches, if any.
---
function _P.get_lua_package_path_namespace_matches(path)
    path = vim.fs.normalize(path)
    local lua_path_separator = ";"

    ---@type string[]
    local output = {}

    for _, expression in ipairs(vim.split(package.path, lua_path_separator)) do
        -- NOTE: A typical package.path contains `"foo;;"` so `expression` may
        -- actually be an empty string. Just skip it if so.
        --
        if expression ~= "" then
            local lua_pattern = (expression:gsub("%?", "(.*)"))
            local match = path:match("^" .. lua_pattern .. "$")

            if match then
                table.insert(output, ((match:gsub("/", ".")):gsub("%.lua$", "")))
            end
        end
    end

    return output
end

--- Create the callbacks that we need to create our documentation.
---
---@param module_identifier string?
---    If provided, any reference to this identifier (e.g. `"M"`) will be
---    replaced with the real import path.
---@param module_path string?
---    The dot-separated path showing how to import the module. e.g. `"mega.vimdoc"`.
---@param options mega.vimdoc.AutoDocumentationOptions?
---    Customize the output using these settings, if needed.
---@return MiniDoc.Hooks
---    All of the generated callbacks.
---
function _P.get_module_enabled_hooks(module_identifier, module_path, options)
    local hooks = vim.deepcopy(doc.default_hooks)

    local seen_tags = {}

    hooks.sections["@class"] = function(section)
        if #section == 0 or section.type ~= "section" then
            return
        end

        local class_name = section[1]

        if vim.tbl_contains(seen_tags, class_name) then
            section:clear_lines()

            return
        end

        table.insert(seen_tags, class_name)

        section[1] = _P.add_tag(class_name)
    end

    hooks.sections["@field"] = function(section)
        if vim.tbl_isempty(section) then
            return
        end

        minidoc.mark_optional(section)
        minidoc.enclose_var_name(section)

        section[1] = _P.enclose_custom_types_for_line(section[1], _P.get_named_type_identifiers(section[1]))

        for index, line in ipairs(section) do
            section[index] = _P.indent(line)
        end
    end

    hooks.sections["@meta"] = function(section)
        module_path = section[1]

        section:clear_lines()
    end

    hooks.sections["@param"] = function(section)
        if vim.tbl_isempty(section) then
            return
        end

        minidoc.mark_optional(section)
        minidoc.enclose_var_name(section)

        section[1] = _P.enclose_custom_types_for_line(section[1], _P.get_named_type_identifiers(section[1]))

        for index, line in ipairs(section) do
            section[index] = _P.indent(line)
        end
    end

    -- NOTE: The mini.doc has no indentation by default. Add it.
    hooks.sections["@return"] = function(section)
        if vim.tbl_isempty(section) then
            return
        end

        section[1] = _P.enclose_custom_types_for_line(section[1], _P.get_return_type_identifiers(section[1]))

        minidoc.mark_optional(section)
        minidoc.add_section_heading(section, "Return")

        for index = 2, #section do
            local line = section[index]

            if not _P.has_indent(line) then
                section[index] = _P.indent(line)
            end
        end
    end

    local original_signature_hook = hooks.sections["@signature"]

    hooks.sections["@signature"] = function(section)
        if module_identifier then
            if not options or options.enable_module_in_signature then
                _P.replace_function_name(section, module_identifier, module_path)
            else
                _P.replace_function_name(section, module_identifier, "")
            end
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
        if module_identifier and module_path then
            _P.replace_function_name(section, module_identifier, module_path)
        end

        local tag_name = section[1]

        if vim.tbl_contains(seen_tags, tag_name) then
            return
        end

        table.insert(seen_tags, tag_name)

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

    local original_section_pre_hook = hooks.section_pre

    hooks.section_pre = function(section)
        original_section_pre_hook(section)

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

--- Find the dot-separated way to import and use `path`.
---
---@param path string
---    An absolute path to a .lua file. e.g. `"/root/here/mega/vimdoc/init.lua"`.
---@return string?
---    The dot-separated path showing how to import the module. e.g. `"mega.vimdoc"`.
---
function _P.get_module_namespace(path)
    path = vim.fs.normalize(path)
    ---@type string[]
    local namespaces = {}

    vim.list_extend(namespaces, _P.get_vim_runtime_namespace_matches(path))
    vim.list_extend(namespaces, _P.get_lua_package_path_namespace_matches(path))

    if vim.tbl_isempty(namespaces) then
        _LOGGER:fmt_error('No namespace was found for "%s" path.', path)

        return nil
    end

    if #namespaces == 1 then
        local namespace = namespaces[1]
        _LOGGER:fmt_info('Found "%s" namespace.', namespace)

        return namespace
    end

    table.sort(namespaces, function(left, right)
        return #left > #right and left > right
    end)
    _LOGGER:fmt_warning(
        'Found multiple possible namespaces "%s". ' .. "We will now choose the longest possible match.",
        namespaces
    )

    return namespaces[1]
end

--- Find the types from a `name-type_name[-description]` style of string.
---
--- e.g. `"variable_name string"` or `"variable_name string Some description"`.
---
---@param text string
---    The raw Lua docstring text to parse.
---@return string[]
---    The found type names, if any. Important: We sort it in descending order
---    to make other functions that use this data more efficient and accurate.
---
function _P.get_named_type_identifiers(text)
    local names = _P.get_type_names_from_lua_docstring(text, { name = true })
    table.sort(names, function(left, right)
        return left > right
    end)

    return names
end

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

--- Find the types from a `type_name[-description]` style of string.
---
--- e.g. `"string"` or `"string # Some description"`.
---
---@param text string
---    The raw Lua docstring text to parse.
---@return string[]
---    The found type names, if any. Important: We sort it in descending order
---    to make other functions that use this data more efficient and accurate.
---
function _P.get_return_type_identifiers(text)
    local names = _P.get_type_names_from_lua_docstring(text, { name = false })
    table.sort(names, function(left, right)
        return left > right
    end)

    return names
end

--- Search all Vim plugins for importablue Lua files that match `path`.
---
---@param path string
---    An absolute path to a .lua file.
---    e.g. `"/root/plugins/mega.vimdoc/lua/mega/vimdoc/init.lua"`.
---@return string[]
---    All found matches. e.g. `"mega.vimdoc"`.
---
function _P.get_vim_runtime_namespace_matches(path)
    ---@type string[]
    local output = {}

    for _, root in ipairs(vim.api.nvim_list_runtime_paths()) do
        local relative = _P.relpath(root, path)

        if relative and vim.startswith(relative, "lua/") then
            local inner_path = relative:sub(5, #relative)
            table.insert(output, _P.to_lua_namespace(inner_path))
        end
    end

    return output
end

--- Find all types (non-user-variable names) to consider for the documentation.
---
---@param summary string
---    A first line text (which will later auto-create into documentation).
---@param options {name: boolean}?
---    Extra settings that control the function's logic. e.g. `name=true` will
---    assume that the first word in `summary` is not a type but a variable
---    name and the second word is the type, instead `name=false`, which
---    assumes the first word is a type.
---@return string[]
---    All replaceable text that we need to surround with (), ``s, etc.
---
function _P.get_type_names_from_lua_docstring(summary, options)
    options = vim.tbl_deep_extend("force", { name = true }, options or {})

    local type_start

    if options.name then
        local _, space_end = summary:find("%s+")

        if not space_end then
            -- NOTE: This happens if the user provides a variable name but not
            -- a type. Just ignore this case.
            --
            return {}
        end

        type_start = space_end
    else
        type_start = 0
    end

    local type_end = _P.find_type_end(summary:sub(type_start + 1, #summary))
    local type_text = summary:sub(type_start + 1, type_end + type_start)

    return type_parse.get_type_names(type_text)
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

--- Wrap all type names found in `section` with || or ()s.
---
---@param section MiniDoc.Section A renderable blob of documentation text.
---
function _P.enclose_custom_types(section)
    for index = 1, #section do
        section[index] = _P.enclose_custom_types_for_line(section[index])
    end
end

--- Add wrap markers around summary `text`.
---
---@param text string
---    Either a name, name + type, and/or description. e.g. `"variable_name"`,
---    `"some_variable_name string"`, `"string # some description."` or
---    something else. It is assumed that `text` has at least one type that
---    will need marker(s) applied.
---@return string
---    The modified `text`.
---
function _P.enclose_custom_types_for_line(text, names)
    for _, name in ipairs(names) do
        local escaped_name = vim.pesc(name)
        local template = "`(%s)`"

        if _P.is_custom_type(name) then
            template = "|%s|"
        end

        text = text:gsub(escaped_name, string.format(template, name))
    end

    return text
end

--- Wrap the user-provided variable identifier in {}s.
---
---@param section MiniDoc.Section A renderable blob of documentation text.
---
function _P.enclose_variable_name(section)
    if #section == 0 or section.type ~= "section" then
        return
    end

    section[1] = section[1]:gsub("(%S+)", "{%1}", 1)
end

--- Find the last index `text` that represents the end of some type.
---
--- It's assumed that text's first character is a type and after the index is
--- found there is non-text data (such as a descriptino or some other non-type
--- data).
---
---@param text string A type + maybe some description. e.g. `"string Some description"`.
---@return integer # A 1-or-more value indicating the point where the type stops.
---
function _P.find_type_end(text)
    local function _get_longest_type_match(sub_text, start_absolute_index)
        local indices = vim.tbl_map(function(pattern)
            local start_, end_ = sub_text:find(pattern)

            if not start_ or not end_ then
                return math.huge
            end

            return start_absolute_index + end_
        end, _P.TYPE_PATTERNS)

        local result = vim.fn.reduce(indices, function(accumulator, current)
            if accumulator == math.huge then
                accumulator = 0
            end

            if not current then
                return accumulator
            end

            if not accumulator or (current ~= math.huge and current > accumulator) then
                accumulator = current
            end

            return accumulator
        end)

        return result
    end

    local function _get_next_index(text_, start_index)
        local found_start_index, _ = text_:find("%s*" .. vim.pesc("|") .. "%s*", start_index)

        return found_start_index
    end

    local start_absolute_index = 1
    local text_count = #text

    while true do
        local sub_text = text:sub(start_absolute_index, text_count)
        local result = _get_longest_type_match(sub_text, start_absolute_index)

        if result == math.huge or result == 0 then
            local next_relative_index = _get_next_index(sub_text, result)

            if next_relative_index then
                start_absolute_index = start_absolute_index + next_relative_index
            else
                local next_space = string.find(sub_text, " ")

                if not next_space then
                    return text_count
                end

                return start_absolute_index + next_space - 1
            end
        end

        local next_relative_index = _get_next_index(sub_text, result)

        if not next_relative_index then
            return result
        end

        start_absolute_index = start_absolute_index + next_relative_index
    end
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

-- TODO: relpath is only available in Vim 0.11+.
-- Remove this block once we drop 0.10 support
--
if vim.fs.relpath then
    _P.relpath = vim.fs.relpath
else
    --- Gets `target` path relative to `base`, or `nil` if `base` is not an ancestor.
    ---
    --- Example:
    ---
    --- ```lua
    --- vim.fs.relpath('/var', '/var/lib') -- 'lib'
    --- vim.fs.relpath('/var', '/usr/bin') -- nil
    --- ```
    ---
    --- @param base string
    --- @param target string
    --- @return string|nil
    function _P.relpath(base, target)
        base = vim.fs.normalize(vim.fn.fnamemodify(base, ":p"))
        target = vim.fs.normalize(vim.fn.fnamemodify(target, ":p"))
        if base == target then
            return "."
        end

        local prefix = ""
        if _IS_WINDOWS then
            prefix, base = _P.split_windows_path(base)
        end
        base = prefix .. base .. (base ~= "/" and "/" or "")

        return vim.startswith(target, base) and target:sub(#base + 1) or nil
    end
end

--- Change the function name in `section` from `module_identifier` to `module_path`.
---
---@param section MiniDoc.Section
---    A renderable blob of text (which will later auto-create into documentation).
---    We assume this `section` represents a Lua function.
---@param module_identifier string
---    Usually a function in Lua is defined with `function M.foo`. In this
---    example, `module_identifier` would be the `M` part.
---@param module_path string?
---    The dot-separated path showing how to import the module. e.g. `"mega.vimdoc"`.
---
function _P.replace_function_name(section, module_identifier, module_path)
    if not vim.endswith(module_identifier, ".") then
        module_identifier = module_identifier .. vim.pesc(".")
    end

    local prefix = string.format("^%s", module_identifier)
    local replacement = ""

    if module_path and module_path ~= "" then
        replacement = string.format("%s.", module_path)
    end

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

-- TODO: relpath is only available in Vim 0.11+.
-- Remove this function once we drop Vim 0.10.
--
--- Split a Windows path into a prefix and a body, such that the body can be processed like a POSIX
--- path. The path must use forward slashes as path separator.
---
--- Does not check if the path is a valid Windows path. Invalid paths will give invalid results.
---
--- Examples:
--- - `//./C:/foo/bar` -> `//./C:`, `/foo/bar`
--- - `//?/UNC/server/share/foo/bar` -> `//?/UNC/server/share`, `/foo/bar`
--- - `//./system07/C$/foo/bar` -> `//./system07`, `/C$/foo/bar`
--- - `C:/foo/bar` -> `C:`, `/foo/bar`
--- - `C:foo/bar` -> `C:`, `foo/bar`
---
--- @param path string Path to split.
--- @return string, string, boolean : prefix, body, whether path is invalid.
function _P.split_windows_path(path)
    local prefix = ""

    --- Match pattern. If there is a match, move the matched pattern from the path to the prefix.
    --- Returns the matched pattern.
    ---
    --- @param pattern string Pattern to match.
    --- @return string|nil Matched pattern
    local function match_to_prefix(pattern)
        local match = path:match(pattern)

        if match then
            prefix = prefix .. match --[[ @as string ]]
            path = path:sub(#match + 1)
        end

        return match
    end

    local function process_unc_path()
        return match_to_prefix("[^/]+/+[^/]+/+")
    end

    if match_to_prefix("^//[?.]/") then
        -- Device paths
        local device = match_to_prefix("[^/]+/+")

        -- Return early if device pattern doesn't match, or if device is UNC and it's not a valid path
        if not device or (device:match("^UNC/+$") and not process_unc_path()) then
            return prefix, path, false
        end
    elseif match_to_prefix("^//") then
        -- Process UNC path, return early if it's invalid
        if not process_unc_path() then
            return prefix, path, false
        end
    elseif path:match("^%w:") then
        -- Drive paths
        prefix, path = path:sub(1, 2), path:sub(3)
    end

    -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
    -- ensure that the body is treated as an absolute path. For paths like C:foo/bar, there are no
    -- slashes at the end of the prefix, so it will be treated as a relative path, as it should be.
    local trailing_slash = prefix:match("/+$")

    if trailing_slash then
        prefix = prefix:sub(1, -1 - #trailing_slash)
        path = trailing_slash .. path --[[ @as string ]]
    end

    return prefix, path, true
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

--- Replace a relative path like `"foo/bar/thing.lua"` to `"foo.bar.thing"`.
---
---@param text string Some relaive path on-disk.
---@return string # The converted namespace that can be `require("foo.bar.thing")`.
---
function _P.to_lua_namespace(text)
    local lua_reserved_module_name = "init.lua"

    if vim.endswith(text, lua_reserved_module_name) then
        text = text:sub(1, #text - #lua_reserved_module_name - 1)
    end

    return (text:gsub("/", "."):gsub("%.lua$", ""))
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
---@param options mega.vimdoc.AutoDocumentationOptions?
---    Customize the output using these settings, if needed.
---
function M.make_documentation_files(paths, options)
    options = vim.tbl_deep_extend("force", _DEFAULT_OPTIONS, options or {})
    _P.validate_paths(paths)

    for _, entry in ipairs(paths) do
        local source = entry.source
        local destination = entry.destination

        local module_identifier = _P.get_module_identifier(source)
        local module_path = _P.get_module_namespace(source)
        local hooks = _P.get_module_enabled_hooks(module_identifier, module_path, options)

        doc.generate({ source }, destination, { hooks = hooks })
    end
end

return M
