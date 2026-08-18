local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.breakindent = true
opt.undofile = true
opt.ignorecase = true
opt.smartcase = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 5
opt.sidescrolloff = 5
opt.completeopt = { "menu", "menuone", "noselect" }
opt.termguicolors = true

-- Coding defaults. Python and most source files use 4 spaces; YAML uses 2.
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
