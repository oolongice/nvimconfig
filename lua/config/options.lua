-- Options are automatically loaded before lazy.nvim startup
local opt = vim.opt

opt.colorcolumn = "81"
opt.termguicolors = true
opt.relativenumber = false

opt.wrap = true
opt.linebreak = true
opt.breakindent = true
opt.showbreak = "↪ "

vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")
