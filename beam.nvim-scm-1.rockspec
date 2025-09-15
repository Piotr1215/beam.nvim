rockspec_format = "3.0"
package = "beam.nvim"
version = "scm-1"
source = {
   url = "git://github.com/Piotr1215/beam.nvim",
   branch = "main"
}
description = {
   summary = "Navigate and perform text operations at the speed of light",
   detailed = [[
      beam.nvim enables performing text object operations (yank, delete, change)
      on distant text without moving your cursor. It hijacks Neovim's native
      search to provide a seamless interface for remote operations.
   ]],
   homepage = "https://github.com/Piotr1215/beam.nvim",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
test_dependencies = {
   "busted"
}
test = {
   type = "command",
   command = "make test"
}
build = {
   type = "builtin",
   modules = {
      ["beam"] = "lua/beam/init.lua",
      ["beam.config"] = "lua/beam/config.lua",
      ["beam.operators"] = "lua/beam/operators.lua",
      ["beam.mappings"] = "lua/beam/mappings.lua",
      ["beam.discovery"] = "lua/beam/discovery.lua",
      ["beam.display"] = "lua/beam/display.lua",
      ["beam.search"] = "lua/beam/search.lua",
      ["beam.telescope"] = "lua/beam/telescope.lua",
      ["beam.utils"] = "lua/beam/utils.lua",
      ["beam.which_key"] = "lua/beam/which_key.lua",
   }
}