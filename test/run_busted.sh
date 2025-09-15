#!/bin/bash

# Set up Lua paths for local luarocks installation
export LUA_PATH="$HOME/.luarocks/share/lua/5.1/?.lua;$HOME/.luarocks/share/lua/5.1/?/init.lua;;"
export LUA_CPATH="$HOME/.luarocks/lib/lua/5.1/?.so;;"

# Run busted using our nvim-shim as the Lua interpreter
./test/nvim-shim $HOME/.luarocks/lib/luarocks/rocks-5.1/busted/2.2.0-1/bin/busted "$@"