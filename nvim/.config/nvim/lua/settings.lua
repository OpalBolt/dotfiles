--local vim = vim

-- Do not hide code
vim.o.conceallevel = 0

-- disable spellchecker by default
vim.o.spell = false

-- enable spellcheck when opening specific file types
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown,tex,latex",
	callback = function()
		vim.o.spell = true
	end,
})

-- split screen directions
vim.o.splitbelow = true
vim.o.splitright = true

-- autosave times
vim.o.updatetime = 250

-- Move curser to search hit when searching
vim.o.incsearch = true

-- Ignore case while searching
vim.o.ignorecase = true

-- Match case if capital letter is used in search
vim.o.smartcase = true

-- set tabs in spaces
vim.o.tabstop = 4
vim.o.shiftwidth = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

-- Highlight matching brackets
vim.o.showmatch = true

-- Display what mode you are editing in
vim.o.showmode = false

-- Diplay current commmand
vim.o.showcmd = true

-- faster scrolling
vim.o.lazyredraw = true

-- ensure that there is room around current line
vim.o.scrolloff = 8

-- enable line numbers and relative line numbers
vim.o.number = true
vim.o.relativenumber = true

-- highlight current line
vim.o.cursorline = true

-- use all colors in terminal
vim.o.termguicolors = true
