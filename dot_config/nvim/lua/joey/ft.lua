local M = {}

function M.init()
    vim.filetype.add({
        extension = {
            mdx = "mdx",
            ftl = "freemarker",
        },
    })
    vim.treesitter.language.register("markdown", "mdx")
end

return M
