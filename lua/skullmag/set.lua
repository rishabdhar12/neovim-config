vim.opt.guicursor = table.concat({
  "n-v-c:block-Cursor",
  "i-ci-ve:block-Cursor",
  "r-cr:hor20-Cursor",
  "o:hor50-Cursor",
  -- "a:blinkwait700-blinkoff400-blinkon250",
}, ",")

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = true

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50
vim.opt.completeopt = { "menu", "menuone", "noselect" }

vim.opt.colorcolumn = "120"

local function set_cursor_highlight()
  vim.api.nvim_set_hl(0, "Cursor", {
    fg = "#101010",
    bg = "#696969",
    -- blend = 70,
    nocombine = true,
  })
  vim.api.nvim_set_hl(0, "lCursor", { link = "Cursor" })
  vim.api.nvim_set_hl(0, "CursorIM", { link = "Cursor" })
end

local function set_pitch_black_background()
  local black = "#000000"
  local highlight_groups = {
    "Normal",
    "NormalNC",
    "SignColumn",
    "FoldColumn",
    "EndOfBuffer",
    "NormalFloat",
    "FloatBorder",
    "Pmenu",
  }

  for _, group in ipairs(highlight_groups) do
    vim.api.nvim_set_hl(0, group, { bg = black })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    set_cursor_highlight()
    set_pitch_black_background()
  end,
})

vim.opt.background = "dark"
-- vim.cmd.colorscheme("default")
set_cursor_highlight()
set_pitch_black_background()
