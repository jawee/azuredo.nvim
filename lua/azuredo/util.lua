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
function M.notifyError(msg)
  if Config.fidget then
    Fidget.notify(msg, vim.log.levels.ERROR)
    return
  end
  vim.notify(msg, vim.log.levels.ERROR)
end

return M
