local M = {}

local function copy_file_reference(with_lines, selection)
    local path = vim.fn.expand("%:.")
    if path == "" then
        vim.notify("This buffer has no file path", vim.log.levels.WARN)
        return
    end

    local reference = path
    if with_lines then
        local first = vim.fn.line(".")
        local last = selection and vim.fn.line("v") or first
        first, last = math.min(first, last), math.max(first, last)
        reference = reference .. ":" .. first
        if last ~= first then
            reference = reference .. "-" .. last
        end
    end

    vim.fn.setreg("+", reference, "v")
    vim.notify("Copied: " .. reference)
end

function M.init()
    -- recenter lines on <C-d> and <C-u>, move 1/3 window instead of 1/2
    vim.keymap.set("n", "<C-d>", "24j")
    vim.keymap.set("n", "<C-u>", "24k")

    -- copy to clipboard keymaps
    vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
    vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
    vim.keymap.set({ "n", "v" }, "<leader>P", [["+P]])
    vim.keymap.set({ "n", "v" }, "<A-y>", [["*y]])
    vim.keymap.set({ "n", "v" }, "<A-p>", [["*p]])
    vim.keymap.set({ "n", "v" }, "<A-P>", [["*P]])

    -- file references for sharing, without copying file contents
    vim.keymap.set({ "n", "x" }, "<leader>cf", function()
        copy_file_reference(false)
    end, { desc = "Copy file path" })
    vim.keymap.set("n", "<leader>cl", function()
        copy_file_reference(true)
    end, { desc = "Copy file path and current line" })
    vim.keymap.set("x", "<leader>cl", function()
        copy_file_reference(true, true)
    end, { desc = "Copy file path and selected lines" })

    -- substitute word under cursor across the whole file
    vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/g<Left><Left>]])

    -- toggle / highlighting
    vim.keymap.set("n", "<leader>hl", ":set hlsearch! hlsearch?<CR>")

    -- give the same keybinds to get out of terminal
--    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
 --   vim.keymap.set("t", "<C-[>", [[<C-\><C-n>]])

    -- next and previous quickfix list keybinds
    vim.keymap.set("n", "<A-j>", ":cnext<CR>")
    vim.keymap.set("n", "<A-k>", ":cprev<CR>")

    -- widen / narrow the current window, 3 columns at a time
    vim.keymap.set("n", "<A-l>", "3<C-w>>")
    vim.keymap.set("n", "<A-h>", "3<C-w><")

    -- lsp code action
    vim.keymap.set("n", "<C-.>", vim.lsp.buf.code_action)

    -- rename using lsp
    vim.keymap.set("n", "<leader>rn", function()
        vim.lsp.buf.rename()
        vim.cmd('silent! wa')
    end)

    -- format using lsp
    vim.keymap.set("n", "<leader>fm", vim.lsp.buf.format)

    -- go to definition
    vim.keymap.set("n", "gd", vim.lsp.buf.definition)

    -- go to declaration
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration)

    -- go to type definition
    vim.keymap.set("n", "gt", vim.lsp.buf.type_definition)

    -- go to implementation
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation)

    -- restart lsp
    vim.keymap.set("n", "<leader>lr", ":LspRestart<CR>")

    -- tab keymaps (requires fzf-lua)
    vim.keymap.set("n", "<C-t>", function()
        local bufno = vim.api.nvim_get_current_buf()
        local cursorPos = vim.api.nvim_win_get_cursor(0)
        vim.cmd("tabnew")
        vim.cmd("b" .. bufno)
        vim.api.nvim_win_set_cursor(0, cursorPos)
    end)

    vim.keymap.set("n", "<C-1>", function() vim.cmd("tabnext 1") end)
    vim.keymap.set("n", "<C-2>", function() vim.cmd("tabnext 2") end)
    vim.keymap.set("n", "<C-3>", function() vim.cmd("tabnext 3") end)
    vim.keymap.set("n", "<C-4>", function() vim.cmd("tabnext 4") end)
    vim.keymap.set("n", "<C-5>", function() vim.cmd("tabnext 5") end)
end

return M
