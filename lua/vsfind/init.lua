-- VSCode-style find box: floating input at the top-right of the window,
-- live highlighting, "N of M" count and case / whole-word / regex toggles.
local M = {}

local MAX_COUNT = 999
local opts = { case = false, word = false, regex = false }
local state

local function build_pattern(query)
  if query == '' then return nil end
  local pat
  if opts.regex then
    pat = opts.word and ('\\v<%(' .. query .. ')>') or ('\\v' .. query)
  else
    pat = '\\V' .. vim.fn.escape(query, '\\')
    if opts.word then pat = '\\V\\<' .. pat:sub(3) .. '\\>' end
  end
  return pat .. (opts.case and '\\C' or '\\c')
end

local function render(count)
  local toggle = function(on, label) return { ' ' .. label .. ' ', on and 'VsFindToggleOn' or 'Comment' } end
  local num = function(n) return n > MAX_COUNT and MAX_COUNT .. '+' or tostring(n) end
  local status
  if state.invalid then
    status = { 'Invalid pattern', 'DiagnosticError' }
  elseif not state.pattern then
    status = { 'No results', 'Comment' }
  elseif count.total == 0 then
    status = { 'No results', 'DiagnosticError' }
  else
    status = { num(count.current) .. ' of ' .. num(count.total), 'Comment' }
  end
  -- footer, not virt text, so long queries aren't covered
  vim.api.nvim_win_set_config(state.input, {
    footer = { status, { ' ' }, toggle(opts.case, 'Aa'), toggle(opts.word, 'ab'), toggle(opts.regex, '.*') },
    footer_pos = 'right',
  })
end

-- Runs search() in the target window; `from_origin` restarts at the open position.
local function update(flags, from_origin)
  local query = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1] or ''
  state.pattern = build_pattern(query)
  state.invalid = false
  local count = { current = 0, total = 0 }
  vim.api.nvim_win_call(state.win, function()
    if from_origin then vim.api.nvim_win_set_cursor(0, state.origin) end
    if not state.pattern then return end
    local ok, found = pcall(vim.fn.search, state.pattern, flags)
    if not ok then
      state.pattern = nil
      state.invalid = true
      return
    end
    -- set_cursor scrolls the (non-focused) target window to the match
    vim.api.nvim_win_set_cursor(0, found == 0 and state.origin or vim.api.nvim_win_get_cursor(0))
    if found ~= 0 then vim.cmd('normal! zv') end
    vim.fn.setreg('/', state.pattern)
    local c = vim.fn.searchcount({ pattern = state.pattern, maxcount = MAX_COUNT, timeout = 100, recompute = true })
    count = { current = c.current or 0, total = c.total or 0 }
  end)
  if not state.pattern then vim.fn.setreg('/', state.prev_search) end
  render(count)
end

local function close()
  if not state then return end
  local s = state
  state = nil
  local was_current = vim.api.nvim_get_current_win() == s.input
  if vim.api.nvim_win_is_valid(s.input) then vim.api.nvim_win_close(s.input, true) end
  vim.o.hlsearch = s.hlsearch
  -- leaving insert mode nudges the cursor left; put it back on the match
  local pos = vim.api.nvim_win_is_valid(s.win) and vim.api.nvim_win_get_cursor(s.win)
  vim.cmd.stopinsert()
  vim.schedule(function()
    if pos and vim.api.nvim_win_is_valid(s.win) then vim.api.nvim_win_set_cursor(s.win, pos) end
  end)
  if s.pattern then
    vim.fn.histadd('/', s.pattern)
    vim.v.searchforward = 1
  end
  if was_current and vim.api.nvim_win_is_valid(s.win) then vim.api.nvim_set_current_win(s.win) end
end

function M.open()
  if state then
    vim.api.nvim_set_current_win(state.input)
    return
  end
  -- seed with a single-line visual selection and search from its start
  local seed
  local mode = vim.fn.mode()
  if mode:match('^[vV\22]') then
    local lines = vim.fn.getregion(vim.fn.getpos('v'), vim.fn.getpos('.'), { type = mode })
    if #lines == 1 then seed = lines[1] end
    vim.cmd.normal({ vim.keycode('<Esc>'), bang = true })
    vim.api.nvim_win_set_cursor(0, { vim.fn.line("'<"), vim.fn.col("'<") - 1 })
  end
  local win = vim.api.nvim_get_current_win()
  vim.cmd("normal! m'")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.b[buf].completion = false
  local width = math.min(50, vim.api.nvim_win_get_width(win) - 4)
  local input = vim.api.nvim_open_win(buf, true, {
    relative = 'win',
    win = win,
    anchor = 'NE',
    row = 0,
    col = vim.api.nvim_win_get_width(win) - 1,
    width = width,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    title = ' Find ',
  })
  vim.api.nvim_set_hl(0, 'VsFindToggleOn', { link = 'IncSearch', default = true })
  -- the input text matches its own search pattern; keep it plain
  local whl = vim.wo[input].winhighlight
  vim.wo[input].winhighlight = (whl ~= '' and whl .. ',' or '')
    .. 'Search:NormalFloat,CurSearch:NormalFloat,IncSearch:NormalFloat'
  state = {
    win = win,
    buf = buf,
    input = input,
    origin = vim.api.nvim_win_get_cursor(win),
    hlsearch = vim.o.hlsearch,
    prev_search = vim.fn.getreg('/'),
  }
  vim.o.hlsearch = true

  local map = function(lhs, fn) vim.keymap.set({ 'i', 'n' }, lhs, fn, { buffer = buf }) end
  local toggle = function(key)
    return function()
      opts[key] = not opts[key]
      update('cw', true)
    end
  end
  map('<CR>', function() update('w') end)
  map('<S-CR>', function() update('bw') end)
  map('<C-n>', function() update('w') end)
  map('<C-p>', function() update('bw') end)
  map('<M-c>', toggle('case'))
  map('<M-w>', toggle('word'))
  map('<M-r>', toggle('regex'))
  map('<Esc>', close)
  vim.keymap.set('n', 'q', close, { buffer = buf })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = function() update('cw', true) end,
  })
  vim.api.nvim_create_autocmd('WinLeave', {
    buffer = buf,
    once = true,
    callback = function() vim.schedule(close) end,
  })

  if seed then vim.api.nvim_buf_set_lines(buf, 0, -1, false, { seed }) end
  update('cw', true)
  vim.cmd.startinsert({ bang = true })
end

return M
