local Config = require("azuredo.config")
local Fidget = require("fidget")

local M = {}

---@param msg string
function M.debug(msg)
  if Config.debug then
    print(msg)
  end
end

---@param msg string
function M.notify(msg)
  if Config.fidget then
    Fidget.notify(msg, vim.log.levels.INFO)
    return
  end
  vim.notify(msg, vim.log.levels.INFO)
end

---@param msg string
function M.notify_error(msg)
  if Config.fidget then
    Fidget.notify(msg, vim.log.levels.ERROR)
    return
  end
  vim.notify(msg, vim.log.levels.ERROR)
end

function M.create_progress_handle()
  local progress = require("fidget.progress")
  local handle = progress.handle.create({
    title = "Azuredo",
    message = "",
    lsp_client = { name = "Calling DevOps" },
    percentage = 0,
  })
  return handle
end

return M

