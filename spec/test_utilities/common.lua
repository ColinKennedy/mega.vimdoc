--- Simple functions to make writing unittests easier.

local M = {}

local _COUNTER = 1
---@type string[]
local _DELETE_LATER = {}
local _ORIGINAL_VIM_NOTIFY = vim.notify

--- Delete all files / folders that were created during unittesting.
function M.delete_temporary_data()
    for _, path in ipairs(_DELETE_LATER) do
        vim.fn.delete(path, "rf")
    end

    _DELETE_LATER = {}
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

--- Revert any mocks before unittests were ran.
function M.reset_mini_doc()
    vim.notify = _ORIGINAL_VIM_NOTIFY
end

return M
