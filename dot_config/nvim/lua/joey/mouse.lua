-- Change the terminal's mouse pointer shape to a resize arrow when it hovers a
-- split boundary. The shape is set with OSC 22, so it only shows up on
-- terminals that implement it (cmux and kitty do; wezterm silently drops it).
local M = {}

-- The OSC 22 spec resets the pointer with an empty shape name, but cmux
-- ignores that and leaves the previous shape stuck, so name the shape we want
-- explicitly. "text" is the I-beam a terminal normally shows over its content.
-- Change this if your terminal's idle pointer should be something else.
local RESET = "text"
local COL_RESIZE = "ew-resize"
local ROW_RESIZE = "ns-resize"

-- what we last told the terminal, so we only write on a change. anything that
-- resets the pointer behind our back has to invalidate this or the shape gets
-- stuck: see the focus autocmds below.
local current = nil

M.stats = { moves = 0, writes = 0, errors = 0, last_error = nil, last = "?", pos = "?" }

local function write(seq)
    -- tmux swallows escape sequences it doesn't recognise unless they are
    -- wrapped for passthrough (requires `allow-passthrough on`)
    if vim.env.TMUX then
        seq = "\027Ptmux;" .. seq:gsub("\027", "\027\027") .. "\027\\"
    end
    vim.api.nvim_ui_send(seq)
end

local function set_shape(shape)
    M.stats.last = shape
    -- the terminal re-asserts its own pointer on input and on redraw, which
    -- silently undoes ours, so a resize shape has to be re-sent on every move
    -- rather than only when it changes. the default shape is the common case
    -- and is safe to write once, on the transition.
    if shape == current and shape == RESET then
        return
    end
    current = shape
    M.stats.writes = M.stats.writes + 1
    write("\027]22;" .. shape .. "\027\\")
end

--- Forget what the terminal is showing, so the next move re-sends it.
local function invalidate()
    current = nil
end

--- Every non-floating window in the current tabpage, in absolute screen cells.
--- Floats are excluded: their edges aren't drag handles.
local function layout()
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
            local pos = vim.fn.win_screenpos(win)
            wins[#wins + 1] = {
                row = pos[1],
                col = pos[2],
                height = vim.api.nvim_win_get_height(win),
                width = vim.api.nvim_win_get_width(win),
            }
        end
    end
    return wins
end

local function win_at(wins, row, col)
    for _, w in ipairs(wins) do
        if row >= w.row and row < w.row + w.height
            and col >= w.col and col < w.col + w.width then
            return w
        end
    end
end

--- The pointer shape for a given screen cell, both 1-based and absolute.
--- A boundary only counts as resizable when there is a window on both sides of
--- it, which is what keeps the bottom statusline and the screen edges out.
---@param row integer
---@param col integer
---@return string
function M.shape_at(row, col)
    local wins = layout()

    local left = win_at(wins, row, col - 1)
    if left and left.col + left.width == col and win_at(wins, row, col + 1) then
        return COL_RESIZE
    end

    local above = win_at(wins, row - 1, col)
    if above and above.row + above.height == row and win_at(wins, row + 1, col) then
        return ROW_RESIZE
    end

    return RESET
end

--- Recompute from the last known mouse position. getmousepos() keeps
--- reporting it when the mouse is stationary, so this also works off events
--- that aren't mouse movement.
local function apply()
    local pos = vim.fn.getmousepos()
    M.stats.pos = pos.screenrow .. "," .. pos.screencol
    set_shape(M.shape_at(pos.screenrow, pos.screencol))
end

--- The shape names this module can send, exposed for testing.
M.shapes = { reset = RESET, col = COL_RESIZE, row = ROW_RESIZE }

local function on_move()
    M.stats.moves = M.stats.moves + 1
    apply()
end

function M.init()
    vim.o.mousemoveevent = true

    -- a throwing handler would fire on every pixel of mouse travel, so swallow
    -- the error and keep the last one for :MouseShape rather than spamming
    local function safe_on_move()
        local ok, err = pcall(on_move)
        if not ok then
            M.stats.errors = M.stats.errors + 1
            M.stats.last_error = tostring(err)
        end
    end

    -- terminal mode is left out so mouse-aware TUIs keep receiving motion
    vim.keymap.set({ "n", "i", "v", "s", "o", "c" }, "<MouseMove>", safe_on_move,
        { desc = "Resize pointer over split boundaries" })

    local group = vim.api.nvim_create_augroup("JoeyMousePointer", { clear = true })

    -- don't hand the shell, or another app, back a resize pointer
    vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend", "FocusLost" }, {
        group = group,
        callback = function() set_shape(RESET) end,
    })

    -- something else owned the pointer while we were away, so re-send on the
    -- next move instead of trusting our cache
    vim.api.nvim_create_autocmd({ "VimResume", "FocusGained" }, {
        group = group,
        callback = function()
            invalidate()
            -- re-assert mouse motion reporting in case the terminal dropped it
            vim.o.mousemoveevent = true
        end,
    })

    -- typing `:` makes the terminal take the pointer back, so put it right
    -- again on the way out without waiting for the mouse to move
    vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = group,
        callback = function()
            invalidate()
            pcall(apply)
        end,
    })

    vim.api.nvim_create_user_command("MouseShape", function()
        local s = M.stats
        print(([[
mousemoveevent : %s
MouseMove map  : %s
moves seen     : %d
shapes written : %d
last shape     : %q
last position  : %s
errors         : %d
last error     : %s
$TMUX          : %s]]):format(
            tostring(vim.o.mousemoveevent),
            tostring(vim.fn.maparg("<MouseMove>", "n", false, true).callback ~= nil),
            s.moves, s.writes, s.last, s.pos, s.errors, tostring(s.last_error),
            tostring(vim.env.TMUX ~= nil)))
    end, { desc = "Report mouse pointer shape state" })

    vim.api.nvim_create_user_command("MouseShapeTest", function(o)
        local shape = o.args ~= "" and o.args or COL_RESIZE
        invalidate()
        set_shape(shape)
        print("sent OSC 22 shape: " .. vim.inspect(shape))
    end, { nargs = "?", desc = "Force a pointer shape, to test terminal support" })
end

return M
