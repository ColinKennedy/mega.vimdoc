# 🐦 mega.vimdoc

Convert Lua source code into Vimdoc syntax.

| <!-- -->     | <!-- -->                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/test.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/test.yml)  [![documentation](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/documentation.yml?branch=main&style=for-the-badge&label=Documentation)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/documentation.yml)  [![luacheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/luacheck.yml) [![llscheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/llscheck.yml?branch=main&style=for-the-badge&label=llscheck)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/llscheck.yml) [![stylua](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/stylua.yml?branch=main&style=for-the-badge&label=Stylua)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/stylua.yml)  [![urlchecker](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/urlchecker.yml?branch=main&style=for-the-badge&label=URLChecker)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/urlchecker.yml)  |
| License      | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/ColinKennedy/mega.vimdoc/blob/main/LICENSE)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Social       | [![RSS](https://img.shields.io/badge/rss-F88900?style=for-the-badge&logo=rss&logoColor=white)](https://github.com/ColinKennedy/mega.vimdoc/commits/main/doc/news.txt.atom)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |



# ⚡️Features

- Auto-links to custom classes. Just hover over a type and `CTRL-]`!
- Auto-indents / formats code
- Auto-replaces Lua namespaces with the module path.
    - No more functions labelled like `M.get_items`


## Gallery
### Class
| Before                                                                                     | After, Concealed                                                                                     | After, Raw Text                                                                                     |
|--------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| ![Before](https://github.com/user-attachments/assets/926d1a49-c361-4b24-81ef-bf41e9da5470) | ![After, Concealed](https://github.com/user-attachments/assets/543ee82a-eb8e-4c19-9a30-0f13df39fa7e) | ![After, Raw Text](https://github.com/user-attachments/assets/366e8fc0-bc27-4fb6-bdeb-eedfa5bbd207) |

### Function
| Before                                                                                     | After, Concealed                                                                                     | After, Raw Text                                                                                     |
|--------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| ![Before](https://github.com/user-attachments/assets/19eb0c3b-49ca-45c3-9e02-20ce6e411388) | ![After, Concealed](https://github.com/user-attachments/assets/f09330e8-25fb-4caa-8592-33679d9ec914) | ![After, Raw Text](https://github.com/user-attachments/assets/0e3d4f05-8c73-4375-8f63-96171c7c1bcd) |


# 📋 Installation
```lua
{
    "ColinKennedy/mega.vimdoc",
    dependencies = {
        "ColinKennedy/mega.logging",  -- Recommended but optional
        "echasnovski/mini.doc",  -- Required
    },
    version = "v1.*",
}
```


# Comparison To Other Plugins
Other vimdoc generators exist, such as [mini.doc](https://github.com/echasnovski/mini.doc).
`mega.vimdoc` can do what most other generators can but has extra features that
set it apart.


## More And Better Automated Tags
Classes, Functions, and other types are auto-tagged with Vimdoc tags. For
example this plugin might output this vimdoc `.txt` file.

```vimdoc
`mega.vimdoc.make_documentation_files`({paths}, {options})

Convert the files in this plug-in from Lua docstrings to Vimdoc documentation.

Parameters ~
    {paths} |mega.vimdoc.AutoDocumentationEntry|[]
       All of the source + destination pairs to process.
    {options} |mega.vimdoc.AutoDocumentationOptions|?
       Customize the output using these settings, if needed.
```

`mega.vimdoc` auto-detects the custom type and places the `||` tags in just the
right place. The end result - just hover your cursor over it and press `CTRL-]`
and jump straight to its definition.

The logic for this type-discovery is pretty good and works even with complex,
nested types. The point is, using `mega.vimdoc` makes your documentation smarter.


## Automatic namespace replacements. So for example like:

`lua/some/file.lua`
```lua
local M

---@param foo string Description.
function M.bar(foo) end

return M
```

With other documentation generators, the above would be documented literally as
`M.bar`. With `mega.vimdoc`, the function is replaced with `some.file.bar`
because it has the full context.


### `---@meta` support
The automated module replacement described above also supports `---@meta` annotations!


# ✅ Tests
## Initialization
Run this line once before calling any `busted` command

```sh
eval $(luarocks path --lua-version 5.1 --bin)
```


## Running
Run all tests
```sh
luarocks test --test-type busted
# Or manually
busted .
# Or with Make
make test
```

Run test based on tags
```sh
busted . --tags=simple
```


# 👂 Tracking Updates
See [doc/news.txt](doc/news.txt) for updates.

You can watch this plugin for changes by adding this URL to your RSS feed:
```
https://github.com/ColinKennedy/mega.vimdoc/commits/main/doc/news.txt.atom
```
