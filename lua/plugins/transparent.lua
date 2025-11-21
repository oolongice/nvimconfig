return {
	"xiyaowong/transparent.nvim",
	lazy = false, -- Load immediately to prevent flashing
	config = function()
		require("transparent").setup({
			-- specific groups to make transparent (optional)
			extra_groups = {
				"NormalFloat", -- plugins which have floating panels
				"NvimTreeNormal", -- NvimTree
			},
		})
		require("transparent").clear_prefix("BufferLine")
		require("transparent").clear_prefix("NeoTree")
		require("transparent").clear_prefix("lualine")
	end,
}
