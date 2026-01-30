-- nvim-tmux-cells.lua
-- A tiny Neovim plugin to send Python "cells" (split by lines that start with `#%%`)
-- to a specified tmux pane, similar to Spyder.

local M = {}

M.config = {
	target = nil, -- tmux target pane: session:window.pane
	send_enter = true, -- send an Enter key after pasting the buffer
	trim_leading_blank = true,
	method = "paste_buffer", -- or "send_keys" (fallback if paste shows blanks)
}

local function join(lines, sep)
	return table.concat(lines, sep or "\n")
end

local function lines_from_range(bufnr, srow, erow)
	local lines = vim.api.nvim_buf_get_lines(bufnr, srow - 1, erow, false)
	return lines
end

local function is_cell_marker(line)
	return line:match("^%s*#%%%%") ~= nil
end

local function find_cell_bounds(bufnr, cursor_row)
	local total = vim.api.nvim_buf_line_count(bufnr)
	local start_row = 1
	for i = cursor_row, 1, -1 do
		local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
		if i ~= cursor_row and is_cell_marker(l) then
			start_row = i + 1
			break
		end
		if i == 1 then
			start_row = 1
		end
	end
	local cur_line = vim.api.nvim_buf_get_lines(bufnr, cursor_row - 1, cursor_row, false)[1] or ""
	if is_cell_marker(cur_line) then
		start_row = cursor_row + 1
	end
	local end_row = total
	for i = cursor_row + 1, total do
		local l = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
		if is_cell_marker(l) then
			end_row = i - 1
			break
		end
	end
	if end_row < start_row then
		end_row = start_row
	end
	return start_row, end_row
end

local function ensure_target()
	local target = M.config.target
	if not target or target == "" then
		error("[nvim-tmux-cells] tmux target is not set. Use :TmuxSetTarget <session:window.pane>")
	end
	return target
end

local function tmux_available()
	return vim.fn.executable("tmux") == 1
end

local function write_tmpfile(text)
	local tmp = vim.fn.tempname()
	local fd = assert(io.open(tmp, "wb"))
	fd:write(text)
	fd:close()
	return tmp
end

local function tmux_paste(text)
	if not tmux_available() then
		error("[nvim-tmux-cells] tmux is not installed or not in PATH")
	end
	local target = ensure_target()

	if M.config.method == "send_keys" then
		for line in (text .. "\n"):gmatch("(.-)\n") do
			if line ~= "" then
				vim.fn.system({ "tmux", "send-keys", "-t", target, "-l", line })
			end
			vim.fn.system({ "tmux", "send-keys", "-t", target, "Enter" })
		end
		return
	end

	local tmp = write_tmpfile(text)
	local bufname = "nvim_tmux_cells"
	local load_cmd = { "tmux", "load-buffer", "-b", bufname, tmp }
	local paste_cmd = { "tmux", "paste-buffer", "-t", target, "-b", bufname, "-d", "-p" }

	local load_out = vim.fn.system(load_cmd)
	if vim.v.shell_error ~= 0 then
		os.remove(tmp)
		error("[nvim-tmux-cells] tmux load-buffer failed: " .. tostring(load_out))
	end
	local paste_out = vim.fn.system(paste_cmd)
	if vim.v.shell_error ~= 0 then
		os.remove(tmp)
		error("[nvim-tmux-cells] tmux paste-buffer failed: " .. tostring(paste_out))
	end
	if M.config.send_enter then
		vim.fn.system({ "tmux", "send-keys", "-t", target, "Enter" })
	end
	os.remove(tmp)
end

function M.send_current_cell()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local srow, erow = find_cell_bounds(bufnr, row)
	local lines = lines_from_range(bufnr, srow, erow)
	if M.config.trim_leading_blank then
		while #lines > 0 and lines[1]:match("^%s*$") do
			table.remove(lines, 1)
		end
	end
	local text = join(lines, "\n")
	if text == "" then
		vim.notify("[nvim-tmux-cells] Current cell is empty", vim.log.levels.WARN)
		return
	end
	local ok, err = pcall(tmux_paste, text)
	if not ok then
		vim.notify(err, vim.log.levels.ERROR)
	else
		vim.notify(string.format("[nvim-tmux-cells] Sent lines %d-%d to tmux", srow, erow))
	end
