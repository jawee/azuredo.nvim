---@class azuredo.Config.mod: azuredo.Config
local M = {}

---@class azuredo.Config
---@field config? fun(opts:azuredo.Config)
local defaults = {
  debug = false,
  project = nil,
}

---@type azuredo.Config
local options

---@param opts? azuredo.Config
function M.setup(opts)
  opts = opts or {}

  options = {}
  options = M.get(opts)

  return options
end

function M.get(...)
  options = options or M.setup()

  ---@type azuredo.Config[]
  local all = { {}, defaults, options or {} }

  for i = 1, select("#", ...) do
    ---@type azuredo.Config?
    local opts = select(i, ...)
    if opts then
      table.insert(all, opts)
    end
  end

  local ret = vim.tbl_deep_extend("force", unpack(all))

  if type(ret.config) == "function" then
    ret.config(ret)
  end

  return ret
end

return setmetatable(M, {
  __index = function(_, key)
    options = options or M.setup()
    return options[key]
  end,
})
