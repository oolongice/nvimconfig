local function set_colorcolumn_hl()
	if vim.o.background == "dark" then
		vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#00aa00" })
	else
		vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#eee8d5" })
	end
end

set_colorcolumn_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
	group = vim.api.nvim_create_augroup("UserColorColumn", { clear = true }),
	callback = set_colorcolumn_hl,
})
