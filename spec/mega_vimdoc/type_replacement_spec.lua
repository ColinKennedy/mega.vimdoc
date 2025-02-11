--- Make sure that inline type-hints work as expected.

local common = require("test_utilities.common")
local logging = require("mega.vimdoc._vendors.logging")
local vimdoc = require("mega.vimdoc")

local _P = {}

local _EXAMPLE_BUILT_IN_TYPE_NAMES = {
    "...",
    "any",
    "boolean",
    "integer",
    "lightuserdata",
    "nil",
    "number",
    "string",
    "thread",
    "userdata",
}
local _EXAMPLE_CUSTOM_CLASS_NAMES = {
    "Class",
    "ClassName",
    "_namespace.ClassName",
    "blah.Num123bered456",
    "fun",
    "namespace.ClassName",
    "some_._Private.thing",
}

local _EXPECTED_FIELD_TEMPLATE = [[
==============================================================================
------------------------------------------------------------------------------
*FakeClass*

Fields ~
    {name} %s Some description
    {another} %s
       Some description that spans multiple lines
       like this one here.
]]

local _EXPECTED_PARAM_TEMPLATE = [[
==============================================================================
------------------------------------------------------------------------------
                                                                       *thing()*

`thing`({value})

Parameters ~
    {name} %s Some description
    {another} %s
       Some description that spans multiple lines
       like this one here.
]]

local _EXPECTED_RETURN_TEMPLATE = [[
==============================================================================
------------------------------------------------------------------------------
                                                                       *thing()*

`thing`()


Return ~
    %s Some description

Return ~
    %s
       Some description that spans multiple lines
       like this one here.
]]

local _SOURCE_FIELD_TEMPLATE = [[
---@class FakeClass
---@field name %s Some description
---@field another %s
---    Some description that spans multiple lines
---    like this one here.
]]

local _SOURCE_PARAM_TEMPLATE = [[
---@param name %s Some description
---@param another %s
---    Some description that spans multiple lines
---    like this one here.
local function thing(value) end
]]

local _SOURCE_RETURN_TEMPLATE = [[
---@return %s # Some description
---@return %s
---    Some description that spans multiple lines
---    like this one here.
local function thing() return "blah" end
]]

--- Make sure `@field` annotation works as intended.
---
---@param type_ string Some type name. e.g. `"string"`, `"CustomClass"`, etc.
---@param expected string The converted text. e.g. `(string)`, `|CustomClass|`, etc.
---
function _P.run_field_test(type_, expected)
    local full_source = string.format(_SOURCE_FIELD_TEMPLATE, type_, type_)
    local full_expected = string.format(_EXPECTED_FIELD_TEMPLATE, expected, expected)
    _P.run_generic_test(full_source, full_expected)
end

