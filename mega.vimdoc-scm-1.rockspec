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

dependencies = {
    "mini.doc >= 0.14.0, < 1.0",
    "mega.logging >= 1.0.0, < 2.0",
}

test_dependencies = {
    "busted >= 2.0, < 3.0",
    "lua >= 5.1, < 6.0",
    "nlua >= 0.2, < 1.0",
}

-- Reference: https://github.com/luarocks/luarocks/wiki/test#test-types
test = {
    type = "busted",
    flags = { "--helper", "spec/minimal_init.lua" },
}

source = {
    url = "git://github.com/" .. user .. "/" .. package,
}

build = {
    type = "builtin",
}
