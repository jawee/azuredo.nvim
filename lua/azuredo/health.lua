local Config = require("azuredo.config")

local M = {}

local function is_plugin_dir_exists(plugin_path)
  return vim.fn.isdirectory(vim.fn.stdpath("data") .. "/lazy/" .. plugin_path) == 1
end

M.check = function()
  vim.health.start("CLI tools")

  if vim.fn.executable("az") == 0 then
    vim.health.error("az cli missing")
  end

  if Config.telescope then
    if not is_plugin_dir_exists("telescope.nvim") then
      vim.health.error("telescope.nvim not installed")
    else
      vim.health.ok("telescope.nvim found")
    end
  end

  if Config.fidget then
    if not is_plugin_dir_exists("fidget.nvim") then
      vim.health.error("fidget.nvim not installed")
    else
      vim.health.ok("fidget.nvim found")
    end
  end

  vim.health.ok("az found")
end

return M
