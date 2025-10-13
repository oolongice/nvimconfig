return {
	"stevearc/aerial.nvim",
	event = "VeryLazy",
	opts = {
		layout = {
			default_direction = "right",
			max_width = { 40, 0.3 },
		},
		attach_mode = "global",
		show_guide = true,
	},
	keys = {
		{ "<leader>a", "<cmd>AerialToggle! right<CR>", desc = "Toggle Aerial Outline" },
	},
}
