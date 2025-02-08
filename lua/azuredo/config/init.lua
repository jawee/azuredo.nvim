local M = {}
---@class azuredo.Config
local defaults = {
}

---@type azuredo.Config
local options
---@param opts? azuredo.Config
function M.setup(opts)
  opts = opts or {}
  options = {}
end

return M
