local Util = require("azuredo.util")

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
  Util.debug(vim.inspect(opts))
  opts = opts or {}

  options = {}
  options = M.get(opts)

  Util.debug(vim.inspect(options))

  return options
end

function M.get(...)
  options = options or M.setup()

  ---@type azuredo.Config[]
  local all = { {}, defaults, options or {} }

  for i = 1, select("#", ...) do
    ---@type azuredo.Config?
    local opts = select(i, ...)
    if type(opts) == "string" then
      opts = { mode = opts }
    end
    if opts then
      table.insert(all, opts)
    end
  end

  local ret = vim.tbl_deep_extend("force", unpack(all))

  if type(ret.config) == "function" then
    ret.config(ret)
  end

  Util.debug(vim.inspect(ret))
  return ret
end

return setmetatable(M, {
  __index = function(_, key)
    options = options or M.setup()
    assert(options, "should be setup")
    return options[key]
  end,
})
