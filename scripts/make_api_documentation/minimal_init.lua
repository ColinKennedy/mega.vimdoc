for url, directory in pairs({
    ["https://github.com/echasnovski/mini.doc"] = os.getenv("MINI_DOC_DIRECTORY") or "/tmp/mini.doc",
}) do
    vim.fn.system({ "git", "clone", url, directory })

    vim.opt.rtp:append(directory)
end

vim.opt.rtp:append(".")
