local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		error("Failed to clone lazy.nvim:\n" .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

local dev_prefix = vim.env.DEV_ENV_PREFIX or vim.fn.expand("~/.local")
local python_tools = dev_prefix .. "/share/dev-env/python-tools/bin/python"

local function executable(path)
	return path and path ~= "" and vim.fn.executable(path) == 1
end

local function project_python()
	local candidates = {}
	if vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
		table.insert(candidates, vim.env.VIRTUAL_ENV .. "/bin/python")
	end
	if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= "" then
		table.insert(candidates, vim.env.CONDA_PREFIX .. "/bin/python")
	end
	table.insert(candidates, vim.fn.getcwd() .. "/.venv/bin/python")
	table.insert(candidates, python_tools)
	table.insert(candidates, vim.fn.exepath("python3"))

	for _, python in ipairs(candidates) do
		if executable(python) then
			return python
		end
	end
	return "python3"
end

local function debug_python()
	for _, python in ipairs({ project_python(), python_tools }) do
		if executable(python) then
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
	if not spec or spec == "" then
		return
	end

	dap.configurations.python = dap.configurations.python or {}
	for item in spec:gmatch("[^,]+") do
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
			{
				"<C-p>",
				function()
					require("fzf-lua").files()
				end,
				desc = "Find files",
			},
			{
				"<leader>ff",
				function()
					require("fzf-lua").files()
				end,
				desc = "Find files",
			},
			{
				"<leader>fg",
				function()
					require("fzf-lua").live_grep()
				end,
				desc = "Live grep",
			},
			{
				"<leader>b",
				function()
					require("fzf-lua").buffers()
				end,
				desc = "Buffers",
			},
			{
				"<leader>fr",
				function()
					require("fzf-lua").oldfiles()
				end,
				desc = "Recent files",
			},
			{
				"<leader>p",
				function()
					require("fzf-lua").lsp_document_symbols()
				end,
				desc = "All document symbols",
			},
			{
				"<leader>fs",
				function()
					require("fzf-lua").lsp_document_symbols()
				end,
				desc = "Document symbols",
			},
			{
				"<leader>fS",
				function()
					require("fzf-lua").lsp_workspace_symbols()
				end,
				desc = "Workspace symbols",
			},
			{
				"<leader>cn",
				function()
					require("fzf-lua").files({
						cwd = vim.fn.stdpath("config"),
						prompt = "Neovim config> ",
					})
				end,
				desc = "Config: Neovim",
			},
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
		priority = 1000,
		config = function()
			vim.cmd.colorscheme("dracula")

			local highlights = {
				Function = { fg = "#50fa7b" },
				["@function"] = { fg = "#50fa7b" },
				["@function.call"] = { fg = "#50fa7b" },
				["@function.method"] = { fg = "#50fa7b" },
				["@function.method.call"] = { fg = "#50fa7b" },
				["@lsp.type.function.python"] = { fg = "#50fa7b" },
				["@lsp.type.method.python"] = { fg = "#50fa7b" },

				["@variable.parameter"] = {
					fg = "#ffb86c",
					italic = true,
				},
				["@lsp.type.parameter.python"] = {
					fg = "#ffb86c",
					italic = true,
				},

				["@type"] = { fg = "#8be9fd" },
				["@type.builtin"] = { fg = "#8be9fd" },
				["@type.definition"] = { fg = "#8be9fd" },
				["@constructor"] = { fg = "#8be9fd" },
				["@lsp.type.class.python"] = { fg = "#8be9fd" },

				["@variable.builtin"] = {
					fg = "#bd93f9",
					italic = true,
				},
				["@variable.member"] = { fg = "#8be9fd" },
				["@property"] = { fg = "#8be9fd" },

				-- Floating completion and signature windows.
				DevPopup = {
					fg = "#f8f8f2",
					bg = "#343746",
				},
				DevPopupBorder = {
					fg = "#bd93f9",
					bg = "#343746",
				},
				DevPopupSelection = {
					fg = "#f8f8f2",
					bg = "#44475a",
					bold = true,
				},
			}

			for group, opts in pairs(highlights) do
				vim.api.nvim_set_hl(0, group, opts)
			end
		end,
	},

	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },

		opts = {
			signcolumn = true,
			numhl = true,
			linehl = false,
		},

		keys = {
			{
				"]h",
				function()
					require("gitsigns").nav_hunk("next")
				end,
				desc = "Next git hunk",
			},
			{
				"[h",
				function()
					require("gitsigns").nav_hunk("prev")
				end,
				desc = "Previous git hunk",
			},
			{
				"<leader>gp",
				function()
					require("gitsigns").preview_hunk()
				end,
				desc = "Preview git hunk",
			},
			{
				"<leader>gs",
				function()
					require("gitsigns").stage_hunk()
				end,
				desc = "Stage git hunk",
			},
			{
				"<leader>gr",
				function()
					require("gitsigns").reset_hunk()
				end,
				desc = "Reset git hunk",
			},
			{
				"<leader>gb",
				function()
					require("gitsigns").blame_line()
				end,
				desc = "Git blame line",
			},
			{
				"<leader>gd",
				function()
					require("gitsigns").diffthis(nil, { vertical = true })
				end,
				desc = "Git diff file",
			},
			{
				"<leader>gD",
				function()
					require("gitsigns").diffthis("~1", { vertical = true })
				end,
				desc = "Git diff file against HEAD",
			},
		},
	},
	{
		"saghen/blink.cmp",
		version = "1.*",

		opts = {
			keymap = { preset = "default" },

			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},

			completion = {
				menu = {
					border = "rounded",
					winblend = 0,
					winhighlight = table.concat({
						"Normal:DevPopup",
						"FloatBorder:DevPopupBorder",
						"CursorLine:DevPopupSelection",
						"Search:None",
					}, ","),
				},

				documentation = {
					auto_show = true,
					auto_show_delay_ms = 300,

					window = {
						border = "rounded",
						winblend = 0,
						winhighlight = table.concat({
							"Normal:DevPopup",
							"FloatBorder:DevPopupBorder",
							"CursorLine:DevPopupSelection",
							"Search:None",
						}, ","),
					},
				},
			},

			signature = {
				enabled = true,

				window = {
					border = "rounded",
					winblend = 0,
					winhighlight = table.concat({
						"Normal:DevPopup",
						"FloatBorder:DevPopupBorder",
					}, ","),
				},
			},
		},
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp" },
		config = function()
			local capabilities = require("blink.cmp").get_lsp_capabilities()

			vim.lsp.config("pyright", {
				capabilities = capabilities,
				before_init = function(_, config)
					config.settings.python.pythonPath = project_python()
				end,
				settings = {
					python = {
						pythonPath = project_python(),
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							typeCheckingMode = "standard",
						},
					},
				},
			})
			vim.lsp.config("ruff", { capabilities = capabilities })
			vim.lsp.enable({ "pyright", "ruff" })

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("DevEnvLspMaps", { clear = true }),
				callback = function(args)
					local function lsp_map(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
					end
					lsp_map("gd", vim.lsp.buf.definition, "Go to definition")
					lsp_map("gD", vim.lsp.buf.declaration, "Go to declaration")
					lsp_map("gr", vim.lsp.buf.references, "References")
					lsp_map("K", vim.lsp.buf.hover, "Hover")
					lsp_map("<leader>rn", vim.lsp.buf.rename, "Rename")
					lsp_map("<leader>ca", vim.lsp.buf.code_action, "Code action")
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
			local dap_python = require("dap-python")
			local map = vim.keymap.set

			dap_python.setup(debug_python())
			dap_python.test_runner = "pytest"
			add_remote_python_targets(dap)

			dapui.setup({
				expand_lines = false,

				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.30 },
							{ id = "stacks", size = 0.30 },
							{ id = "breakpoints", size = 0.20 },
							{ id = "watches", size = 0.20 },
						},
						position = "left",
						size = 40,
					},
					{
						elements = {
							{ id = "repl", size = 0.50 },
							{ id = "console", size = 0.50 },
						},
						position = "bottom",
						size = 15,
					},
				},
			})

			-- Make the stopped line clearly visible using the colorscheme.
			vim.api.nvim_set_hl(0, "DapStoppedLine", {
				link = "Visual",
			})

			vim.fn.sign_define("DapStopped", {
				text = "▶",
				texthl = "DiagnosticOk",
				linehl = "DapStoppedLine",
				numhl = "DapStoppedLine",
			})

			local function open_debug_ui()
				pcall(vim.cmd, "Neotree close")
				dapui.open()
			end

			local has_last_debug_config = false

			dap.listeners.after.event_initialized["dapui_config"] = function()
				has_last_debug_config = true
				open_debug_ui()
			end

			local function focus_dap_element(element)
				dapui.open({ layout = 2 })

				local buffer = dapui.elements[element].buffer()
				local window = vim.fn.bufwinid(buffer)

				if window ~= -1 then
					vim.api.nvim_set_current_win(window)
					vim.cmd.startinsert()
				end
			end
			local function continue_or_run_last()
				if dap.session() then
					dap.continue()
				elseif has_last_debug_config then
					dap.run_last()
				else
					dap.continue()
				end
			end

			map("n", "<leader>dc", continue_or_run_last, {
				desc = "Debug: continue/run last",
			})

			map("n", "<leader>dC", dap.continue, {
				desc = "Debug: choose configuration",
			})

			map("n", "<leader>db", dap.toggle_breakpoint, {
				desc = "Debug: breakpoint",
			})

			map("n", "<leader>do", dap.step_over, {
				desc = "Debug: step over",
			})

			map("n", "<leader>di", dap.step_into, {
				desc = "Debug: step into",
			})

			map("n", "<leader>dO", dap.step_out, {
				desc = "Debug: step out",
			})

			map("n", "<leader>du", dapui.toggle, {
				desc = "Debug: toggle UI",
			})

			map("n", "<leader>dr", function()
				focus_dap_element("repl")
			end, {
				desc = "Debug: focus REPL",
			})

			map("n", "<leader>dC", function()
				focus_dap_element("console")
			end, {
				desc = "Debug: focus console",
			})

			map("n", "<leader>dt", dap_python.test_method, {
				desc = "Debug: test method",
			})
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
		opts = {
			filesystem = {
				follow_current_file = { enabled = true },
				use_libuv_file_watcher = true,
			},
			window = {
				position = "left",
				width = 34,
				mappings = {
					["l"] = "open",
					["h"] = "close_node",
					["Y"] = function(state)
						local node = state.tree:get_node()
						local path = node:get_id()

						-- Yank to both Neovim and the system clipboard.
						vim.fn.setreg('"', path)
						vim.fn.setreg("+", path)

						vim.notify("Yanked: " .. path)
					end,
				},
			},
		},
		keys = {
			{ "<leader>e", "<cmd>Neotree toggle filesystem reveal left<CR>", desc = "Explorer" },
		},
	},

	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				python = { "ruff_organize_imports", "ruff_format" },
				lua = { "stylua" },
				yaml = { "yamlfmt" },
				java = { "google-java-format" },
				sh = { "shfmt" },
				bash = { "shfmt" },
			},
			format_on_save = function(bufnr)
				if vim.bo[bufnr].filetype == "python" then
					return { timeout_ms = 3000, lsp_format = "fallback" }
				end
			end,
		},
		keys = {
			{
				"<leader>lf",
				function()
					require("conform").format({ async = true, lsp_format = "fallback" })
				end,
				desc = "Format file",
			},
		},
	},

	{
		"hat0uma/csvview.nvim",
		cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
		opts = {
			parser = { comments = { "#", "//" } },
			keymaps = {
				textobject_field_inner = { "if", mode = { "o", "x" } },
				textobject_field_outer = { "af", mode = { "o", "x" } },
				jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
				jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
			},
		},
	},

	{
		"mason-org/mason.nvim",
		opts = {
			-- Prefer bootstrap-managed binaries over Mason shims.
			PATH = "append",
		},
	},

	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "mason-org/mason.nvim" },
		opts = {
			ensure_installed = {
				"stylua",
				"yamlfmt",
				"google-java-format",
				"shfmt",
			},
		},
	},

	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate lua python bash yaml json markdown markdown_inline",
		init = function()
			-- tree-sitter-lua uses main; apply this before Lazy's build command.
			vim.api.nvim_create_autocmd("User", {
				pattern = "TSUpdate",
				callback = function()
					require("nvim-treesitter.parsers").lua.install_info.revision = "main"
				end,
			})
		end,
		config = function()
			local treesitter = require("nvim-treesitter")
			require("nvim-treesitter.parsers").lua.install_info.revision = "main"

			treesitter.install({
				"lua",
				"python",
				"bash",
				"yaml",
				"json",
				"markdown",
				"markdown_inline",
			})

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("DevEnvTreesitter", { clear = true }),
				pattern = { "python", "lua", "bash", "sh", "yaml", "json", "markdown" },
				callback = function(args)
					-- A parser can still be downloading on first launch; do not abort BufRead.
					pcall(vim.treesitter.start, args.buf)
				end,
			})
		end,
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {},
	},
	{
		"github/copilot.vim",
		event = "InsertEnter",
	},

	{
		"stevearc/aerial.nvim",
		opts = {
			highlight_on_hover = true,

			-- Full outline: AerialToggle float
			keymaps = {
				["<Esc>"] = "actions.close",
			},

			-- Compact navigator: AerialNavToggle
			nav = {
				keymaps = {
					["<Esc>"] = "actions.close",
					["q"] = "actions.close",
				},
			},
		},
		keys = {
			{
				"<leader>o",
				"<cmd>AerialToggle float<CR>",
				desc = "Document outline",
			},
		},
	},
}, {
	checker = { enabled = false },
	change_detection = { notify = false },
})
