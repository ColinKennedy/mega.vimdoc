--- Make sure "automatically find the module for a `require`" works.

local common = require("test_utilities.common")
local logging = require("mega.vimdoc._vendors.logging")
local vimdoc = require("mega.vimdoc")

local _PACKAGE_PATH = ""
local _RUNTIMEPATH = ""
---@type string[]
local _PACKAGES_TO_UNLOAD = {}

--- Reset all dependencies and clean up and temporary files / directories.
local function _after_each()
    common.reset_mini_doc()
    common.delete_temporary_data()
end

--- Remember the current `:help 'runtimepath'` so it can be reverted later.
local function _keep_neovim_runtime()
    _RUNTIMEPATH = vim.fn.copy(vim.o.runtimepath)
end

--- Add `directory` to the start of `:help 'runtimepath'` so that we can import it.
---
---@param directory string An absolute path on-disk to a Neovim plugin.
---
local function _prepend_to_runtimepath(directory)
    if not vim.o.runtimepath or vim.o.runtimepath == "" then
        vim.o.runtimepath = directory

        return
    end

    local separator = ","
    vim.o.runtimepath = directory .. separator .. vim.o.runtimepath
end

--- Get the saved `:help 'runtimepath'` and apply it back to the current environment.
local function _restore_neovim_runtime()
    vim.o.runtimepath = _RUNTIMEPATH

    for _, namespace in ipairs(_PACKAGES_TO_UNLOAD) do
        package.loaded[namespace] = nil
    end
end

before_each(function()
    logging.set_configuration(nil, { use_console = false })
    common.silence_mini_doc()
end)

after_each(_after_each)

