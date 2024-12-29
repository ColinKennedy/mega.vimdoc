rockspec_format = "3.0"
package = "mega.vimdoc"
version = "scm-1"

local user = "ColinKennedy"

description = {
    homepage = "https://github.com/" .. user .. "/" .. package,
    labels = { "neovim", "neovim-plugin" },
    license = "MIT",
    summary = 'A "Best Practices" Neovim plugin template',
}

source = {
    url = "git://github.com/" .. user .. "/" .. package,
}

build = {
    type = "builtin",
}
