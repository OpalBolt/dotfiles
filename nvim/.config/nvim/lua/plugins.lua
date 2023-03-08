return {
	-- Theme, Nightfox
	{
	"EdenEast/nightfox.nvim",
	config = function()
		require("plugin_config.nightfox")
	end,
	},
	-- Glyphs
	{
		"nvim-tree/nvim-web-devicons",
		config = function()
			require("nvim-web-devicons").setup()
		end,
	},
	-- tree file browser

	{
		"nvim-tree/nvim-tree.lua",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			},
		tag = "nightly",
		config = function()
			require("plugin_config.nvim-tree")

		end,
	},
	-- preview markdown files in browser
	{
		"toppair/peek.nvim",
		build = "deno task --quiet build:fast",
		config = function()
			require("plugin_config.peek")
		end,
	},
	-- fuzzy finder
    {
		"nvim-telescope/telescope.nvim",
		dependencies = {
			{ "nvim-lua/popup.nvim" },
			{ "nvim-lua/plenary.nvim" },
		},
		config = function()
			require("plugin_config.telescope_settings")
			require("plugin_config.telescope")
		end,
	},
	-- better syntax highlighting
	{
		"nvim-treesitter/nvim-treesitter",
		config = function()
			require("plugin_config.treesitter")
		end,
		build = ":TSUpdate",
	},
	-- Line status bar.
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			require("plugin_config.lualine")
		end,
	},
    -- show git status in left editor gutter
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup()
		end,
	},
    {"tpope/vim-fugitive"},
    {
        "VonHeikemen/lsp-zero.nvim",
        branch = "v1.x",
        dependencies = {
            -- LSP Support
            {'williamboman/mason.nvim'},
            {'williamboman/mason-lspconfig.nvim'},
            {'neovim/nvim-lspconfig'},

            -- Autocompletion
            {'hrsh7th/nvim-cmp'},
            {'hrsh7th/cmp-buffer'},
            {'hrsh7th/cmp-path'},
            {'saadparwaiz1/cmp_luasnip'},
            {'hrsh7th/cmp-nvim-lsp'},
            {'hrsh7th/cmp-nvim-lua'},

            -- Snippets
            {'L3MON4D3/LuaSnip'},
            {'rafamadriz/friendly-snippets'},
        },
    },
} 