--- Check if `mega.vimdoc` generates `expected` from `text`.
---
---@param text string The literal Lua comment to expand.
---@param expected string The final vimdoc .txt result.
---
function _P.run_generic_test(text, expected)
    local source = common.make_temporary_path("_test_source.lua")
    common.make_fake_file(source, text)
    local destination = common.make_temporary_path("_test_destination.txt")

    vimdoc.make_documentation_files({ { source = source, destination = destination } })

    -- NOTE: We ignore the last few lines because they are auto-generated.
    local raw = vim.fn.readfile(destination)
    local found = vim.fn.join(common.get_slice(raw, 1, math.max(#raw - 4, 1)), "\n")

    assert.equal(expected, found)
end

--- Make sure `@param` annotation works as intended.
---
---@param type_ string Some type name. e.g. `"string"`, `"CustomClass"`, etc.
---@param expected string The converted text. e.g. `(string)`, `|CustomClass|`, etc.
---
function _P.run_param_test(type_, expected)
    local full_source = string.format(_SOURCE_PARAM_TEMPLATE, type_, type_)
    local full_expected = string.format(_EXPECTED_PARAM_TEMPLATE, expected, expected)
    _P.run_generic_test(full_source, full_expected)
end

--- Make sure `@return` annotation works as intended.
---
---@param type_ string Some type name. e.g. `"string"`, `"CustomClass"`, etc.
---@param expected string The converted text. e.g. `(string)`, `|CustomClass|`, etc.
---
function _P.run_return_test(type_, expected)
    local full_source = string.format(_SOURCE_RETURN_TEMPLATE, type_, type_)
    local full_expected = string.format(_EXPECTED_RETURN_TEMPLATE, expected, expected)
    _P.run_generic_test(full_source, full_expected)
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

describe("annotations", function()
    describe("builtin", function()
        it("works with @field", function()
            _P.run_field_test("string", "`(string)`")
        end)

        it("works with @param", function()
            _P.run_param_test("string", "`(string)`")
        end)

        it("works with @return", function()
            _P.run_return_test("string", "`(string)`")
        end)
    end)

    describe("custom", function()
        it("works with @field", function()
            _P.run_field_test("base.MyClassName", "|base.MyClassName|")
        end)

        it("works with @param", function()
            _P.run_param_test("base.MyClassName", "|base.MyClassName|")
        end)

        it("works with @return", function()
            _P.run_return_test("base.MyClassName", "|base.MyClassName|")
        end)
    end)
end)

describe("types", function()
    describe("builtins", function()
        it("works with basic builtin types", function()
            for _, name in ipairs(_EXAMPLE_BUILT_IN_TYPE_NAMES) do
                local expected = string.format("`(%s)`", name)
                _P.run_field_test(name, expected)
                _P.run_param_test(name, expected)
                _P.run_return_test(name, expected)
            end

            for _, name in ipairs(_EXAMPLE_BUILT_IN_TYPE_NAMES) do
                local input = name .. "[]"
                local expected = string.format("`(%s)`[]", name)
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end
        end)

        describe("dictionary", function()
            it("works with basic types", function()
                local input = "{ [string]: integer }"
                local expected = "{ [`(string)`]: `(integer)` }"
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)

        describe("function", function()
            it("works with basic types", function()
                local input = "fun(some_variable: string | number, another: table<string, string>, last: string): nil"
                -- luacheck: push ignore 631
                local expected =
                    "fun(some_variable: `(string)` | `(number)`, another: table<`(string)`, `(string)`>, last: `(string)`): `(nil)`"
                -- luacheck: pop
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)

        describe("table - key-value", function()
            it("works with basic types", function()
                local input = "table<string, integer | number>"
                local expected = "table<`(string)`, `(integer)` | `(number)`>"
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)

        describe("table - table literal", function()
            it("works with basic types", function()
                local input = '{name: string, ["some key"]: integer, last_key: table<string, number>}'
                local expected =
                    '{name: `(string)`, ["some key"]: `(integer)`, last_key: table<`(string)`, `(number)`>}'
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)

        describe("tuple", function()
            it("works with basic types", function()
                local input = "[string, integer, table<string, number>]"
                local expected = "[`(string)`, `(integer)`, table<`(string)`, `(number)`>]"
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)
    end)

    describe("custom", function()
        it("works with custom types", function()
            for _, name in ipairs(_EXAMPLE_CUSTOM_CLASS_NAMES) do
                local input = name
                local expected = string.format("|%s|", name)
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end
        end)

        it("works with custom array types", function()
            for _, name in ipairs(_EXAMPLE_CUSTOM_CLASS_NAMES) do
                local input = name .. "[]"
                local expected = string.format("|%s|[]", name)
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end
        end)
    end)

    describe("alias", function()
        it("works with basic types", function()
            for _, name in ipairs(_EXAMPLE_BUILT_IN_TYPE_NAMES) do
                local input = "`" .. name .. "`"
                local expected = input
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end
        end)

        it("works with custom types", function()
            for _, name in ipairs(_EXAMPLE_CUSTOM_CLASS_NAMES) do
                local input = "`" .. name .. "`"
                local expected = input
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end
        end)

        describe("complex", function()
            it("works with a union", function()
                local input = "`A` | `B`"
                local expected = input
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)

            it("works with a weird type", function()
                -- luacheck: push ignore 631
                local input =
                    "fun(value: fun(value2: (`A` | {[string]: `B`?})?: fun(thing: table<[string, integer?], number?>): nil)): integer?"
                local expected =
                    "fun(value: fun(value2: (`A` | {[`(string)`]: `B`?})?: fun(thing: table<[`(string)`, `(integer)`?], `(number)`?>): `(nil)`)): `(integer)`?"
                -- luacheck: pop
                _P.run_field_test(input, expected)
                _P.run_param_test(input, expected)
                _P.run_return_test(input, expected)
            end)
        end)
    end)

    describe("optional", function()
        it("works with basic types", function()
            for _, name in ipairs(_EXAMPLE_BUILT_IN_TYPE_NAMES) do
                local input = name .. "?"
                local expected = string.format("`(%s)` (optional)", name)
                _P.run_return_test(input, expected)
            end
        end)

        it("works with custom types", function()
            for _, name in ipairs(_EXAMPLE_CUSTOM_CLASS_NAMES) do
                local input = name .. "?"
                local expected = string.format("|%s| (optional)", name)
                _P.run_return_test(input, expected)
            end
        end)

        it("works with a complex type", function()
            -- luacheck: push ignore 631
            local input =
                "fun(value: fun(value2: (string | {[string]: integer})?: fun(thing: table<[string, integer?], number?>): nil)): integer?"
            local expected =
                "fun(value: fun(value2: (`(string)` | {[`(string)`]: `(integer)`})?: fun(thing: table<[`(string)`, `(integer)`?], `(number)`?>): `(nil)`)): `(integer)`?"
            -- luacheck: pop
            _P.run_field_test(input, expected)
            _P.run_param_test(input, expected)
            _P.run_return_test(input, expected)
        end)
    end)
end)
