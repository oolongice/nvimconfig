return {
	{
		dir = vim.fn.stdpath("config") .. "/myplugins/nvim-tmux-cells", -- 指向上面的本地目录
		name = "nvim-tmux-cells",
		-- 想要懒加载可以用 keys/cmd 触发；先简单起见直接加载：
		lazy = false,
		config = function()
			require("nvim-tmux-cells").setup({
				target = "0:1.0",
				send_enter = true,
				trim_leading_blank = true,
			})
		end,
	},
}
