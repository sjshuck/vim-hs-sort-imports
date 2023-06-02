# vim-hs-sort-imports

Sort Haskell import statements in Neovim the way I like.

## Prerequisites

* Neovim.  Tested on 0.7.x.

## Installation

I used to use [vim-plug](https://github.com/junegunn/vim-plug).

```vimscript
call plug#begin()
    Plug 'sjshuck/vim-hs-sort-imports'
call plug#end()
```

`:PlugUpdate`

But now I use [packer.nvim](https://github.com/wbthomason/packer.nvim), which is unmaintained&mdash;I intend to switch to [lazy.nvim](https://github.com/folke/lazy.nvim).  Basically, consult your plugin manager's docs and install this plugin the normal way.  :neutral_face:

## Use

`:HsSortImports`

## License

GPLv3+.

## Copyright

2022&ndash;2023 S. Shuck
