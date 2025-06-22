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

-- @return progress_handle
function M.create_progress_handle()
  if Config.fidget then
    local progress = require("fidget.progress")
    local handle = progress.handle.create({
      title = "Azuredo",
      message = "",
      lsp_client = { name = "Calling DevOps" },
      percentage = 0,
    })
    return handle
  end

  return {
    report = function(_, other)
      M.notify(other.message)
    end,
    finish = function() end,
  }
end

function M.progress_report(handle, message, percentage)
  handle:report({
    title = "Azuredo",
    message = message,
    percentage = percentage,
  })
end

function M.progress_finish(handle)
  handle:finish()
end

return M
