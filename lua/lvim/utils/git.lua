local M = {}

local Log = require "lvim.core.log"
local if_nil = vim.F.if_nil

local function git_cmd(opts)
  local plenary_loaded, Job = pcall(require, "plenary.job")
  if not plenary_loaded then
    return 1, { "" }
  end

  opts = opts or {}
  opts.cwd = opts.cwd or get_lvim_base_dir()

  local stderr = {}
  local stdout, ret = Job
    :new({
      command = "git",
      args = opts.args,
      cwd = opts.cwd,
      on_stderr = function(_, data)
        table.insert(stderr, data)
      end,
    })
    :sync()

  if not vim.tbl_isempty(stderr) then
    Log:debug(stderr)
  end

  if not vim.tbl_isempty(stdout) then
    Log:debug(stdout)
  end

  return ret, stdout
end

local function safe_deep_fetch()
  local ret, result = git_cmd { args = { "rev-parse", "--is-shallow-repository" } }
  if ret ~= 0 then
    Log:error "Git fetch failed! Check the log for further information"
    return
  end
  -- git fetch --unshallow will cause an error on a a complete clone
  local fetch_mode = result[1] == "true" and "--unshallow" or "--all"
  ret = git_cmd { args = { "fetch", fetch_mode } }
  if ret ~= 0 then
    Log:error "Git fetch failed! Check the log for further information"
    return
  end
  return true
end

---pulls the latest changes from github
function M.update_base_lvim()
  Log:info "Checking for updates"

  local ret = git_cmd { args = { "fetch" } }
  if ret ~= 0 then
    Log:error "Update failed! Check the log for further information"
    return
  end

  ret = git_cmd { args = { "diff", "--quiet", "@{upstream}" } }
  if ret == 0 then
    Log:info "LunarVim is already up-to-date"
    return
  end

  ret = git_cmd { args = { "merge", "--ff-only", "--progress" } }
  if ret ~= 0 then
    Log:error "Update failed! Please pull the changes manually instead."
    return
  end
end

---Switch Lunarvim to the specified development branch
---@param branch string
function M.switch_lvim_branch(branch)
  if not safe_deep_fetch() then
    return
  end
  local ret = git_cmd { args = { "switch", branch } }
  if ret ~= 0 then
    Log:error "Unable to switch branches! Check the log for further information"
    return
  end
end

---Get the current Lunarvim development branch
---@return string|nil
function M.get_lvim_branch()
  local _, results = git_cmd { args = { "rev-parse", "--abbrev-ref", "HEAD" } }
  local branch = if_nil(results[1], "")
  return branch
end

---Get currently checked-out tag of Lunarvim
---@return string
function M.get_lvim_tag()
  local args = { "describe", "--tags", "--abbrev=0" }

  local _, results = git_cmd { args = args }
  local tag = if_nil(results[1], "")
  return tag
end

---Get the commit hash of currently checked-out commit of Lunarvim
---@return string|nil
function M.get_lvim_current_sha()
  local _, log_results = git_cmd { args = { "log", "--pretty=format:%h", "-1" } }
  local abbrev_version = if_nil(log_results[1], "")
  return abbrev_version
end

function M.generate_plugins_sha(output)
  local list = {}
  output = output or "commits.lua"

  local core_plugins = require "lvim.plugins"
  for _, plugin in pairs(core_plugins) do
    local name = plugin[1]:match "/(%S*)"
    local url = "https://github.com/" .. plugin[1]
    print("checking: " .. name .. ", at: " .. url)
    local retval, latest_sha = git_cmd { args = { "ls-remote", url, "origin", "HEAD" } }
    if retval == 0 then
      -- replace dashes, remove postfixes and use lowercase
      local normalize_name = (name:gsub("-", "_"):gsub("%.%S+", "")):lower()
      list[normalize_name] = latest_sha[1]:gsub("\tHEAD", "")
    end
  end
  require("lvim.utils").write_file(output, "local commit = " .. vim.inspect(list), "w")
end
return M
