local M = {}

M.check = function()
  vim.health.start("CLI tools")

  if vim.fn.executable("az") == 0 then
    vim.health.error("az cli missing")
  end

  vim.health.ok("az found")
end

return M
