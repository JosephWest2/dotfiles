local M = {}

function M.init()
    vim.filetype.add({
        extension = {
            mdx = "mdx",
            ftl = "freemarker",
        },
    })
    vim.treesitter.language.register("markdown", "mdx")

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "mdx",
        callback = function(ev)
            vim.treesitter.start(ev.buf, "markdown")
        end,
    })
end

return M
