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
    "Some long running process",
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
    rpc = false,            -- Set to true if your external command is an RPC server
    stdout_buffered = true, -- Buffer stdout until job ends or a buffer is full
    on_stdout = function(_, data, _)
      -- 'data' is a list of lines from stdout
      if on_stdout then
        on_stdout(data)
      end
    end,
    on_exit = function(_, exit_code, _)
      -- 'exit_code' is the exit status of the command
      if on_exit then
        on_exit(exit_code)
      end
    end,
    -- Other options you might find useful:
    -- stderr_buffered = true,
    -- on_stderr = function(_, data, event) ... end,
    -- cwd = '/path/to/directory', -- Set working directory
    -- detach = true, -- Detach the process from Neovim's control
  })

  if job_id == 0 then
    vim.notify("Failed to start job: " .. command, vim.log.levels.ERROR)
  end
end

local function create_progress_handle()
  local progress = require("fidget.progress")
  local handle = progress.handle.create({
    title = "Azuredo",
    message = "",
    lsp_client = { name = "Calling DevOps" },
    percentage = 0,
  })
  return handle
end

local function handleCreatePullRequestCommand()
  local collected_output = {}

  local handle = create_progress_handle()

  run_async_command(
    "sh",                                         -- Use 'sh' to execute a shell command
    { "-c", "az repos pr create --output json" }, -- Command with sleep
    function(output_lines)
      print("Command output:")
      for _, line in ipairs(output_lines) do
        print(line)
        table.insert(collected_output, line)
      end
    end,
    function(exit_code)
      if exit_code ~= 0 then
        Util.debug("Command failed with exit code: " .. exit_code)
        handle:report({
          title = "Azuredo",
          message = "Failed to create Pull Request",
          percentage = 100,
        })
        handle:finish()
        return
      end
      local raw_json_output = table.concat(collected_output, "") -- Join all lines into a single string
      local success, pr_data = pcall(vim.json.decode, raw_json_output)

      if success and pr_data and pr_data.pullRequestId then
        Util.debug("Pull Request ID: " .. pr_data.pullRequestId .. " created successfully!")
        M.prId = pr_data.pullRequestId
        handle:report({
          title = "Azuredo",
          message = "Created Pull Request ID: " .. M.prId,
          percentage = 100,
        })
      else
        handle:report({
          title = "Azuredo",
          message = "Failed to parse PR response or missing ID",
          percentage = 100,
        })
        Util.debug("Failed to parse PR response or missing ID.")
        Util.debug("Raw output: " .. raw_json_output) -- Helpful for debugging
      end
      handle:finish()
    end
  )
end

function M.executeCommand(command)
  if command == "Create Pull Request" then
    handleCreatePullRequestCommand()
  elseif command == "Add Work item to Pull Request" then
    if not M.prId then
      Util.notifyError("No Pull Request ID found. Please create a Pull Request first.")
      return
    end

    M.fetch_and_show_workitems()
  elseif command == "Set PR Id manually" then
    M.prId = vim.fn.input("Enter PR ID: ")
  elseif command == "Set Existing PR Id" then
    local result = vim.fn.system("az repos pr list --source-branch $(git branch --show-current) --output json")

    local success, pr_data = pcall(vim.json.decode, result)
    if success and pr_data and pr_data[1].pullRequestId then
      Util.notify("Pull Request ID: " .. pr_data[1].pullRequestId)
      M.prId = pr_data[1].pullRequestId
    else
      Util.notifyError("Failed to get ID. PR doesn't exist or something went wrong")
      Util.debug(result)
    end
  elseif command == "Open PR in Browser" then
    if not M.prId then
      Util.notifyError("No Pull Request ID found. Please create a Pull Request first.")
      return
    end

    local result = vim.fn.system("az repos pr show --id " .. M.prId .. " --query repository.webUrl --output tsv")
    local success, repo_url = pcall(string.gsub, result, "\n", "")
    if success then
      Util.notify("Opening PR " .. M.prId .. " in Browser")
      vim.ui.open(repo_url .. "/pullrequest/" .. M.prId)
    else
      Util.notifyError("Failed to open PR in Browser")
    end
  elseif command == "Some long running process" then
    local progress = require("fidget.progress")

    local handle = progress.handle.create({
      title = "Azuredo",
      message = "",
      lsp_client = { name = "Calling DevOps" },
      percentage = 0,
    })

    run_async_command(
      "sh",                                                                  -- Use 'sh' to execute a shell command
      { "-c", "echo 'Starting sleep...'; sleep 5; echo 'Sleep finished!'" }, -- Command with sleep
      function(output_lines)
        print("Command output:")
        for _, line in ipairs(output_lines) do
          print(line)
        end
      end,
      function(exit_code)
        handle:report({
          title = "Azuredo",
          message = "Got a result",
          percentage = 100,
        })
        handle:finish()
        print("Command exited with code: " .. exit_code)
      end
    )
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
    Util.notifyError("No open tasks or bugs found or failed to fetch data.")
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
      Util.notify("Adding Id" .. selected_id .. " to PR " .. M.prId)
      local work_item_cmd = [[az repos pr work-item add --id ]] .. M.prId .. [[ --work-items ]] .. selected_id
      vim.fn.system(work_item_cmd)
    end
  end

  if Config.telescope then
    Window.createTelescopeWindow(work_items, select_current_line, nil, "Select Work Item")
  else
    Window.createWindow(work_items, select_current_line)
  end
end

vim.api.nvim_create_user_command("Azuredo", function(opts)
  if opts.args then
    M.openMainMenu()
    return
  end
end, { nargs = "*", desc = "azuredo plugin" })

return M
