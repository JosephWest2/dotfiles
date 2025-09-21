local M = {}

-- Imports are relative to the lua/ directory
local prefix = 'joey.plugins.'

local plugins = {
    require(prefix .. 'autoclose'),
    require(prefix .. 'treesitter'),
    require(prefix .. 'fzf-lua'),
    require(prefix .. 'auto-save'),
    require(prefix .. 'onedark'),
    require(prefix .. 'lspconfig'),
    require(prefix .. 'lazy-dev'),
    require(prefix .. 'codeium'),
    require(prefix .. 'blink-cmp'),
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
