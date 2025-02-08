local Config = require("azuredo.config")

local M = {}

---@param msg string
function M.debug(msg)
  if Config.debug then
    print(msg)
  end
end

return M
