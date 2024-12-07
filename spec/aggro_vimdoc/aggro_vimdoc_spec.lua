--- Make sure the base features of `aggro.vimdoc` works as expected.
---
---@module 'spec.aggro_vimdoc.aggro_vimdoc_spec'
---

local vimdoc = require("aggro.vimdoc")

--- Read text from file on-disk, `path`.
---
---@param path string An absolute path on-disk to read.
---@return string # The found text.
---
local function _get_text(path)
    return vim.fn.join(vim.fn.readfile(path), "\n")
end

--- Make a file ending in `suffix`.
---
---@param suffix string An ending name / file extension. e.g. `".lua"`.
---@return string # The file path on-disk that Vim made.
---
local function _make_temporary_file(suffix)
    local path = vim.fn.tempname() .. suffix
    vim.fn.mkdir(vim.fs.dirname(path), "p")

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

    local found = _get_text(destination)

    assert.equal(expected, found)
end

--- TODO: write this
---
--- - Internal linking for @param
---     - Custom types, too
--- - Classes (metatables)
---
---

describe("@class", function()
    it("works with a contiguous @class definition - 001 - No descriptions", function()
        _run_test(
            [[
            ---@class Foo
            ---@field bar string
            ---@field fizz number
            ---@field buzz integer
            ]],
            [[
            asdfasdfasfdasdf
            ]]
        )
    end)
end)
