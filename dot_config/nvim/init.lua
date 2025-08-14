vim.g.mapleader = " "

vim.o.shiftwidth = 4

vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true

vim.o.termguicolors = true
vim.o.scrolloff = 8
vim.o.nu = true
vim.o.rnu = true

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")

vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]])
vim.keymap.set({ "n", "v" }, "<leader>P", [["+P]])
vim.keymap.set({ "n", "v" }, "<A-y>", [["*y]])
vim.keymap.set({ "n", "v" }, "<A-p>", [["*p]])
vim.keymap.set({ "n", "v" }, "<A-P>", [["*P]])

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/g<Left><Left>]])

vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])
vim.keymap.set("t", "<C-[>", [[<C-\><C-n>]])
vim.keymap.set("t", "C-c", [[<C-\><C-n>]])


