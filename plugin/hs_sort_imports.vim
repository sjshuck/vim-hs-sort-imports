if exists('g:loaded_hs_sort_imports') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

command! HsSortImports lua require('hs_sort_imports').hs_sort_imports()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_hs_sort_imports = 1
