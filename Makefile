.PHONY: api_documentation llscheck luacheck stylua test

# Git will error if the repository already exists. We ignore the error.
# NOTE: We still print out that we did the clone to the user so that they know.
#
ifeq ($(OS),Windows_NT)
    IGNORE_EXISTING = 2> nul
else
    IGNORE_EXISTING = 2> /dev/null || true
endif

clone_git_dependencies:
	git clone git@github.com:ColinKennedy/mega.logging.git .dependencies/mega.logging $(IGNORE_EXISTING)
	git clone git@github.com:LuaCATS/busted.git .dependencies/busted $(IGNORE_EXISTING)
	git clone git@github.com:LuaCATS/luassert.git .dependencies/luassert $(IGNORE_EXISTING)

api_documentation:
	nvim -u scripts/make_api_documentation/minimal_init.lua -l scripts/make_api_documentation/main.lua

llscheck: clone_git_dependencies
	VIMRUNTIME=`nlua -e 'io.write(os.getenv("VIMRUNTIME"))'` llscheck --configpath $(CONFIGURATION) .

luacheck:
	luacheck lua scripts spec

stylua:
	stylua lua scripts spec

test: clone_git_dependencies
	busted .
