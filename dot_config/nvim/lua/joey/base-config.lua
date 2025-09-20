local M = {}

function M.init()
    vim.g.mapleader = " "

    vim.o.shiftwidth = 4

    vim.o.tabstop = 4
    vim.o.softtabstop = 4
    vim.o.expandtab = true

    vim.o.termguicolors = true
    vim.o.scrolloff = 8
    vim.o.nu = true
    vim.o.rnu = true

end

return M
