local Config = require("azuredo.config")
local Util = require("azuredo.util")
local Window = require("azuredo.window")

local M = {}

---@param opts? azuredo.Config
function M.setup(opts)
  Util.debug(vim.inspect(opts))
  require("azuredo.config").setup(opts)
end

function M.openMainMenu()
  local options = {
    "Create Pull Request",
    "Add Work item to Pull Request",
    "Print PR Id",
    "Set Existing PR Id",
    "Set PR Id manually",
  }

  ---@param row integer
  local function select_current_line(row)
    local choice = options[row]
    if choice then
      M.executeCommand(choice)
    end
  end

  Window.createWindow(options, select_current_line)
end

M.prId = nil

function M.executeCommand(command)
  if command == "Create Pull Request" then
    print("Creating Pull Request")
    local result = vim.fn.system("az repos pr create --output json")

    local success, pr_data = pcall(vim.json.decode, result)
    if success and pr_data and pr_data.pullRequestId then
      print("Pull Request ID: " .. pr_data.pullRequestId)
      M.prId = pr_data.pullRequestId
    else
      print("Failed to create Pull Request")
    end
  elseif command == "Add Work item to Pull Request" then
    if not M.prId then
      print("No Pull Request ID found. Please create a Pull Request first.")
      return
    end

    M.fetch_and_show_workitems()
  elseif command == "Print PR Id" then
    print(M.prId)
  elseif command == "Set PR Id manually" then
    M.prId = vim.fn.input("Enter PR ID: ")
  elseif command == "Set Existing PR Id" then
    local result = vim.fn.system("az repos pr list --source-branch $(git branch --show-current) --output json")

    local success, pr_data = pcall(vim.json.decode, result)
    if success and pr_data and pr_data[1].pullRequestId then
      print("Pull Request ID: " .. pr_data[1].pullRequestId)
      M.prId = pr_data[1].pullRequestId
    else
      print("Failed to get ID. PR doesn't exist or something went wrong")
      Util.debug(result)
    end
  end
end

function M.fetch_and_show_workitems()
  local cmd = [[
  az boards query \
  ]]

  cmd = cmd
    .. [[
  --wiql "SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType] \
  FROM WorkItems WHERE
  ]]

  Util.debug(Config.project)
  if Config.project ~= nil then
    Util.debug("apply project filter")
    cmd = cmd .. "[System.TeamProject] = '" .. Config.project .. "' AND "
  end

  cmd = cmd .. [[[System.State] <> 'Closed' and [System.WorkItemType] in ('Task', 'Bug')" --output json
  ]]

  local result = vim.fn.system(cmd)

  local success, data = pcall(vim.json.decode, result)

  if not success or not data or #data == 0 then
    Util.debug(result)
    print("No open tasks or bugs found or failed to fetch data.")
    return
  end

  local work_items = {}
  local work_item_ids = {}
  for _, item in ipairs(data) do
    local id = item.fields["System.Id"]
    local title = item.fields["System.Title"]
    local wtype = item.fields["System.WorkItemType"]
    table.insert(work_items, string.format("%d: [%s] %s", id, wtype, title))
    table.insert(work_item_ids, id)
  end

  ---@param row integer
  local function select_current_line(row)
    local selected_id = work_item_ids[row]
    if selected_id then
      print("Adding Id" .. selected_id .. " to PR " .. M.prId)
      local work_item_cmd = [[az repos pr work-item add --id ]] .. M.prId .. [[ --work-items ]] .. selected_id
      vim.fn.system(work_item_cmd)
    end
  end

  Window.createWindow(work_items, select_current_line)
end

vim.api.nvim_create_user_command("Azuredo", function(opts)
  if opts.args then
    M.openMainMenu()
    return
  end
end, { nargs = "*", desc = "azuredo plugin" })

return M
