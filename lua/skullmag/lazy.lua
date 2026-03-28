local uv = vim.uv or vim.loop
local default_lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local fallback_lazypath = (vim.env.HOME or "") .. "/.local/share/nvim/lazy/lazy.nvim"
local lazypath = default_lazypath

if not uv.fs_stat(lazypath) and uv.fs_stat(fallback_lazypath) then
  lazypath = fallback_lazypath
end

if not uv.fs_stat(lazypath) then
  local clone_output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })

  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { clone_output, "WarningMsg" },
    }, true, {})
    error("failed to clone lazy.nvim")
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup("skullmag.plugins", {
  change_detection = {
    notify = false,
  },
})
