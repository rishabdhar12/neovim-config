return {
  {
    "blazkowolf/gruber-darker.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("gruber-darker")
    end,
  },
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        "<leader>ff",
        function()
          require("telescope.builtin").find_files()
        end,
        desc = "Telescope find files",
      },
      {
        "<leader>/",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Telescope live grep",
      },
      {
        "<leader>b",
        function()
          require("telescope.builtin").buffers()
        end,
        desc = "Telescope buffers",
      },
      {
        "<leader>fh",
        function()
          require("telescope.builtin").help_tags()
        end,
        desc = "Telescope help tags",
      },
    },
  },
  {
    "folke/trouble.nvim",
    cmd = {
      "Trouble",
      "TroubleToggle",
    },
    keys = {
      {
        "<leader>xq",
        "<cmd>TroubleToggle quickfix<cr>",
        silent = true,
        noremap = true,
      },
    },
    opts = {
      icons = false,
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      {
        "nvim-treesitter/playground",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
      },
      {
        "nvim-treesitter/nvim-treesitter-context",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
      },
    },
    config = function()
      local parser_install_dir = vim.fn.stdpath("data") .. "/site"
      vim.opt.runtimepath:prepend(parser_install_dir)

      require("nvim-treesitter.configs").setup({
        parser_install_dir = parser_install_dir,
        ensure_installed = {
          "bash",
          "c",
          "dart",
          "go",
          "java",
          "javascript",
          "json",
          "kotlin",
          "lua",
          "python",
          "rust",
          "toml",
          "tsx",
          "typescript",
          "vim",
          "xml",
          "yaml",
        },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("conform").setup({
        notify_on_error = true,
        formatters_by_ft = {
          kotlin = { "ktlint" },
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local lint = require("lint")
      local lint_group = vim.api.nvim_create_augroup("SkullmagLint", { clear = true })

      lint.linters_by_ft = {
        kotlin = { "ktlint" },
      }

      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = lint_group,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = false,
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = {
          "nvim-neotest/nvim-nio",
        },
      },
      {
        "theHamsta/nvim-dap-virtual-text",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local android = require("skullmag.android")
      local adapter_path = vim.fn.exepath("kotlin-debug-adapter")

      dapui.setup({})
      require("nvim-dap-virtual-text").setup({})

      vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "R", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapLogPoint", { text = "L", texthl = "DiagnosticInfo" })

      dap.listeners.after.event_initialized["skullmag_dapui"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["skullmag_dapui"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["skullmag_dapui"] = function()
        dapui.close()
      end

      dap.adapters.kotlin = {
        type = "executable",
        command = adapter_path ~= "" and adapter_path or "kotlin-debug-adapter",
      }

      dap.configurations.kotlin = {
        {
          type = "kotlin",
          request = "launch",
          name = "Launch current Kotlin file",
          projectRoot = "${workspaceFolder}",
          mainClass = function()
            return vim.fn.input("Kotlin main class: ", android.guess_kotlin_main_class())
          end,
        },
        {
          type = "kotlin",
          request = "attach",
          name = "Attach on localhost:5005",
          projectRoot = "${workspaceFolder}",
          hostName = "127.0.0.1",
          port = 5005,
          timeout = 5000,
        },
      }

      dap.configurations.java = vim.deepcopy(dap.configurations.kotlin)
    end,
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<CR>" },
    },
  },
  {
    "tpope/vim-fugitive",
    cmd = "Git",
    keys = {
      { "<leader>gs", "<cmd>Git<CR>" },
    },
    config = function()
      local fugitive_group = vim.api.nvim_create_augroup("ThePrimeagen_Fugitive", {})

      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = fugitive_group,
        pattern = "*",
        callback = function()
          if vim.bo.ft ~= "fugitive" then
            return
          end

          local bufnr = vim.api.nvim_get_current_buf()
          local opts = { buffer = bufnr, remap = false }

          vim.keymap.set("n", "<leader>p", function()
            vim.cmd.Git("push")
          end, opts)

          vim.keymap.set("n", "<leader>P", function()
            vim.cmd.Git({ "pull", "--rebase" })
          end, opts)

          vim.keymap.set("n", "<leader>t", ":Git push -u origin ", opts)
        end,
      })
    end,
  },
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      {
        "<leader>nn",
        function()
          require("refactoring").refactor("Inline Variable")
        end,
        mode = "n",
      },
    },
    config = function()
      require("refactoring").setup({})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "saadparwaiz1/cmp_luasnip",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lua",
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local cmp_select = { behavior = cmp.SelectBehavior.Select }
      local mason_registry = require("mason-registry")

      local function ensure_mason_packages(package_names)
        for _, package_name in ipairs(package_names) do
          local ok, package = pcall(mason_registry.get_package, package_name)
          if ok and not package:is_installed() then
            package:install()
          end
        end
      end

      require("luasnip.loaders.from_vscode").lazy_load()
      require("mason").setup()
      mason_registry.refresh(function()
        ensure_mason_packages({
          "kotlin-language-server",
          "kotlin-debug-adapter",
          "ktlint",
        })
      end)

      require("mason-lspconfig").setup({
        ensure_installed = { "eslint", "lemminx", "lua_ls", "rust_analyzer" },
        automatic_enable = false,
      })

      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, remap = false }

        vim.keymap.set("n", "gd", function()
          vim.lsp.buf.definition()
        end, opts)
        vim.keymap.set("n", "K", function()
          vim.lsp.buf.hover()
        end, opts)
        vim.keymap.set("n", "<leader>vws", function()
          vim.lsp.buf.workspace_symbol()
        end, opts)
        vim.keymap.set("n", "<leader>vd", function()
          vim.diagnostic.open_float()
        end, opts)
        vim.keymap.set("n", "[d", function()
          vim.diagnostic.goto_next()
        end, opts)
        vim.keymap.set("n", "]d", function()
          vim.diagnostic.goto_prev()
        end, opts)
        vim.keymap.set("n", "<leader>vca", function()
          vim.lsp.buf.code_action()
        end, opts)
        vim.keymap.set("n", "<leader>vrr", function()
          vim.lsp.buf.references()
        end, opts)
        vim.keymap.set("n", "<leader>vrn", function()
          vim.lsp.buf.rename()
        end, opts)
        vim.keymap.set("i", "<C-h>", function()
          vim.lsp.buf.signature_help()
        end, opts)

        if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end

        if client:supports_method(vim.lsp.protocol.Methods.textDocument_codeLens) then
          local code_lens_group = vim.api.nvim_create_augroup("SkullmagCodeLens" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "InsertLeave" }, {
            group = code_lens_group,
            buffer = bufnr,
            callback = function()
              pcall(vim.lsp.codelens.refresh)
            end,
          })
        end
      end

      vim.lsp.config("*", {
        capabilities = capabilities,
        on_attach = on_attach,
      })

      vim.lsp.config("kotlin_language_server", {
        settings = {
          kotlin = {
            completion = {
              snippets = {
                enabled = true,
              },
            },
            debugAdapter = {
              enabled = true,
              path = vim.fn.exepath("kotlin-debug-adapter"),
            },
            diagnostics = {
              enabled = true,
              level = "hint",
            },
            externalSources = {
              useKlsScheme = true,
            },
            indexing = {
              enabled = true,
            },
            inlayHints = {
              chainedHints = true,
              parameterHints = true,
              typeHints = true,
            },
            java = {
              home = vim.env.JAVA_HOME or "",
            },
            scripts = {
              buildScriptsEnabled = true,
              enabled = true,
            },
          },
        },
      })

      vim.lsp.config("lemminx", {})

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            telemetry = {
              enable = false,
            },
            workspace = {
              checkThirdParty = false,
            },
          },
        },
      })

      vim.lsp.enable({ "eslint", "kotlin_language_server", "lemminx", "lua_ls", "rust_analyzer" })

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-p>"] = cmp.mapping.select_prev_item(cmp_select),
          ["<C-n>"] = cmp.mapping.select_next_item(cmp_select),
          ["<Up>"] = cmp.mapping.select_prev_item(cmp_select),
          ["<Down>"] = cmp.mapping.select_next_item(cmp_select),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item(cmp_select)
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item(cmp_select)
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<C-y>"] = cmp.mapping.confirm({ select = true }),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "nvim_lua" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })

      vim.diagnostic.config({
        severity_sort = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        virtual_text = {
          prefix = "*",
          spacing = 2,
          source = "if_many",
        },
        float = {
          border = "rounded",
          source = "if_many",
        },
      })
    end,
  },
}
