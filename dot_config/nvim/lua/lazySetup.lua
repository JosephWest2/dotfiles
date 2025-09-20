local M = {}

-- Imports are relative to the lua/ directory
local plugins = {
    require('plugins.autoclose'),
    require('plugins.treesitter'),
    require('plugins.fzf-lua'),
    require('plugins.auto-save'),
    require('plugins.onedark'),
    require('plugins.lspconfig'),
}

function M.init()

    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "WarningMsg" },
          { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      spec = plugins,
      checker = { enabled = true },
    })

end

return M
