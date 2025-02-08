# azuredo.nvim
Plugin for Azure DevOps integration in Neovim

## Features
- Create PR from current branch
- Add Work Items to PR

# Work in Progress
Should probably not be used.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
return {
  "jawee/azuredo.nvim",
  config = function()
    require("azuredo").setup()
    vim.keymap.set("n", "<leader>az", "<cmd>Azuredo<CR>")
  end,
}
```
