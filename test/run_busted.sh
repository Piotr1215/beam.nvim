#!/bin/bash

# Find busted binary (check common locations)
BUSTED=""
if [ -f "$HOME/.luarocks/lib/luarocks/rocks-5.1/busted/2.2.0-1/bin/busted" ]; then
    BUSTED="$HOME/.luarocks/lib/luarocks/rocks-5.1/busted/2.2.0-1/bin/busted"
elif command -v busted >/dev/null 2>&1; then
    BUSTED="$(command -v busted)"
elif [ -f "$HOME/.luarocks/bin/busted" ]; then
    BUSTED="$HOME/.luarocks/bin/busted"
else
    echo "Error: busted not found. Install with: luarocks install busted"
    exit 1
fi

# Run busted using our nvim-shim as the Lua interpreter
./test/nvim-shim "$BUSTED" "$@"