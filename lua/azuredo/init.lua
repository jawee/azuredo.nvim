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
    "Set Existing PR Id",
    "Set PR Id manually",
    "Open PR in Browser",
  }

  ---@param row integer
  local function select_current_line(row)
    local choice = options[row]
    if choice then
      M.executeCommand(choice)
    end
  end

  if Config.telescope then
    Window.createTelescopeWindow(options, select_current_line, nil, "Available Commands")
  else
    Window.createWindow(options, select_current_line)
  end
end

M.prId = nil

local function run_async_command(command, args, on_stdout, on_exit)
  local job_id = vim.fn.jobstart(vim.list_extend({ command }, args), {
    rpc = false,
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if on_stdout then
        on_stdout(data)
      end
    end,
    on_exit = function(_, exit_code, _)
      if on_exit then
        on_exit(exit_code)
      end
    end,
  })

  if job_id == 0 then
    vim.notify("Failed to start job: " .. command, vim.log.levels.ERROR)
  end
end

local function handle_set_existing_pr_command()
  local collected_output = {}

  local handle = Util.create_progress_handle()

  run_async_command(
    "sh",
    { "-c", "az repos pr list --source-branch $(git branch --show-current) --output json" },
    function(output_lines)
      for _, line in ipairs(output_lines) do
        table.insert(collected_output, line)
      end
    end,
    function(exit_code)
      if exit_code ~= 0 then
        Util.debug("Command failed with exit code: " .. exit_code)
        Util.progress_report(handle, "Failed to fetch existing PRs", 100)
        Util.progress_finish(handle)
        return
      end

      local raw_json_output = table.concat(collected_output, "") -- Join all lines into a single string
      -- local success, pr_data = pcall(vim.json.decode, raw_json_output)
      local pr_data = vim.json.decode(raw_json_output)
      if pr_data and pr_data[1] and pr_data[1].pullRequestId then
        Util.debug("Found existing PR ID: " .. pr_data[1].pullRequestId)
        M.prId = pr_data[1].pullRequestId
        Util.progress_report(handle, "Found existing PR ID: " .. M.prId, 100)
      else
        Util.progress_report(handle, "No existing PR found", 100)
        Util.debug("No existing PR found or failed to parse response.")
      end
      Util.progress_finish(handle)
    end
  )
end

local function handle_create_pull_request_command()
  local collected_output = {}

  local handle = Util.create_progress_handle()

  run_async_command("sh", { "-c", "az repos pr create --output json" }, function(output_lines)
    for _, line in ipairs(output_lines) do
      table.insert(collected_output, line)
    end
  end, function(exit_code)
    if exit_code ~= 0 then
      Util.debug("Command failed with exit code: " .. exit_code)
      Util.progress_report(handle, "Failed to create Pull Request", 100)
      Util.progress_finish(handle)
      return
    end
    local raw_json_output = table.concat(collected_output, "")
    local pr_data = vim.json.decode(raw_json_output)

    if pr_data and pr_data.pullRequestId then
      Util.debug("Pull Request ID: " .. pr_data.pullRequestId .. " created successfully!")
      M.prId = pr_data.pullRequestId
      Util.progress_report(handle, "Created Pull Request ID: " .. M.prId, 100)
    else
      Util.progress_report(handle, "Failed to parse PR response or missing ID", 100)
      Util.debug("Failed to parse PR response or missing ID.")
      Util.debug("Raw output: " .. raw_json_output) -- Helpful for debugging
    end
    Util.progress_finish(handle)
  end)
end

