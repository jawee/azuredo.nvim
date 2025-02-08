local M = {};

function M.setup(opts)
    require("azuredo.config").setup(opts)
end

function M.createWindow()
    local options = {
        "Create Pull Request",
        "Add Work item to Pull Request",
        "Print PR Id",
        "Set PR Id",
    }

    local buf = vim.api.nvim_create_buf(false, true)
    local width = 80
    local max_height = 20
    local height = math.min(#options + 2, max_height)

    local ui = vim.api.nvim_list_uis()[1]

    local opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((ui.height - height) / 2),
        col = math.floor((ui.width - width) / 2),
        anchor = 'NW',
        style = 'minimal',
        border = 'rounded',
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
        local choice = options[row]
        if choice then
            vim.api.nvim_win_close(win, true)
            M.executeCommand(choice)
        end
    end


    vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<CR>", select_current_line, { buffer = buf, silent = true })

    for i, option in ipairs(options) do
        vim.keymap.set("n", tostring(i), function()
            vim.api.nvim_win_close(win, true)
            print(option)
        end, { buffer = buf, silent = true })
    end
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
        end

    elseif command == "Add Work item to Pull Request" then
        if not M.prId then
            print("No Pull Request ID found. Please create a Pull Request first.")
            return
        end

        M.fetch_and_show_workitems()
    elseif command == "Print PR Id" then
        print(M.prId)
    elseif command == "Set PR Id" then
        M.prId = vim.fn.input("Enter PR ID: ")
    end
end

function M.fetch_and_show_workitems()
    local cmd = [[az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType] FROM WorkItems WHERE [System.State] <> 'Closed' and [System.WorkItemType] in ('Task', 'Bug')" --output json]]
    local result = vim.fn.system(cmd)

    local success, data = pcall(vim.json.decode, result)

    if not success or not data or #data == 0 then
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

    local buf = vim.api.nvim_create_buf(false, true)
    local width = 80
    local max_height = 20
    local height = math.min(#work_items + 2, max_height)

    local ui = vim.api.nvim_list_uis()[1]
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((ui.height - height) / 2),
        col = math.floor((ui.width - width) / 2),
        style = "minimal",
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.api.nvim_set_current_win(win)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, work_items)

    vim.bo[buf].modifiable = false
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false

    vim.api.nvim_win_set_cursor(win, {1, 0})

    local function select_current_line()
        local row, _ = unpack(vim.api.nvim_win_get_cursor(win))
        local selected_id = work_item_ids[row]
        if selected_id then
            vim.api.nvim_win_close(win, true)
            print("Adding Id" .. selected_id .. " to PR " .. M.prId)
            local work_item_cmd = [[az repos pr work-item add --id ]] .. M.prId .. [[ --work-items ]] .. selected_id
            vim.fn.system(work_item_cmd)
        end
    end

    vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf, silent = true })
    vim.keymap.set("n", "<CR>", select_current_line, { buffer = buf, silent = true })
end

vim.api.nvim_create_user_command("Azuredo", function(opts)
    if opts.args then
        M.createWindow()
        return
    end
end, { nargs = "*", desc = "azuredo plugin" })

return M
