local Util = require("azuredo.util")

local M = {}

---@param options string[]
---@param callback fun(integer)
function M.createWindow(options, callback)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 80
  local max_height = 20
  local height = math.min(#options + 2, max_height)

  local ui = vim.api.nvim_list_uis()[1]

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    anchor = "NW",
    style = "minimal",
    border = "rounded",
  }

  local win = vim.api.nvim_open_win(buf, false, opts)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, options)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.api.nvim_set_option_value("winhl", "Normal:MyHighlight", { win = win })
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local function select_current_line()
    local row, _ = unpack(vim.api.nvim_win_get_cursor(win))
    vim.api.nvim_win_close(win, true)
    callback(row)
  end

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", select_current_line, { buffer = buf, silent = true })

  for i, option in ipairs(options) do
    vim.keymap.set("n", tostring(i), function()
      vim.api.nvim_win_close(win, true)
      Util.debug(option)
    end, { buffer = buf, silent = true })
  end
end
return M