local function handle_open_pr_in_browser_command()
  if not M.prId then
    Util.notify_error("No Pull Request ID found. Please create a Pull Request first.")
    return
  end
  local collected_output = {}

  local handle = Util.create_progress_handle()
  run_async_command(
    "sh",
    { "-c", "az repos pr show --id " .. M.prId .. " --query repository.webUrl --output tsv" },
    function(output_lines)
      for _, line in ipairs(output_lines) do
        if line and line ~= "" then
          line = line:gsub("^%s*(.-)%s*$", "%1")
          table.insert(collected_output, line)
        end
      end
    end,
    function(exit_code)
      print(vim.inspect(collected_output))
      if exit_code ~= 0 then
        Util.notify_error("Failed to fetch PR URL. Please check your Azure CLI configuration.")
        return
      end
      local url = nil
      if #collected_output > 0 then
        url = collected_output[#collected_output]
        url = url:gsub("^%s*(.-)%s*$", "%1")
      end

      if url and url:match("^https?://") then
        Util.progress_report(handle, "Opening PR " .. M.prId .. " in Browser", 100)
        vim.ui.open(url .. "/pullrequest/" .. M.prId)
      else
        Util.progress_report(handle, "Failed to open PR in Browser", 100)
      end
      Util.progress_finish(handle)
    end
  )
end

local function add_workitem_to_pr(work_item_id, pr_id)
  local handle = Util.create_progress_handle()
  local work_item_cmd = [[az repos pr work-item add --id ]] .. pr_id .. [[ --work-items ]] .. work_item_id
  run_async_command(
    "sh",
    { "-c", work_item_cmd },
    function(_)
    end,
    function(exit_code)
      if exit_code ~= 0 then
        Util.notify_error("Failed to add Work Item " .. work_item_id .. " to PR " .. pr_id)
        Util.progress_report(handle, "Failed to add Work Item " .. work_item_id .. " to PR " .. pr_id, 100)
        Util.progress_finish(handle)
        return
      end
      Util.progress_report(handle, "Added Work Item " .. work_item_id .. " to PR " .. pr_id, 100)
      Util.progress_finish(handle)
    end
  )
end

local function fetch_and_show_workitems()
  if not M.prId then
    Util.notify_error("No Pull Request ID found. Please create a Pull Request first.")
    return
  end

  local collected_output = {}

  local handle = Util.create_progress_handle()

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

  run_async_command(
    "sh",
    { "-c", cmd },
    function(output_lines)
      for _, line in ipairs(output_lines) do
        table.insert(collected_output, line)
      end
    end,
    function(exit_code)
      if exit_code ~= 0 then
        Util.debug("Command failed with exit code: " .. exit_code)
        Util.progress_report(handle, "Failed to fetch work items", 100)
        Util.progress_finish(handle)
        return
      end

      local raw_json_output = table.concat(collected_output, "")
      local data = vim.json.decode(raw_json_output)

      if not data or #data == 0 then
        Util.debug(raw_json_output)
        Util.notify_error("No open tasks or bugs found or failed to fetch data.")
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
          add_workitem_to_pr(selected_id, M.prId)
        end
      end

      Util.progress_report(handle, "Fetched work items successfully", 100)
      if Config.telescope then
        Window.createTelescopeWindow(work_items, select_current_line, nil, "Select Work Item")
      else
        Window.createWindow(work_items, select_current_line)
      end
      Util.progress_finish(handle)
    end
  )
end

function M.executeCommand(command)
  if command == "Create Pull Request" then
    handle_create_pull_request_command()
  elseif command == "Add Work item to Pull Request" then
    if not M.prId then
      Util.notify_error("No Pull Request ID found. Please create a Pull Request first.")
      return
    end

    fetch_and_show_workitems()
  elseif command == "Set PR Id manually" then
    M.prId = vim.fn.input("Enter PR ID: ")
  elseif command == "Set Existing PR Id" then
    handle_set_existing_pr_command()
  elseif command == "Open PR in Browser" then
    handle_open_pr_in_browser_command()
  end
end

vim.api.nvim_create_user_command("Azuredo", function(opts)
  if opts.args then
    M.openMainMenu()
    return
  end
end, { nargs = "*", desc = "azuredo plugin" })

return M
