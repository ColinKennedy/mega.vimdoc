--- Simple functions to make writing unittests easier.

local M = {}

local _COUNTER = 1
---@type string[]
local _DELETE_LATER = {}
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
function M.get_slice(table_, first, last, step)
    local sliced = {}

    for i = first or 1, last or #table_, step or 1 do
        sliced[#sliced + 1] = table_[i]
    end

    return sliced
end

--- Delete all files / folders that were created during unittesting.
function M.delete_temporary_data()
    for _, path in ipairs(_DELETE_LATER) do
        vim.fn.delete(path, "rf")
    end

    _DELETE_LATER = {}
end

--- Make a file on-disk at `path`.
---
--- Raises:
---     If `path` is not writeable for some reason.
---
---@param path string An absolute path where a new file (probably a file file) will go.
---@param data string A blob of text to write into the `path`.
---
function M.make_fake_file(path, data)
    local directory = vim.fs.dirname(path)

    if vim.fn.isdirectory(directory) ~= 1 then
        vim.fn.mkdir(directory, "p")
    end

    local file = io.open(path, "w")

    if not file then
        error(string.format('Path "%s" cannot be written to.', path), 0)
    end

    file:write(data)
    file:close()
end

if vim.fn.has("win32") == 1 then
    -- NOTE: GitHub actions place temp files in a directory, C:\Users\RUNNER~1,
    -- that Vim doesn't know how to read. So we need to redirect that temporary
    -- directory that gets created.

    --- Make a file ending in `suffix`.
    ---
    ---@param suffix string? An ending name / file extension. e.g. `".lua"`.
    ---@return string # The file path on-disk that Vim made.
    ---
    M.make_temporary_path = function(suffix)
        -- NOTE: We need just the string for a directory name.
        local directory = os.tmpname()
        vim.fn.delete(directory)
        directory = vim.fs.joinpath(vim.fn.getcwd(), ".tmp.mega.vimdoc", vim.fs.basename(directory))

        local path = vim.fs.joinpath(directory, tostring(_COUNTER) .. (suffix or ""))
        table.insert(_DELETE_LATER, directory)
        _COUNTER = _COUNTER + 1

        return path
    end
else
    --- Make a file ending in `suffix`.
    ---
    ---@param suffix string? An ending name / file extension. e.g. `".lua"`.
    ---@return string # The file path on-disk that Vim made.
    ---
    M.make_temporary_path = function(suffix)
        -- NOTE: We need just the string for a directory name.
        local directory = os.tmpname()
        vim.fn.delete(directory)

        local path = vim.fs.joinpath(directory, tostring(_COUNTER) .. (suffix or ""))
        table.insert(_DELETE_LATER, directory)
        _COUNTER = _COUNTER + 1

        return path
    end
end

--- Stop mini.doc from printing during unittests.
function M.silence_mini_doc()
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function() end
end

--- Read the file contents of `path`.
---
--- Raises:
---     If `path` is unreadable.
---
---@param path string An absolute path on-disk.
---@return string # The found text.
---
function M.read_file_data(path)
    local file = io.open(path, "r")

    if not file then
        error(string.format('Path "%s" cannot be read.', path))
    end

    local data = file:read("*a")

    file:close()

    return data
end

--- Revert any mocks before unittests were ran.
function M.reset_mini_doc()
    vim.notify = _ORIGINAL_VIM_NOTIFY
end

return M
