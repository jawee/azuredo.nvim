local Config = require("azuredo.config")

local M = {}

---@param msg string|string[]
function M.debug(msg, ...)
  if Config.debug then
    if select("#", ...) > 0 then
      local obj = select("#", ...) == 1 and ... or { ... }
      msg = msg .. "\n```lua\n" .. vim.inspect(obj) .. "\n```"
    end
    M.notify(msg, { title = "Azuredo (debug)" })
  end
end

return M
