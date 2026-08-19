return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        on_attach = function(bufnr)
            local gitsigns = require("gitsigns")
            local function map(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, {
                    buffer = bufnr,
                    desc = "Git: " .. desc,
                })
            end

            map("n", "]c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "]c", bang = true })
                else
                    gitsigns.nav_hunk("next")
                end
            end, "Next hunk")

            map("n", "[c", function()
                if vim.wo.diff then
                    vim.cmd.normal({ "[c", bang = true })
                else
                    gitsigns.nav_hunk("prev")
                end
            end, "Previous hunk")

            map("n", "<leader>gs", gitsigns.stage_hunk, "Stage hunk")
            map("v", "<leader>gs", function()
                gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
            end, "Stage hunk")
            map("n", "<leader>gr", gitsigns.reset_hunk, "Reset hunk")
            map("v", "<leader>gr", function()
                gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
            end, "Reset hunk")
            map("n", "<leader>gS", gitsigns.stage_buffer, "Stage buffer")
            map("n", "<leader>gR", gitsigns.reset_buffer, "Reset buffer")
            map("n", "<leader>gu", gitsigns.undo_stage_hunk, "Undo staged hunk")
            map("n", "<leader>gp", gitsigns.preview_hunk, "Preview hunk")
            map("n", "<leader>gb", function()
                gitsigns.blame_line({ full = true })
            end, "Blame line")
            map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "Toggle line blame")
            map("n", "<leader>gd", gitsigns.diffthis, "Diff against index")
            map("n", "<leader>gD", function()
                gitsigns.diffthis("~")
            end, "Diff against parent")
            map("n", "<leader>gq", gitsigns.setqflist, "Send hunks to quickfix")
        end,
    },
}
