--- Parse Lua docstrings for types.

local _P = {}
local M = {}

--- Find all types within `text`.
---
---@param text string The blob of, we assume, a single Lua type to look for sub-types.
---@return string[] # All found types, if any.
---
function _P.get_inner_types(text)
    local function _is_variable(text_, start_index)
        return (text_:sub(start_index, #text_)):match("^%s*:")
    end

    text = _P.strip_nested_types(text)
    text = _P.strip_sparse_types(text)

    ---@type string[]
    local output = {}

    local start = 1

    while true do
        local start_index, end_index = text:find("[%w%._]+", start)

        if start_index and end_index then
            if not _is_variable(text, end_index + 1) then
                local match = text:sub(start_index, end_index)
                table.insert(output, match)
            end

            start = end_index + 1
        else
            break
        end
    end

    return output
end

--- Create a function that recursively finds inner pairs of characters.
---
---@param template string
---    Some regex pairs pattern. e.g. `"%b<>"` will find all text within <>s.
---@return fun(text: string): table<string, string[]>
---    Every top-level match + its children, recursively.
---
function _P.extract(template)
    return function(str)
        ---@type table<string, string[]>
        local results = {}
        ---@type string?
        local current_group
        ---@type integer?
        local current_end_index

        local function find_parentheses(sub_str, start_pos)
            local start_index, end_index = sub_str:find(template, start_pos)

            if start_index then
                local match = sub_str:sub(start_index + 1, end_index - 1) -- Exclude outer parentheses
                if not current_group or start_index > current_end_index then
                    current_group = match
                    current_end_index = end_index
                end

                -- NOTE: Recursively find inner matches first
                find_parentheses(match, 1)

                results[current_group] = results[current_group] or {}
                table.insert(results[current_group], match)

                find_parentheses(sub_str, end_index + 1)
            end
        end

        find_parentheses(str, 1)

        return results
    end
end

_P.extract_angle_brackets = _P.extract("%b<>")

_P.extract_parentheses = _P.extract("%b()")

_P.extract_square_braces = _P.extract("%b[]")

--- Delete the contents of any part of `text` that could contain sub-types.
---
---@param text string
---    Some full Lua type to start stripping.
---@return string
---    A partially-stripped type. Types like `fun(foo: bar)` are returned as `fun()`.
---
function _P.strip_nested_types(text)
    repeat
        local before = text
        text = text:gsub("%b()", "()")
        text = text:gsub("%b<>", "<>")
        text = text:gsub('%b""', '""')
        text = text:gsub("%b``", "``")
    until text == before

    return text
end

--- Remove any partially-removed types completely.
---
---@param text string
---    A pseudo-Lua type that has already been partially stripped.
---    e.g. `"foo | fun(): blah | table<> | thing".`
---@return string
---    The stripped result. e.g. `"foo | blah | | thing".`
---
function _P.strip_sparse_types(text)
    text = text:gsub(vim.pesc("table<>"), "")
    text = text:gsub(vim.pesc("fun():"), "")
    text = text:gsub(vim.pesc("fun()"), "")

    return text
end

--- Parse Lua docstrings for types.
---
--- We try our best to avoid accidentally typing variable names. For example
--- fun(foo: bar): fizz would skip `foo` but would type `bar` and `fizz`.
---
---@param text string Any expected Lua type. e.g. `"string | another | some.Class"`.
---@return string[] # All type names, if any.
---
function M.get_type_names(text)
    local function _extend_with_children(container, data)
        for _, children in pairs(data) do
            for _, child in ipairs(children) do
                vim.list_extend(container, _P.get_inner_types(child))
            end
        end
    end

    ---@type string[]
    local all_types = {}

    _extend_with_children(all_types, _P.extract_parentheses(text))
    _extend_with_children(all_types, _P.extract_angle_brackets(text))
    _extend_with_children(all_types, _P.extract_square_braces(text))

    vim.list_extend(all_types, _P.get_inner_types(text))

    -- NOTE: The type annotation from Neovim is wrong. Just ignore it.
    ---@diagnostic disable-next-line: return-type-mismatch
    return vim.fn.uniq(vim.fn.sort(all_types))
end

return M
