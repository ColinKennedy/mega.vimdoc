# mega.vimdoc

Convert Lua source code into Vimdoc syntax.

| <!-- -->     | <!-- -->                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/test.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/test.yml)  [![documentation](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/documentation.yml?branch=main&style=for-the-badge&label=Documentation)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/documentation.yml)  [![luacheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/luacheck.yml) [![llscheck](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/llscheck.yml?branch=main&style=for-the-badge&label=llscheck)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/llscheck.yml) [![stylua](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/stylua.yml?branch=main&style=for-the-badge&label=Stylua)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/stylua.yml)  [![urlchecker](https://img.shields.io/github/actions/workflow/status/ColinKennedy/mega.vimdoc/urlchecker.yml?branch=main&style=for-the-badge&label=URLChecker)](https://github.com/ColinKennedy/mega.vimdoc/actions/workflows/urlchecker.yml)  |
| License      | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/ColinKennedy/mega.vimdoc/blob/main/LICENSE)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| Social       | [![RSS](https://img.shields.io/badge/rss-F88900?style=for-the-badge&logo=rss&logoColor=white)](https://github.com/ColinKennedy/mega.vimdoc/commits/main/doc/news.txt.atom)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |



# Features

- Links to custom classes
- Auto-indents / formats code
- Auto-replaces Lua namespaces with the module path

## Gallery
### Class
| Before                                                                                     | After, Concealed                                                                                     | After, Raw Text                                                                                     |
|--------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| ![Before](https://github.com/user-attachments/assets/926d1a49-c361-4b24-81ef-bf41e9da5470) | ![After, Concealed](https://github.com/user-attachments/assets/543ee82a-eb8e-4c19-9a30-0f13df39fa7e) | ![After, Raw Text](https://github.com/user-attachments/assets/366e8fc0-bc27-4fb6-bdeb-eedfa5bbd207) |

### Function
| Before                                                                                     | After, Concealed                                                                                     | After, Raw Text                                                                                     |
|--------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| ![Before](https://github.com/user-attachments/assets/19eb0c3b-49ca-45c3-9e02-20ce6e411388) | ![After, Concealed](https://github.com/user-attachments/assets/f09330e8-25fb-4caa-8592-33679d9ec914) | ![After, Raw Text](https://github.com/user-attachments/assets/0e3d4f05-8c73-4375-8f63-96171c7c1bcd) |


# Installation
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


# Tests
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


# Tracking Updates
See [doc/news.txt](doc/news.txt) for updates.

You can watch this plugin for changes by adding this URL to your RSS feed:
```
https://github.com/ColinKennedy/mega.vimdoc/commits/main/doc/news.txt.atom
```


# Other Plugins
This template is full of various features. But if your plugin is only meant to
be a simple plugin and you don't want the bells and whistles that this template
provides, consider instead using
[nvim-plugin-template](https://github.com/ellisonleao/nvim-plugin-template)
