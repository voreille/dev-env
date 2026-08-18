local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

local function project_python()
  local candidates = {}

  if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
    table.insert(candidates, vim.env.VIRTUAL_ENV .. "/bin/python")
  end
  if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= "" then
    table.insert(candidates, vim.env.CONDA_PREFIX .. "/bin/python")
  end

  local local_venv = vim.fn.getcwd() .. "/.venv/bin/python"
  table.insert(candidates, local_venv)
  table.insert(candidates, vim.fn.expand("~/.local/share/dev-env/python-tools/bin/python"))
  table.insert(candidates, vim.fn.exepath("python3"))

  for _, python in ipairs(candidates) do
    if python and python ~= "" and vim.fn.executable(python) == 1 then
      return python
    end
  end
  return "python3"
end

local function debug_python()
  local candidates = {
    project_python(),
    vim.fn.expand("~/.local/share/dev-env/python-tools/bin/python"),
  }

  for _, python in ipairs(candidates) do
    if python and vim.fn.executable(python) == 1 then
      vim.fn.system({ python, "-c", "import debugpy" })
      if vim.v.shell_error == 0 then
        return python
      end
    end
  end

  return project_python()
end

local function add_remote_python_targets(dap)
  local spec = vim.env.DAP_PYTHON_TARGETS
  if not spec or spec == "" then return end

  dap.configurations.python = dap.configurations.python or {}
  for item in string.gmatch(spec, "[^,]+") do
    local name, host, port = item:match("^%s*([^=]+)=([^:]+):(%d+)%s*$")
    if name and host and port then
      table.insert(dap.configurations.python, {
        type = "python",
        request = "attach",
        name = "Attach: " .. name,
        connect = { host = host, port = tonumber(port) },
        justMyCode = false,
      })
    end
  end
end

require("lazy").setup({
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 300,
      spec = {
        { "<leader>c", group = "config/code" },
        { "<leader>d", group = "debug/diagnostics" },
        { "<leader>f", group = "find/files" },
        { "<leader>l", group = "LSP" },
      },
    },
  },

  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    keys = {
      { "<C-p>", function() require("fzf-lua").files() end, desc = "Find files" },
      { "<leader>ff", function() require("fzf-lua").files() end, desc = "Find files" },
      { "<leader>fg", function() require("fzf-lua").live_grep() end, desc = "Live grep" },
      { "<leader>fb", function() require("fzf-lua").buffers() end, desc = "Buffers" },
      { "<leader>fr", function() require("fzf-lua").oldfiles() end, desc = "Recent files" },
      { "<leader>p", function() require("fzf-lua").lsp_document_symbols() end, desc = "Document symbols" },
      { "<leader>fs", function() require("fzf-lua").lsp_document_symbols() end, desc = "Document symbols" },
      { "<leader>fS", function() require("fzf-lua").lsp_workspace_symbols() end, desc = "Workspace symbols" },
      { "<leader>cn", function()
          require("fzf-lua").files({
            cwd = vim.fn.stdpath("config"),
            prompt = "Neovim config> ",
          })
        end, desc = "Config: Neovim" },
    },
  },

  {
    "stevearc/oil.nvim",
    opts = {
      default_file_explorer = true,
      view_options = { show_hidden = false },
    },
    keys = {
      { "-", "<cmd>Oil<CR>", desc = "Parent directory" },
      { "<leader>fo", "<cmd>Oil<CR>", desc = "Oil" },
    },
  },

  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("dracula")
    end,
  },

  { "lewis6991/gitsigns.nvim", opts = {} },

  {
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      keymap = { preset = "default" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      signature = { enabled = true },
    },
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local python = project_python()

      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          python = {
            pythonPath = python,
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              typeCheckingMode = "standard",
            },
          },
        },
      })

      vim.lsp.config("ruff", { capabilities = capabilities })
      vim.lsp.enable("pyright")
      vim.lsp.enable("ruff")

      local format_group = vim.api.nvim_create_augroup("RuffFormatOnSave", { clear = true })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = format_group,
        pattern = "*.py",
        callback = function(args)
          vim.lsp.buf.format({
            bufnr = args.buf,
            async = false,
            filter = function(client) return client.name == "ruff" end,
          })
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
          vim.keymap.set("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "References" }))
          vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
          vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end,
            vim.tbl_extend("force", opts, { desc = "Format" }))
        end,
      })
    end,
  },

  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("dap-python").setup(debug_python())
      require("dap-python").test_runner = "pytest"
      add_remote_python_targets(dap)
      dapui.setup()

      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: continue/start" })
      vim.keymap.set("n", "<F9>", dap.toggle_breakpoint, { desc = "Debug: breakpoint" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug UI" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug REPL" })
      vim.keymap.set("n", "<leader>dt", function() require("dap-python").test_method() end, { desc = "Debug test method" })
    end,
  },
  {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    require("neo-tree").setup({
      filesystem = {
        follow_current_file = {
          enabled = true,
        },
        use_libuv_file_watcher = true,
      },
      window = {
            position = "left",
            width = 34,
        mappings = {
            ["l"] = "open",
            ["h"] = "close_node",
        },
      },
    })
  end,
  keys = {
    {
      "<leader>e",
      "<cmd>Neotree toggle filesystem reveal left<cr>",
      desc = "Explorer",
    },
   },
  },
}, {
  checker = { enabled = false },
  change_detection = { notify = false },
})
