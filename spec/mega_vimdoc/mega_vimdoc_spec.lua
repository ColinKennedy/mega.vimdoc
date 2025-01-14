--- Make sure the base features of `mega.vimdoc` works as expected.
---
---@module 'spec.mega_vimdoc.mega_vimdoc_spec'
---

local vimdoc = require("mega.vimdoc")

local _COUNTER = 1

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


local _make_temporary_file

if vim.fn.has("win32") == 1 then
    -- NOTE: GitHub actions place temp files in a directory, C:\Users\RUNNER~1,
    -- that Vim doesn't know how to read. So we need to redirect that temporary
    -- directory that gets created.

    --- Make a file ending in `suffix`.
    ---
    ---@param suffix string An ending name / file extension. e.g. `".lua"`.
    ---@return string # The file path on-disk that Vim made.
    ---
    _make_temporary_file = function(suffix)
        -- NOTE: We need just the string for a directory name.
        local directory = os.tmpname()
        vim.fn.delete(directory)
        directory = vim.fs.joinpath(vim.fn.getcwd(), ".tmp.mega.vimdoc", vim.fs.basename(directory))

        local path = vim.fs.joinpath(directory, tostring(_COUNTER) .. suffix)
        table.insert(_DIRECTORIES_TO_DELETE, directory)
        vim.fn.mkdir(directory, "p")
        _COUNTER = _COUNTER + 1

        return path
    end