end

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function get_current_tmux_id()
	-- 关键判断：如果环境变量 TMUX 为空，说明当前 Neovim 不在 Tmux 内部
	if not vim.env.TMUX or vim.env.TMUX == "" then
		return nil
	end

	-- 只有确认在 Tmux 内部时，才查询 ID
	-- -p 意味着只输出信息，不显示在状态栏
	local cmd = { "tmux", "display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}" }
	local id = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		return nil
	end

	-- 去除换行符
	return (id:gsub("^%s*(.-)%s*$", "%1"))
end

function M.select_target()
	if not tmux_available() then
		vim.notify("[nvim-tmux-cells] tmux not found", vim.log.levels.ERROR)
		return
	end

	-- 1. 获取 Tmux 面板列表
	-- -a: 列出所有会话
	-- -F: 自定义格式。我们要构建一个特殊的字符串方便后续解析： "ID|描述"
	-- 格式解释： #{session_name}:#{window_index}.#{pane_index} 是目标ID
	--            #{pane_current_command} 是正在运行的程序
	--            #{window_name} 是窗口名
	local format_str =
		"#{session_name}:#{window_index}.#{pane_index}|[#{session_name}] #{window_name} (cmd: #{pane_current_command})"
	local cmd = { "tmux", "list-panes", "-a", "-F", format_str }

	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		vim.notify("[nvim-tmux-cells] Failed to list tmux panes", vim.log.levels.ERROR)
		return
	end
	local current_pane_id = get_current_tmux_id()
	-- 2. 解析输出并准备列表
	local items = {}
	for line in output:gmatch("[^\r\n]+") do
		local id = line:match("^(.-)|")

		-- 过滤逻辑：
		-- 如果 current_pane_id 存在（即我们在 Tmux 里），且等于列表中的 id，则跳过
		if current_pane_id and id == current_pane_id then
		-- 这是一个“当前所在 Pane”，跳过它，不加入列表
		else
			table.insert(items, line)
		end
	end

	if #items == 0 then
		vim.notify("[nvim-tmux-cells] No other tmux panes found", vim.log.levels.WARN)
		return
	end
	-- 3. 调用 vim.ui.select
	vim.ui.select(items, {
		prompt = "Select Tmux Target Pane:",
		-- 格式化显示的文本（只显示 | 后面的描述部分，隐藏 ID）
		format_item = function(item)
			local _, desc = item:match("^(.-)|(.*)$")
			return desc or item
		end,
	}, function(choice)
		-- 回调函数：当用户选择后执行
		if choice then
			local target_id = choice:match("^(.-)|")
			if target_id then
				M.set_target(target_id)
			end
		end
	end)
end

function M.set_target(target)
	M.config.target = target
	vim.notify("[nvim-tmux-cells] tmux target set to " .. tostring(target))
end

function M.show_target()
	vim.notify("[nvim-tmux-cells] tmux target: " .. tostring(M.config.target or "<unset>"))
end

function M.debug_current_cell_text()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local srow, erow = find_cell_bounds(bufnr, row)
	local lines = lines_from_range(bufnr, srow, erow)
	local text = table.concat(lines, "\n")
	vim.notify(string.format("cell %d-%d (len=%d)\n---\n%s", srow, erow, #text, text))
end

function M.setup(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
	vim.api.nvim_create_user_command("TmuxSetTarget", function(o)
		M.set_target(o.args)
	end, { nargs = 1 })
	vim.api.nvim_create_user_command("TmuxSelect", function()
		M.select_target()
	end, {})
	vim.api.nvim_create_user_command("TmuxShowTarget", function()
		M.show_target()
	end, {})
	vim.api.nvim_create_user_command("TmuxSendCell", function()
		M.send_current_cell()
	end, {})
end

return M
