return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
        local parsers = {
            "bash",
            "c",
            "cpp",
            "c_sharp",
            "css",
            "go",
            "gomod",
            "gosum",
            "gowork",
            "groovy",
            "html",
            "java",
            "javascript",
            "json",
            "lua",
            "markdown",
            "markdown_inline",
            "properties",
            "rust",
            "tsx",
            "typescript",
            "xml",
            "yaml",
        }

        require("nvim-treesitter").install(parsers)

        local group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true })
        vim.api.nvim_create_autocmd("FileType", {
            group = group,
            callback = function(event)
                local filetype = vim.bo[event.buf].filetype
                local language = vim.treesitter.language.get_lang(filetype)
                if language then
                    pcall(vim.treesitter.start, event.buf, language)
                end
            end,
        })
    end,
}
