local M = {}
local Log = require "lvim.core.log"

local generic_opts_any = { noremap = true, silent = true }

local generic_opts = {
  insert_mode = generic_opts_any,
  normal_mode = generic_opts_any,
  visual_mode = generic_opts_any,
  visual_block_mode = generic_opts_any,
  command_mode = generic_opts_any,
  term_mode = { silent = true },
}

local mode_adapters = {
  insert_mode = "i",
  normal_mode = "n",
  term_mode = "t",
  visual_mode = "v",
  visual_block_mode = "x",
  command_mode = "c",
}

local defaults = {
  ---@usage change or add keymappings for insert mode
  insert_mode = {
    ['<C-s>']='<ESC>:w<CR>',

    ['<C-c>']='~<ESC>u',
    ['<C-q>']='~<ESC>u',


    ['<C-a>']='<HOME>',
    ['<C-e>']='<END>',
  },

  ---@usage change or add keymappings for normal mode
  normal_mode = {
    ['|']='J',
    ['?']='K',

    ['n']='nzz',
    ['N']='Nzz',

    ['<']='<<',
    ['>']='>>',

    ['<A-a>']='<C-a>',
    ['<A-x>']='<C-x>',

    [';']=':',
    ['<C-s>']=':w<CR>',
    ['<C-q>']=':q<CR>',
  },

  ---@usage change or add keymappings for terminal mode
  term_mode = {
    -- Terminal window navigation
    ["<C-h>"] = "<C-\\><C-N><C-w>h",
    ["<C-j>"] = "<C-\\><C-N><C-w>j",
    ["<C-k>"] = "<C-\\><C-N><C-w>k",
    ["<C-l>"] = "<C-\\><C-N><C-w>l",
  },

  ---@usage change or add keymappings for visual mode
  visual_mode = {
    -- Better indenting
    ["<"] = "<gv",
    [">"] = ">gv",
    ['<C-s>']= '<ESC>:w<CR>',
    ['Y']= '"+y',
    ['*']= ':normal gv"+y<CR>/\\V<C-r>"<CR>',

    -- ["p"] = '"0p',
    -- ["P"] = '"0P',
  },

  ---@usage change or add keymappings for visual block mode
  visual_block_mode = {
    ['<C-s>']='<ESC>:w<CR>',
    ['Y']='"+y',
    ['*']=':normal gv"+y<CR>/\\V<C-r>"<CR>',
  },

  ---@usage change or add keymappings for command mode
  command_mode = {
    ['<C-a>']='<HOME>',
    ['<C-e>']='<END>',
  },
}

if vim.fn.has "mac" == 1 then
  defaults.normal_mode["<A-Up>"] = defaults.normal_mode["<C-Up>"]
  defaults.normal_mode["<A-Down>"] = defaults.normal_mode["<C-Down>"]
  defaults.normal_mode["<A-Left>"] = defaults.normal_mode["<C-Left>"]
  defaults.normal_mode["<A-Right>"] = defaults.normal_mode["<C-Right>"]
  Log:debug "Activated mac keymappings"
end

-- Append key mappings to lunarvim's defaults for a given mode
-- @param keymaps The table of key mappings containing a list per mode (normal_mode, insert_mode, ..)
function M.append_to_defaults(keymaps)
  local default = M.get_defaults()
  lvim.keys = lvim.keys or default
  for mode, mappings in pairs(keymaps) do
    for k, v in pairs(mappings) do
      defaults[mode][k] = v
    end
  end
end

-- Unsets all keybindings defined in keymaps
-- @param keymaps The table of key mappings containing a list per mode (normal_mode, insert_mode, ..)
function M.clear(keymaps)
  local default = M.get_defaults()
  for mode, mappings in pairs(keymaps) do
    local translated_mode = mode_adapters[mode] or mode
    for key, _ in pairs(mappings) do
      -- some plugins may override default bindings that the user hasn't manually overridden
      if default[mode][key] ~= nil or (default[translated_mode] ~= nil and default[translated_mode][key] ~= nil) then
        pcall(vim.api.nvim_del_keymap, translated_mode, key)
      end
    end
  end
end

-- Unsets all keybindings defined in keymaps
-- @param keymaps The table of key mappings containing a list per mode (normal_mode, insert_mode, ..)
function M.clear(keymaps)
  local default = M.get_defaults()
  for mode, mappings in pairs(keymaps) do
    local translated_mode = mode_adapters[mode] and mode_adapters[mode] or mode
    for key, _ in pairs(mappings) do
      -- some plugins may override default bindings that the user hasn't manually overriden
      if default[mode][key] ~= nil or (default[translated_mode] ~= nil and default[translated_mode][key] ~= nil) then
        pcall(vim.api.nvim_del_keymap, translated_mode, key)
      end
    end
  end
end

-- Set key mappings individually
-- @param mode The keymap mode, can be one of the keys of mode_adapters
-- @param key The key of keymap
-- @param val Can be form as a mapping or tuple of mapping and user defined opt
function M.set_keymaps(mode, key, val)
  local opt = generic_opts[mode] or generic_opts_any
  if type(val) == "table" then
    opt = val[2]
    val = val[1]
  end
  if val then
    vim.api.nvim_set_keymap(mode, key, val, opt)
  else
    pcall(vim.api.nvim_del_keymap, mode, key)
  end
end

-- Load key mappings for a given mode
-- @param mode The keymap mode, can be one of the keys of mode_adapters
-- @param keymaps The list of key mappings
function M.load_mode(mode, keymaps)
  mode = mode_adapters[mode] or mode
  for k, v in pairs(keymaps) do
    M.set_keymaps(mode, k, v)
  end
end

-- Load key mappings for all provided modes
-- @param keymaps A list of key mappings for each mode
function M.load(keymaps)
  keymaps = keymaps or {}
  for mode, mapping in pairs(keymaps) do
    M.load_mode(mode, mapping)
  end
end

-- Load the default keymappings
function M.load_defaults()
  M.load(M.get_defaults())
  lvim.keys = {}
  for idx, _ in pairs(defaults) do
    lvim.keys[idx] = {}
  end
end

-- Get the default keymappings
function M.get_defaults()
  return defaults
end

return M