describe("module discovery", function()
    before_each(function()
        _PACKAGE_PATH = vim.fn.copy(package.path)
    end)
    after_each(function()
        package.path = _PACKAGE_PATH
    end)

    describe("lua", function()
        it("works when a path is found in Lua's LUA_CPATH", function()
            local root = vim.fs.normalize(common.make_temporary_path())
            local plugin = vim.fs.joinpath(root, "my_fake_neovim_plugin")
            local path = vim.fs.joinpath(plugin, "lua", "foo.lua")

            package.path = vim.fs.joinpath(plugin, "lua", "?.lua")
            common.make_fake_file(
                path,
                [[
local M = {}

---@param value string Some data to do things with.
---@return integer # Some return text.
function M.bar(value) end

return M
]]
            )

            table.insert(_PACKAGES_TO_UNLOAD, "foo")

            local success, _ = pcall(function()
                require("foo")
            end)
            assert.is_true(success)

            local destination = vim.fs.joinpath(common.make_temporary_path(), "inner_folder", "destination.lua")
            vimdoc.make_documentation_files({ { source = path, destination = destination } })

            local found = common.read_file_data(destination)

            assert.equal(
                [[
==============================================================================
------------------------------------------------------------------------------
                                                                     *foo.bar()*

`foo.bar`({value})

Parameters ~
    {value} `(string)` Some data to do things with.

Return ~
    `(integer)` Some return text.


WARNING: This file is auto-generated. Do not edit it!

 vim:tw=78:ts=8:noet:ft=help:norl:]],
                found
            )
        end)
    end)

    describe("neovim runtimepath", function()
        before_each(_keep_neovim_runtime)
        after_each(_restore_neovim_runtime)

        it("works with a Lua file in a Neovim plugin", function()
            local root = common.make_temporary_path()
            local plugin = vim.fs.joinpath(root, "my_fake_neovim_plugin")
            local path = vim.fs.joinpath(plugin, "lua", "foo.lua")

            _prepend_to_runtimepath(plugin)
            common.make_fake_file(
                path,
                [[
local M = {}

---@param value string Some data to do things with.
---@return integer # Some return text.
function M.bar(value) end

return M
]]
            )

            table.insert(_PACKAGES_TO_UNLOAD, "foo")

            local success, _ = pcall(function()
                require("foo")
            end)
            assert.is_true(success)

            local destination = vim.fs.joinpath(common.make_temporary_path(), "inner_folder", "destination.lua")
            vimdoc.make_documentation_files({ { source = path, destination = destination } })

            local found = common.read_file_data(destination)

            assert.equal(
                [[
==============================================================================
------------------------------------------------------------------------------
                                                                     *foo.bar()*

`foo.bar`({value})

Parameters ~
    {value} `(string)` Some data to do things with.

Return ~
    `(integer)` Some return text.


WARNING: This file is auto-generated. Do not edit it!

 vim:tw=78:ts=8:noet:ft=help:norl:]],
                found
            )
        end)

        it("works with a init.lua in a Neovim plugin", function()
            local root = common.make_temporary_path()
            local plugin = vim.fs.joinpath(root, "my_fake_neovim_plugin")
            local path = vim.fs.joinpath(plugin, "lua", "foo", "init.lua")

            _prepend_to_runtimepath(plugin)
            common.make_fake_file(
                path,
                [[
local M = {}

---@param value string Some data to do things with.
---@return integer # Some return text.
function M.bar(value) end

return M
]]
            )

            table.insert(_PACKAGES_TO_UNLOAD, "foo")

            local success, _ = pcall(function()
                require("foo")
            end)
            assert.is_true(success)

            local destination = vim.fs.joinpath(common.make_temporary_path(), "inner_folder", "destination.lua")
            vimdoc.make_documentation_files({ { source = path, destination = destination } })

            local found = common.read_file_data(destination)

            assert.equal(
                [[
==============================================================================
------------------------------------------------------------------------------
                                                                     *foo.bar()*

`foo.bar`({value})

Parameters ~
    {value} `(string)` Some data to do things with.

Return ~
    `(integer)` Some return text.


WARNING: This file is auto-generated. Do not edit it!

 vim:tw=78:ts=8:noet:ft=help:norl:]],
                found
            )
        end)

        it("works with an inner Lua file in a Neovim plugin", function()
            local root = common.make_temporary_path()
            local plugin = vim.fs.joinpath(root, "my_fake_neovim_plugin")
            local path = vim.fs.joinpath(plugin, "lua", "foo", "fizz.lua")

            _prepend_to_runtimepath(plugin)
            common.make_fake_file(
                path,
                [[
local M = {}

---@param value string Some data to do things with.
---@return integer # Some return text.
function M.bar(value) end

return M
]]
            )

            table.insert(_PACKAGES_TO_UNLOAD, "foo")

            local success, _ = pcall(function()
                require("foo.fizz")
            end)
            assert.is_true(success)

            local destination = vim.fs.joinpath(common.make_temporary_path(), "inner_folder", "destination.lua")
            vimdoc.make_documentation_files({ { source = path, destination = destination } })

            local found = common.read_file_data(destination)

            assert.equal(
                [[
==============================================================================
------------------------------------------------------------------------------
                                                                *foo.fizz.bar()*

`foo.fizz.bar`({value})

Parameters ~
    {value} `(string)` Some data to do things with.

Return ~
    `(integer)` Some return text.


WARNING: This file is auto-generated. Do not edit it!

 vim:tw=78:ts=8:noet:ft=help:norl:]],
                found
            )
        end)
    end)

    describe("generic", function()
        it("fails if the path is not findable", function()
            local root = common.make_temporary_path()
            local plugin = vim.fs.joinpath(root, "my_fake_neovim_plugin")
            local path = vim.fs.joinpath(plugin, "lua", "foo", "fizz.lua")

            common.make_fake_file(
                path,
                [[
local M = {}

---@param value string Some data to do things with.
---@return integer # Some return text.
function M.bar(value) end

return M
]]
            )

            table.insert(_PACKAGES_TO_UNLOAD, "foo")

            local success, _ = pcall(function()
                require("foo.fizz")
            end)
            assert.is_true(success)

            local destination = vim.fs.joinpath(common.make_temporary_path(), "inner_folder", "destination.lua")
            vimdoc.make_documentation_files({ { source = path, destination = destination } })

            local found = common.read_file_data(destination)

            assert.equal(
                [[
==============================================================================
------------------------------------------------------------------------------
                                                                       *M.bar()*

`bar`({value})

Parameters ~
    {value} `(string)` Some data to do things with.

Return ~
    `(integer)` Some return text.


WARNING: This file is auto-generated. Do not edit it!

 vim:tw=78:ts=8:noet:ft=help:norl:]],
                found
            )
        end)
    end)
end)
