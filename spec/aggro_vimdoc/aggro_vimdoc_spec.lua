--- Make sure the base features of `aggro.vimdoc` works as expected.
---
---@module 'spec.aggro_vimdoc.aggro_vimdoc_spec'
---

local vimdoc = require("aggro.vimdoc")

---@type string[]
local _DIRECTORIES_TO_DELETE = {}

local _ORIGINAL_VIM_NOTIFY = vim.notify

--- Get a sub-section copy of `table_` as a new table.
---
---@param table_ table<any, any>
---    A list / array / dictionary / sequence to copy + reduce.
---@param first? number
---    The start index to use. This value is **inclusive** (the given index
---    will be returned). Uses `table_`'s first index if not provided.
---@param last? number
---    The end index to use. This value is **inclusive** (the given index will
---    be returned). Uses every index to the end of `table_`' if not provided.
---@param step? number
---    The step size between elements in the slice. Defaults to 1 if not provided.
---@return table<any, any>
---    The subset of `table_`.
---
local function _get_slice(table_, first, last, step)
    local sliced = {}

    for i = first or 1, last or #table_, step or 1 do
        sliced[#sliced + 1] = table_[i]
    end

    return sliced
end

--- Stop mini.doc from printing during unittests.
local function _silence_mini_doc()
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function() end
end

--- Revert any mocks before unittests were ran.
local function _reset_mini_doc()
    vim.notify = _ORIGINAL_VIM_NOTIFY
end

--- Make a file ending in `suffix`.
---
---@param suffix string An ending name / file extension. e.g. `".lua"`.
---@return string # The file path on-disk that Vim made.
---
local function _make_temporary_file(suffix)
    local path = vim.fn.tempname() .. suffix
    local directory = vim.fs.dirname(path)
    table.insert(_DIRECTORIES_TO_DELETE, directory)
    vim.fn.mkdir(directory, "p")

    return path
end

--- Fill a file with `source_text`, make documentation, and check it against `expected`.
---
--- Raises:
---     If the generated Vimdoc does not match `expected`.
---
---@param source_text string The raw Lua source code (including docstring text).
---@param expected string The Vimdoc that we think `source_text` should create.
---
local function _run_test(source_text, expected)
    local source = _make_temporary_file(".lua")
    local destination = _make_temporary_file(".txt")

    vim.fn.writefile(vim.fn.split(source_text, "\n"), source)
    vimdoc.make_documentation_files({{source=source, destination=destination}})

    -- NOTE: We ignore the last few lines because they are auto-generated.
    local raw = vim.fn.readfile(destination)
    local found = vim.fn.join(_get_slice(raw, 1, math.max(#raw - 3, 1)), "\n")

    assert.equal(expected, found)
end

--- Reset all dependencies and clean up and temporary files / directories.
local function _after_each()
    _reset_mini_doc()

    for _, directory in ipairs(_DIRECTORIES_TO_DELETE) do
        vim.fn.delete(directory, "rf")
    end

    _DIRECTORIES_TO_DELETE = {}
end

describe("@class", function()
    before_each(_silence_mini_doc)
    after_each(_after_each)

    it("works with a contiguous @class definition - 001 - no descriptions", function()
        _run_test(
            [[
---@class Foo
---@field bar string
---@field fizz number
---@field buzz integer
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
*Foo*

Fields ~
    {bar} `(string)`
    {fizz} `(number)`
    {buzz} `(integer)`
]]
        )
    end)

    it("works with a contiguous @class definition - 002 - with descriptions", function()
        _run_test(
            [[
---@class Foo
---    And some text here.
---@field bar string
---    More information.
---@field fizz number
---    Lines and lines.
---    with more lines here
---    that span extra lines.
---@field buzz integer
---    Etc etc.
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
*Foo*
   And some text here.

Fields ~
    {bar} `(string)`
       More information.
    {fizz} `(number)`
       Lines and lines.
       with more lines here
       that span extra lines.
    {buzz} `(integer)`
       Etc etc.
]]
        )
    end)
end)
