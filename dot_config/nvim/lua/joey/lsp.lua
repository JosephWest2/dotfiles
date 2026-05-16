local M = {}

function M.init()
    vim.g.zig_fmt_autosave = 0

    vim.diagnostic.config({
        virtual_lines = {
            current_line = true
        }
    })

    local orig = vim.lsp.handlers["textDocument/rename"]
    vim.lsp.handlers["textDocument/rename"] = function(err, result, ctx, config)
        local ret = orig(err, result, ctx, config)
        vim.cmd("silent! wa")
        return ret
    end

    local orig = vim.lsp.handlers["workspace/applyEdit"]
    vim.lsp.handlers["workspace/applyEdit"] = function(err, result, ctx, config)
        local ret = orig(err, result, ctx, config)
        vim.cmd("silent! wa") -- write all after LSP workspace edit
        return ret
    end
end

return M
