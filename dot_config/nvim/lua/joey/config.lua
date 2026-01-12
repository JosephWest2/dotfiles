local M = {}

function M.init()
    vim.g.mapleader = " "

    -- add gap so warning's / errors don't cause text to shift right.
    vim.o.signcolumn = 'yes'

    -- << and >> insert / remove 4 spaces
    vim.o.shiftwidth = 4

    -- wrap text, wrapped text appears indented to the start of the line
    vim.o.wrap = true
    vim.o.breakindent = true

    -- tabs appear as 4 spaces
    vim.o.tabstop = 4

    -- tab actually inserts 4 spaces
    vim.o.softtabstop = 4
    vim.o.expandtab = true

    -- limit scroll to 8 lines from bottom, enable
    vim.o.termguicolors = true
    vim.o.scrolloff = 8

    -- enable line numbers and relative line numbers
    vim.o.nu = true
    vim.o.rnu = true

    local indent_group = vim.api.nvim_create_augroup("IndentSettings", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = indent_group,
        pattern = { "javascript", "typescript", "typescriptreact", "javascriptreact" },
        callback = function()
            vim.opt_local.tabstop = 2
            vim.opt_local.shiftwidth = 2
            vim.opt_local.softtabstop = 2
            vim.opt_local.expandtab = true
        end,
    })
end

return M
