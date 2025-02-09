# azuredo.nvim
Plugin for Azure DevOps integration in Neovim

# Work in Progress
Should probably not be used.

## Features
- Create PR from current branch
- Add Work Items to PR
- [Telescope](https://github.com/nvim-telescope/telescope.nvim) UI
- [Fidget](https://github.com/j-hui/fidget.nvim) notifications


## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "jawee/azuredo.nvim",
  config = function()
    require("azuredo").setup({})
    vim.keymap.set("n", "<leader>az", "<cmd>Azuredo<CR>")
  end,
}
```

## Configuration

Default settings below.

<details><summary>Default Settings</summary>
<!-- config:start -->

```lua
---@class azuredo.Config
---@field config? fun(opts:azuredo.Config)
local defaults = {
  debug = false,
  project = nil, -- optional project filter for querying work items
  telescope = false, -- if UI should be through telescope
  fidget = false, -- if notifications should come through fidget.nvim
}
```

<!-- config:end -->

</details>

## Usage

- `Azuredo`
