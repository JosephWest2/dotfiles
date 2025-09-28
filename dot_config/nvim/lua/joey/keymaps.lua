local M = {}

function M.init()
    -- recenter lines on <C-d> and <C-u>
    vim.keymap.set("n", "<C-d>", "<C-d>zz")
    vim.keymap.set("n", "<C-u>", "<C-u>zz")

    -- copy to clipboard keymaps
    vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
    vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
    vim.keymap.set({ "n", "v" }, "<leader>P", [["+P]])
    vim.keymap.set({ "n", "v" }, "<A-y>", [["*y]])
    vim.keymap.set({ "n", "v" }, "<A-p>", [["*p]])
    vim.keymap.set({ "n", "v" }, "<A-P>", [["*P]])

    -- substitute word under cursor across the whole file
    vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/g<Left><Left>]])

    -- give the same keybinds to get out of terminal
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
    vim.keymap.set("t", "<C-[>", [[<C-\><C-n>]])
    vim.keymap.set("t", "<C-c>", [[<C-\><C-n>]])

    -- next and previous quickfix list keybinds
    vim.keymap.set("n", "<A-j>", ":cnext<CR>")
    vim.keymap.set("n", "<A-k>", ":cprev<CR>")

    -- lsp code action
    vim.keymap.set("n", "<C-,>", vim.lsp.buf.code_action)

    -- rename using lsp
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)

    -- format using lsp
    vim.keymap.set("n", "<leader>fm", vim.lsp.buf.format)

end

return M