else
    --- Make a file ending in `suffix`.
    ---
    ---@param suffix string An ending name / file extension. e.g. `".lua"`.
    ---@return string # The file path on-disk that Vim made.
    ---
    _make_temporary_file = function(suffix)
        -- NOTE: We need just the string for a directory name.
        local directory = os.tmpname()
        vim.fn.delete(directory)

        local path = vim.fs.joinpath(directory, tostring(_COUNTER) .. suffix)
        table.insert(_DIRECTORIES_TO_DELETE, directory)
        vim.fn.mkdir(directory, "p")
        _COUNTER = _COUNTER + 1

        return path
    end
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
    vimdoc.make_documentation_files({ { source = source, destination = destination } })

    -- NOTE: We ignore the last few lines because they are auto-generated.
    local raw = vim.fn.readfile(destination)
    local found = vim.fn.join(_get_slice(raw, 1, math.max(#raw - 4, 1)), "\n")

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

describe("namespace replacements", function()
    before_each(_silence_mini_doc)
    after_each(_after_each)

    it("still works if the module has no `return` statement", function()
        _run_test(
            [[
--- A module.
---
---@module 'foo.bar'
---

local M = {}

--- Do something.
---
---@param value integer A thing.
---@return string # Text.
---
function M.something(value)
    return "stuff"
end
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
A module.

------------------------------------------------------------------------------
                                                                 *M.something()*

`M.something`({value})

Do something.

Parameters ~
    {value} `(integer)` A thing.

Return ~
    `(string)` Text.
]]
        )
    end)

    it("works with functions - 001", function()
        _run_test(
            [[
--- A module.
---
---@module 'foo.bar'
---

local M = {}

--- Do something.
---
---@param value integer A thing.
---@return string # Text.
---
function M.something(value)
    return "stuff"
end

return M
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
A module.

------------------------------------------------------------------------------
                                                           *foo.bar.something()*

`foo.bar.something`({value})

Do something.

Parameters ~
    {value} `(integer)` A thing.

Return ~
    `(string)` Text.
]]
        )
    end)

    it("works with functions - 002", function()
        _run_test(
            [[
--- A module.
---
---@module 'foo.bar'
---

local M = {}

--- Do something.
---@param value integer A thing.
---@return string # Text.
function M.something(value)
    return "stuff"
end

return M
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
A module.

------------------------------------------------------------------------------
                                                           *foo.bar.something()*

`foo.bar.something`({value})

Do something.

Parameters ~
    {value} `(integer)` A thing.

Return ~
    `(string)` Text.
]]
        )
    end)
end)

describe("@class", function()
    before_each(_silence_mini_doc)
    after_each(_after_each)

    it("works with metatable definitions", function()
        _run_test(
            [[
--- A module.
---
---@module 'some.thing_here'
---

---@class Parameter
---    Something class
---
M.Parameter = {
    __tostring = function(parameter)
        return string.format("Parameter({names=%s})", parameter.name)
    end,
}
M.Parameter.__index = M.Parameter

--- Create a new instance using `options`.
---
---@param options cmdparse.ParameterOptions All of the settings to include in a new parse argument.
---@return cmdparse.Parameter # The created instance.
---
function M.Parameter.new(options)
    --- @class cmdparse.Parameter
    local self = setmetatable({}, M.Parameter)

    self._action = nil
    self._action_type = nil
    self._nargs = options.nargs or 1
    self._type = options.type
    self._used = 0
    self.choices = options.choices
    self.count = options.count or 1
    self.default = options.default
    self.names = options.names
    self.help = options.help
    self.destination = text_parse.get_nice_name(options.destination or options.names[1])
    self:set_action(options.action)
    self.required = options.required
    self.value_hint = options.value_hint
    self._parent = options.parent

    return self
end

return M
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
A module.

------------------------------------------------------------------------------
                                                     *some.thing_here.Parameter*

`some.thing_here.Parameter`

*Parameter*
   Something class

------------------------------------------------------------------------------
                                               *some.thing_here.Parameter.new()*

`some.thing_here.Parameter.new`({options})

Create a new instance using `options`.

Parameters ~
    {options} cmdparse.ParameterOptions All of the settings to include in a new parse argument.

Return ~
    cmdparse.Parameter The created instance.
]]
        )
    end)

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

describe("@field", function()
    before_each(_silence_mini_doc)
    after_each(_after_each)

    it("links custom @class / @alias / @enum", function()
        _run_test(
            [[
---@class Foo
---    And some text here.
---@field bar SomeCustomType
---    More information.
---@field fizz _PrivateThing
---    Lines and lines.
---    with more lines here
---    that span extra lines.
---@field blah string
---    Stuff
---@field buzz namespaced._foo.Thing
---    Etc etc.
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
*Foo*
   And some text here.

Fields ~
    {bar} SomeCustomType
       More information.
    {fizz} _PrivateThing
       Lines and lines.
       with more lines here
       that span extra lines.
    {blah} `(string)`
       Stuff
    {buzz} namespaced._foo.Thing
       Etc etc.
]]
        )
    end)
end)

describe("@param", function()
    before_each(_silence_mini_doc)
    after_each(_after_each)

    it("links custom @class / @alias / @enum", function()
        _run_test(
            [[
--- Do something.
---
---@param value integer A thing.
---@param another CustomClass A thing.
---@param foo _PrivateCustomClass A thing.
---@param bar namespace.with._PrivateCustomClass A thing.
---@param fizz namespace.with._private_module._PrivateCustomClass A thing.
---@return string # Text.
---@return CustomClass A thing.
---@return _PrivateCustomClass # A thing.
---@return namespace.with._PrivateCustomClass # A thing.
---@return namespace.with._private_module._PrivateCustomClass # A thing.
---
function M.something(value)
    return "stuff"
end
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
                                                                 *M.something()*

`M.something`({value})

Do something.

Parameters ~
    {value} `(integer)` A thing.
    {another} CustomClass A thing.
    {foo} _PrivateCustomClass A thing.
    {bar} namespace.with._PrivateCustomClass A thing.
    {fizz} namespace.with._private_module._PrivateCustomClass A thing.

Return ~
    `(string)` Text.

Return ~
    CustomClass A thing.

Return ~
    _PrivateCustomClass A thing.

Return ~
    namespace.with._PrivateCustomClass A thing.

Return ~
    namespace.with._private_module._PrivateCustomClass A thing.
]]
        )
    end)
end)
