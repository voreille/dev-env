local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit" })

-- Edit dev-env configuration. ~/.config/dev-env/bashrc is a symlink back to
-- this repository, so edits remain version controlled.
map("n", "<leader>cb", function()
  vim.cmd.edit(vim.fn.expand("~/.config/dev-env/bashrc"))
end, { desc = "Config: bash" })

-- Window movement.
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Keep selected text selected while indenting.
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Diagnostics. Keep Vim-style mappings, but provide QWERTZ-friendly leader
-- alternatives because [ and ] are awkward on many Swiss keyboards.
map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Next diagnostic" })
map("n", "<leader>dp", function() vim.diagnostic.jump({ count = -1, float = true }) end, { desc = "Diagnostic: previous" })
map("n", "<leader>dn", function() vim.diagnostic.jump({ count = 1, float = true }) end, { desc = "Diagnostic: next" })
map("n", "<leader>de", vim.diagnostic.open_float, { desc = "Diagnostic: details" })
