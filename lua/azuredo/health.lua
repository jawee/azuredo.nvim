local M = {}

M.check = function()
  vim.health.start("CLI tools")

  -- Check if `az` is installed
  -- figure out how to check if extension is installed
  if vim.fn.executable("az") == 0 then
    vim.health.error("az cli missing")
    -- elseif vim.fn.execute("az extension show --name azure-devops") == 0 then
    --   vim.health.error("az devops extension missing")
  else
    -- local handle = io.popen("az extension show --name azure-devops")
    --
    -- if handle == nil then
    --   vim.health.error("error on attempting to read `az extension show --name azure-devops`")
    --   return
    -- end
    --
    -- local output = handle:read("*a")
    -- handle:close()
    --
    -- if output:match("extension azure-devops is not installed") then
    --   vim.health.error("az devops extension missing")
    --   -- print("Azure DevOps extension is NOT installed")
    --   return
    -- end
    --
    -- local result = handle:read("*a")
    -- handle:close()
    --
    -- if result:find("The extension azure-devops is not installed") then
    --   vim.health.error("az devops extension missing")
    --   return
    -- end
  end
  vim.health.ok("az found")
  -- else
  -- 	-- Run `dotnet --version` to get the version of dotnet
  -- 	local handle = io.popen("dotnet --version")
  --
  -- 	-- If the output is nil then report an error (this should never happen)
  -- 	if handle == nil then
  -- 		vim.health.error("error on attempting to read `dotnet --version`")
  -- 		return
  -- 	end
  --
  -- 	-- Read the result of running `dotnet --version`
  -- 	local result = handle:read("*a")
  -- 	handle:close()
  --
  -- 	-- Remove the newline character from the result
  -- 	local version = result.gsub(result, "\n", "")
  --
  -- 	-- Report the version of `dotnet`
  -- end
end

return M
