--- Make sure the base features of `mega.vimdoc` works as expected.

local common = require("test_utilities.common")
local logging = require("mega.vimdoc._vendors.logging")
local vimdoc = require("mega.vimdoc")

--- Create the directory just above `path`.
---
---@param path string An absolute path that doesn't exist on-disk.
---
local function _make_parent_directory(path)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
end

--- Fill a file with `source_text`, make documentation, and check it against `expected`.
---
--- Raises:
---     If the generated Vimdoc does not match `expected`.
---
---@param source_text string
---    The raw Lua source code (including docstring text).
---@param expected string
---    The Vimdoc that we think `source_text` should create.
---@param options mega.vimdoc.AutoDocumentationOptions?
---    Customize the output using these settings, if needed.
---
local function _run_test(source_text, expected, options)
    local source = common.make_temporary_path(".lua")
    local destination = common.make_temporary_path(".txt")
    _make_parent_directory(source)
    _make_parent_directory(destination)

    vim.fn.writefile(vim.fn.split(source_text, "\n"), source)
    vimdoc.make_documentation_files({ { source = source, destination = destination } }, options)

    -- NOTE: We ignore the last few lines because they are auto-generated.
    local raw = vim.fn.readfile(destination)
    local found = vim.fn.join(common.get_slice(raw, 1, math.max(#raw - 4, 1)), "\n")

    assert.equal(expected, found)
end

--- Reset all dependencies and clean up and temporary files / directories.
local function _after_each()
    common.reset_mini_doc()
    common.delete_temporary_data()
end

before_each(function()
    logging.set_configuration(nil, { use_console = false })
    common.silence_mini_doc()
end)

after_each(_after_each)

describe("general", function()
    it("hides private functions by default #simple", function()
        _run_test(
            [[
--- A module.
---
---@meta foo.bar
---

local M = {}
local _P = {}

---@return string # This function does things
---@private
function _P.another_function()
    return "asdfsafd"
end

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

    it("hides private functions by default if they are not return-ed", function()
        _run_test(
            [[
local _P = {}
local M = {}

---@class FooThing
---    I am a Foo description.
M.Foo = {}

---@class BarThing
---    I am a Bar description.
_P.Bar = {}

---@return integer # Blah.
function _P.bar()
end

---@return integer # Blah.
local function thing()
end

---@return integer # Blah.
function M.foo()
end

---@return integer # Blah.
---@private
function M.another()
end

return M
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
                                                                         *M.Foo*

`Foo`

*FooThing*
   I am a Foo description.

------------------------------------------------------------------------------
                                                                       *M.foo()*

`foo`()


Return ~
    `(integer)` Blah.
]]
        )
    end)

    it("hides the module name from the signature if disabled", function()
        _run_test(
            [[
--- A module.
---
---@meta foo.bar
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

`something`({value})

Do something.

Parameters ~
    {value} `(integer)` A thing.

Return ~
    `(string)` Text.
]],
            { enable_module_in_signature = false }
        )
    end)
end)

describe("namespace replacements", function()
    it("still works if the module has no `return` statement", function()
        _run_test(
            [[
--- A module.
---
---@meta foo.bar
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
---@meta foo.bar
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
---@meta foo.bar
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
    it("works with base class inheritance #current", function()
        _run_test(
            [[
---@class Foo : SomeOtherBaseClass
---    I am a Foo class!
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
*Foo*
   I am a Foo class!
]]
        )
    end)

    it("works with metatable definitions", function()
        _run_test(
            [[
--- A module.
---
---@meta some.thing_here
---

---@class cmdparse.Parameter
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
    ---@class cmdparse.Parameter
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

*cmdparse.Parameter*
   Something class

------------------------------------------------------------------------------
                                               *some.thing_here.Parameter.new()*

`some.thing_here.Parameter.new`({options})

Create a new instance using `options`.

Parameters ~
    {options} |cmdparse.ParameterOptions| All of the settings to include in a new parse argument.

Return ~
    |cmdparse.Parameter| The created instance.
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
    {bar} |SomeCustomType|
       More information.
    {fizz} |_PrivateThing|
       Lines and lines.
       with more lines here
       that span extra lines.
    {blah} `(string)`
       Stuff
    {buzz} |namespaced._foo.Thing|
       Etc etc.
]]
        )
    end)
end)

describe("@param", function()
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
    {another} |CustomClass| A thing.
    {foo} |_PrivateCustomClass| A thing.
    {bar} |namespace.with._PrivateCustomClass| A thing.
    {fizz} |namespace.with._private_module._PrivateCustomClass| A thing.

Return ~
    `(string)` Text.

Return ~
    |CustomClass| A thing.

Return ~
    |_PrivateCustomClass| A thing.

Return ~
    |namespace.with._PrivateCustomClass| A thing.

Return ~
    |namespace.with._private_module._PrivateCustomClass| A thing.
]]
        )
    end)
end)

describe("bug fix", function()
    describe("@alias", function()
        it("works with complex, partial aliases - 001", function()
            _run_test(
                [[
---@alias Foo table<string, FooBar>

---@class Thing
---@field blah3 fun(value: table<string, FooBar>) | table<string, FooBar>
---    Another replaced
                ]],
                [[
==============================================================================
------------------------------------------------------------------------------
*Thing*

Fields ~
    {blah3} fun(value: table<`(string)`, |FooBar|>) | table<`(string)`, |FooBar|>
       Another replaced
]]
            )
        end)

        it("works with complex, partial aliases - 002", function()
            _run_test(
                [[
---@alias Foo table<string, FooBar>

---@class FooBar
---    Something
---@field blah1 string
---    Another

---@class Thing
---    Something replaced
---@field blah2 Foo
---    Another replaced
---@field blah3 fun(value: Foo) | Foo
---    Another replaced
                ]],
                [[
==============================================================================
------------------------------------------------------------------------------
*FooBar*
   Something

Fields ~
    {blah1} `(string)`
       Another

------------------------------------------------------------------------------
*Thing*
   Something replaced

Fields ~
    {blah2} table<`(string)`, |FooBar|>
       Another replaced
    {blah3} fun(value: table<`(string)`, |FooBar|>) | table<`(string)`, |FooBar|>
       Another replaced
]]
            )
        end)

        it("works with complex, partial aliases", function()
            _run_test(
                [[
---@alias some._Level "trace" | "debug" | "info" | "warn" | "error" | "fatal"

---@class some._LevelThing
---@field blah_blah some._Level Some description
---@field infix some._LevelInner Another description
---@field blah_optional some._Level? Last description
---@field prefix some.Some_Level Another description
                ]],
                [[
==============================================================================
------------------------------------------------------------------------------
*some._LevelThing*

Fields ~
    {blah_blah} "trace" | "debug" | "info" | "warn" | "error" | "fatal" Some description
    {infix} |some._LevelInner| Another description
    {blah_optional} ("trace" | "debug" | "info" | "warn" | "error" | "fatal")? Last description
    {prefix} |some.Some_Level| Another description
]]
            )
        end)
    end)

    it("works with the logging module #simple", function()
        _run_test(
            [[
--- A generalized logging for Lua. It's similar to Python's built-in logger.
---
---@meta mega.logging
---

---@alias some._Level "trace" | "debug" | "info" | "warn" | "error" | "fatal"

---@class mega.logging.SparseLoggerOptions
---    All of the customizations a person can make to a logger instance.
---@field float_precision number?
---    A positive value (max of 1) to indicate the rounding precision. e.g.
---    0.01 rounds to every hundredths.
---@field level some._Level?
---    The minimum severity needed for this logger instance to output a log.
---@field name string?
---    An identifier for this logger.
---@field output_path string?
---    A path on-disk where logs are written to, if any.
---@field use_console boolean?
---    If `true`, logs are printed to the terminal / console.
---@field use_file boolean?
---    If `true`, logs are written to `output_path`.
---@field use_highlights boolean?
---    If `true`, logs are colorful. If `false`, they're mono-colored text.
---@field use_neovim_commands boolean?
---    If `true`, allow logs to submit as Neovim commands. If `false`, only
---    built-in Lua commands will be used. This is useful if you want to log
---    within a libuv thread and don't want to call `vim.schedule()`.

---@class mega.logging.LoggerOptions
---    All of the customizations a person can make to a logger instance.
---@field float_precision number
---    A positive value (max of 1) to indicate the rounding precision. e.g.
---    0.01 rounds to every hundredths.
---@field level some._Level
---    The minimum severity needed for this logger instance to output a log.
---@field name string
---    An identifier for this logger.
---@field output_path string
---    A path on-disk where logs are written to, if any.
---@field use_console boolean
---    If `true`, logs are printed to the terminal / console.
---@field use_file boolean
---    If `true`, logs are written to `output_path`.
---@field use_highlights boolean
---    If `true`, logs are colorful. If `false`, they're mono-colored text.
---@field use_neovim_commands boolean
---    If `true`, allow logs to submit as Neovim commands. If `false`, only
---    built-in Lua commands will be used. This is useful if you want to log
---    within a libuv thread and don't want to call `vim.schedule()`.

---@class mega.logging._LevelMode
---    Data related to `level` to consider.
---@field highlight string
---    The Neovim highlight group name used to colorize the logs.
---@field level string
---    The associated level for this object.
---@field name string
---    The name of the level, e.g. `"info"`.
---@private

local _P = {}
local M = {}

local _LOGGER_HIERARCHY_SEPARATOR = "."
local _LEVELS = { trace = 10, debug = 20, info = 30, warn = 40, error = 50, fatal = 60 }

---@type table<string, mega.logging.SparseLoggerOptions>
---@private
local _OPTIONS = {}

--- Suggest a default level for all loggers.
---
--- Raises:
---     If `$LOG_LEVEL` is set but it is empty or a non-number.
---
---@param default number The 1-or-more level to use for all loggers.
---@return number # The found suggestion.
---@private
---
function _P.get_initial_default_level(default)
    local level_text = os.getenv("LOG_LEVEL")

    if not level_text then
        return default
    end

    local level = tonumber(level_text)

    if level then
        return level
    end

    error(string.format('LOG_LEVEL "%s" must be a number.', level_text), 0)
end

local _MODES = {
    debug = { name = "debug", highlight = "Comment" },
    error = { name = "error", highlight = "ErrorMsg" },
    fatal = { name = "fatal", highlight = "ErrorMsg" },
    info = { name = "info", highlight = "None" },
    trace = { name = "trace", highlight = "Comment" },
    warning = { name = "warning", highlight = "WarningMsg" },
}

M._DEFAULTS = {
    float_precision = 0.01,
    highlights = true,
    level = _P.get_initial_default_level(_LEVELS.info),
    output_path = nil,
    use_console = true,
    use_file = true,
    use_highlights = true,
    use_neovim_commands = true,
}

local _ROOT_NAME = "__ROOT__"

---@private
---@type table<string, mega.logging.Logger>
M._LOGGERS = {}

---@class mega.logging.Logger
M.Logger = {
    __tostring = function(logger)
        return string.format("mega.logging.Logger({names=%s})", vim.inspect(logger.name))
    end,
}
M.Logger.__index = M.Logger

-- TODO: Replace the timing function that rounds precision with this rounder, instead.
--- Approximate (round) `value` according to `increment`.
---
---@param value number
---    Some float to round / crop.
---@param increment number
---    A positive value (max of 1) to indicate the rounding precision. e.g.
---    0.01 rounds to every hundredths.
---@return number
---    The founded value.
---@private
---
function _P.round(value, increment)
    increment = increment or 1
    value = value / increment

    return (value > 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)) * increment
end

--- Add `data` to this logger instance's description.
---
---@param options mega.logging.SparseLoggerOptions The logger to create.
---@private
---
function M.Logger:_apply_parent_configuration(options)
    self._sparse_options = _OPTIONS[self.name] or self._sparse_options
    local full_options = vim.tbl_deep_extend("force", options, self._sparse_options)

    self.level = full_options.level
    self.use_file = full_options.use_file
    self.use_highlights = full_options.use_highlights
    self.use_neovim_commands = full_options.use_neovim_commands

    self._float_precision = full_options.float_precision
    self._use_console = full_options.use_console
    ---@type string?
    self._output_path = full_options.output_path

    if not self._output_path and self.use_neovim_commands then
        self._output_path = vim.fs.joinpath(vim.api.nvim_call_function("stdpath", { "data" }), "default.log")
    end
end

--- Format a template string and log it according to `level` and `mode`.
---
---@param level number
---    The level for the log (debug, info, etc).
---@param mode mega.logging._LevelMode
---    Data related to `level` to consider.
---@param ... any
---    Arguments to pass to `message_maker`. It's expected that the first
---    argument is a template like `"some thing to %s replace %d here"`, and
---    then the next arguments might be `"asdf"` and `8`, to fill in the template.
---@private
---
function M.Logger:_format_and_log_at_level(level, mode, ...)
    local passed = { ... }

    return self:_log_at_level(level, mode, function()
        local template = table.remove(passed, 1)
        local inspected = {}

        for _, value in ipairs(passed) do
            if type(value) == "string" then
                table.insert(inspected, value)
            else
                table.insert(inspected, vim.inspect(value))
            end
        end

        return string.format(template, unpack(inspected))
    end)
end

--- Decide whether or not to log and how.
---
---@param level number The level for the log (debug, info, etc).
---@param mode mega.logging._LevelMode Data related to `level` to consider.
---@param message_maker fun(...: any): string The function that, when called, creates a log message.
---@param ... any Arguments to pass to `message_maker`.
---@private
---
function M.Logger:_log_at_level(level, mode, message_maker, ...)
end

--- Serialize log arguments into strings and merge them into a single log message.
---
---@param ... any The arguments to consider.
---@return string # The genreated message.
---@private
---
function M.Logger:_make_string(...)
    local characters = {}

    for index = 1, select("#", ...) do
        local text = select(index, ...)

        if type(text) == "number" and self._float_precision then
            text = tostring(_P.round(text, self._float_precision))
        elseif type(text) == "table" then
            text = vim.inspect(text)
        else
            text = tostring(text)
        end

        characters[#characters + 1] = text
    end

    return table.concat(characters, " ")
end

--- Send a message that is intended for developers to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:debug(...)
    self:_log_at_level(_LEVELS.debug, _MODES.debug, function(...)
        return self:_make_string(...)
    end, ...)
end

--- Send a "we could not recover from some issue" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:error(...)
    self:_log_at_level(_LEVELS.error, _MODES.error, function(...)
        return self:_make_string(...)
    end, ...)
end

--- Send a "this issue affects multiple systems. It's a really bad error" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fatal(...)
    self:_log_at_level(_LEVELS.fatal, _MODES.fatal, function(...)
        return self:_make_string(...)
    end, ...)
end

--- Send a message that is intended for developers to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fmt_debug(...)
    self:_format_and_log_at_level(_LEVELS.debug, _MODES.debug, ...)
end

--- Send a "we could not recover from some issue" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fmt_error(...)
    self:_format_and_log_at_level(_LEVELS.error, _MODES.error, ...)
end

--- Send a "this issue affects multiple systems. It's a really bad error" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fmt_fatal(...)
    self:_format_and_log_at_level(_LEVELS.fatal, _MODES.fatal, ...)
end

--- Send a user-facing message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fmt_info(...)
    self:_format_and_log_at_level(_LEVELS.info, _MODES.info, ...)
end

--- Send a "this might be an issue or we recovered from an error" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:fmt_warning(...)
    self:_format_and_log_at_level(_LEVELS.warning, _MODES.warning, ...)
end

--- Send a user-facing message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:info(...)
    self:_log_at_level(_LEVELS.info, _MODES.info, function(...)
        return self:_make_string(...)
    end, ...)
end

--- Send a "this might be an issue or we recovered from an error" message to the logger.
---
---@param ... any Any arguments.
---
function M.Logger:warning(...)
    self:_log_at_level(_LEVELS.warning, _MODES.warning, function(...)
        return self:_make_string(...)
    end, ...)
end

--- Create a new logger according to `options`.
---
---@param options mega.logging.SparseLoggerOptions The logger to create.
---@return mega.logging.Logger # The created instance.
---
function M.Logger.new(options)
    ---@class mega.logging.Logger
    local self = setmetatable({}, M.Logger)

    self._sparse_options = options

    local full_options = vim.tbl_deep_extend("force", M._DEFAULTS, options or {})
    ---@cast full_options mega.logging.LoggerOptions

    self.level = full_options.level
    self.name = full_options.name
    self.use_file = full_options.use_file
    self.use_highlights = full_options.use_highlights
    self.use_neovim_commands = full_options.use_neovim_commands

    self._float_precision = full_options.float_precision
    self._use_console = full_options.use_console
    ---@type string?
    self._output_path = full_options.output_path

    if not self._output_path and self.use_neovim_commands then
        self._output_path = vim.fs.joinpath(vim.api.nvim_call_function("stdpath", { "data" }), "default.log")
    end

    return self
end

---@return string? # The path on-disk where logs will be written to.
function M.Logger:get_log_path()
    return self._output_path
end

--- Gather all data above `logger`.
---
--- Important:
---     This function is *exclusive* - it does not include any sparse options
---     of `logger` itself, just its parents.
---
---@param logger mega.logging.Logger The logger to start searching from.
---@return mega.logging.SparseLoggerOptions # All found options, if any.
---@private
---
function _P.get_parent_configuration(logger)
    local parts = vim.fn.split(logger.name, "\\.")
    ---@type mega.logging.SparseLoggerOptions
    local output = {}

    for index = 1, #parts do
        ---@type string[]
        local namespace = {}

        for inner_index = 1, index do
            table.insert(namespace, parts[inner_index])
        end

        output =
            vim.tbl_deep_extend("force", output, _OPTIONS[vim.fn.join(namespace, _LOGGER_HIERARCHY_SEPARATOR)] or {})
    end

    return output
end

--- Find and re-apply all configurations for all loggers starting with `name`.
---
---@param name string A starting point. e.g. `"foo.bar"`.
---@private
---
function _P.recompute_loggers(name)
    for _, logger in pairs(M._LOGGERS) do
        if not name or vim.startswith(logger.name, name) then
            local data = _P.get_parent_configuration(logger)
            ---@diagnostic disable-next-line undefined-field
            logger:_apply_parent_configuration(data)
        end
    end
end

--- Find an existing logger with `name` or create one if it does not exist already.
---
---@param options mega.logging.SparseLoggerOptions string The logger to create.
---@return mega.logging.Logger # The created instance.
---
function M.get_logger(options)
    if type(options) == "string" then
        ---@diagnostic disable-next-line: missing-fields
        options = { name = options }
    end

    local name = options.name

    if not name then
        name = _ROOT_NAME
    end

    if M._LOGGERS[name] then
        return M._LOGGERS[name]
    end

    M._LOGGERS[name] = M.Logger.new(options)

    return M._LOGGERS[name]
end

--- Apply `options` to `name` and all child loggers.
---
--- If `name` is `"foo.bar"` then `"foo.bar"` will be edited but also so will
--- its children `"foo.bar.fizz"`, `"foo.bar.fizz.buzz"`, `"foo.bar.another"`, etc.
---
---@param name string The logger namespace to start modifying from.
---@param options mega.logging.SparseLoggerOptions The data to apply.
---
function M.set_configuration(name, options)
    _OPTIONS[name] = options

    _P.recompute_loggers(name)
end

return M
            ]],
            [[
==============================================================================
------------------------------------------------------------------------------
A generalized logging for Lua. It's similar to Python's built-in logger.

------------------------------------------------------------------------------
*mega.logging.SparseLoggerOptions*
   All of the customizations a person can make to a logger instance.

Fields ~
    {float_precision} `(number)`?
       A positive value (max of 1) to indicate the rounding precision. e.g.
       0.01 rounds to every hundredths.
    {level} ("trace" | "debug" | "info" | "warn" | "error" | "fatal")?
       The minimum severity needed for this logger instance to output a log.
    {name} `(string)`?
       An identifier for this logger.
    {output_path} `(string)`?
       A path on-disk where logs are written to, if any.
    {use_console} `(boolean)`?
       If `true`, logs are printed to the terminal / console.
    {use_file} `(boolean)`?
       If `true`, logs are written to `output_path`.
    {use_highlights} `(boolean)`?
       If `true`, logs are colorful. If `false`, they're mono-colored text.
    {use_neovim_commands} `(boolean)`?
       If `true`, allow logs to submit as Neovim commands. If `false`, only
       built-in Lua commands will be used. This is useful if you want to log
       within a libuv thread and don't want to call `vim.schedule()`.

------------------------------------------------------------------------------
*mega.logging.LoggerOptions*
   All of the customizations a person can make to a logger instance.

Fields ~
    {float_precision} `(number)`
       A positive value (max of 1) to indicate the rounding precision. e.g.
       0.01 rounds to every hundredths.
    {level} "trace" | "debug" | "info" | "warn" | "error" | "fatal"
       The minimum severity needed for this logger instance to output a log.
    {name} `(string)`
       An identifier for this logger.
    {output_path} `(string)`
       A path on-disk where logs are written to, if any.
    {use_console} `(boolean)`
       If `true`, logs are printed to the terminal / console.
    {use_file} `(boolean)`
       If `true`, logs are written to `output_path`.
    {use_highlights} `(boolean)`
       If `true`, logs are colorful. If `false`, they're mono-colored text.
    {use_neovim_commands} `(boolean)`
       If `true`, allow logs to submit as Neovim commands. If `false`, only
       built-in Lua commands will be used. This is useful if you want to log
       within a libuv thread and don't want to call `vim.schedule()`.

------------------------------------------------------------------------------
                                                           *mega.logging.Logger*

`mega.logging.Logger`

------------------------------------------------------------------------------
                                                   *mega.logging.Logger:debug()*

`mega.logging.Logger:debug`({...})

Send a message that is intended for developers to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                   *mega.logging.Logger:error()*

`mega.logging.Logger:error`({...})

Send a "we could not recover from some issue" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                   *mega.logging.Logger:fatal()*

`mega.logging.Logger:fatal`({...})

Send a "this issue affects multiple systems. It's a really bad error" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                               *mega.logging.Logger:fmt_debug()*

`mega.logging.Logger:fmt_debug`({...})

Send a message that is intended for developers to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                               *mega.logging.Logger:fmt_error()*

`mega.logging.Logger:fmt_error`({...})

Send a "we could not recover from some issue" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                               *mega.logging.Logger:fmt_fatal()*

`mega.logging.Logger:fmt_fatal`({...})

Send a "this issue affects multiple systems. It's a really bad error" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                *mega.logging.Logger:fmt_info()*

`mega.logging.Logger:fmt_info`({...})

Send a user-facing message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                             *mega.logging.Logger:fmt_warning()*

`mega.logging.Logger:fmt_warning`({...})

Send a "this might be an issue or we recovered from an error" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                    *mega.logging.Logger:info()*

`mega.logging.Logger:info`({...})

Send a user-facing message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                 *mega.logging.Logger:warning()*

`mega.logging.Logger:warning`({...})

Send a "this might be an issue or we recovered from an error" message to the logger.

Parameters ~
    {...} `(any)` Any arguments.

------------------------------------------------------------------------------
                                                     *mega.logging.Logger.new()*

`mega.logging.Logger.new`({options})

Create a new logger according to `options`.

Parameters ~
    {options} |mega.logging.SparseLoggerOptions| The logger to create.

Return ~
    |mega.logging.Logger| The created instance.

------------------------------------------------------------------------------
                                            *mega.logging.Logger:get_log_path()*

`mega.logging.Logger:get_log_path`()


Return ~
    `(string)` (optional) The path on-disk where logs will be written to.

------------------------------------------------------------------------------
                                                     *mega.logging.get_logger()*

`mega.logging.get_logger`({options})

Find an existing logger with `name` or create one if it does not exist already.

Parameters ~
    {options} |mega.logging.SparseLoggerOptions| string The logger to create.

Return ~
    |mega.logging.Logger| The created instance.

------------------------------------------------------------------------------
                                              *mega.logging.set_configuration()*

`mega.logging.set_configuration`({name}, {options})

Apply `options` to `name` and all child loggers.

If `name` is `"foo.bar"` then `"foo.bar"` will be edited but also so will
its children `"foo.bar.fizz"`, `"foo.bar.fizz.buzz"`, `"foo.bar.another"`, etc.

Parameters ~
    {name} `(string)` The logger namespace to start modifying from.
    {options} |mega.logging.SparseLoggerOptions| The data to apply.
]]
        )
    end)
end)
