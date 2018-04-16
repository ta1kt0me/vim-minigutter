scriptencoding utf-8

" Minigutter {{{

if exists('g:loaded_minigutter') || &cp
  finish
endif

let g:loaded_minigutter = 1

highlight AddCharHighlight ctermfg=green ctermbg=235 guibg=#232526
highlight ModifyCharHighlight ctermfg=yellow ctermbg=235 guibg=#232526
highlight RemoveCharHighlight ctermfg=red ctermbg=235 guibg=#232526

sign define AddGit text=+ texthl=AddCharHighlight
sign define RemoveGit text=- texthl=RemoveCharHighlight
sign define ModifyGit text=+ texthl=ModifyCharHighlight
sign define ModifyRemoveGit text=+- texthl=ModifyCharHighlight

augroup minigutter
  autocmd FileChangedShellPost,CursorHold,BufRead,BufWritepost * :call minigutter#execute_diff()
augroup END

" }}}

" vim:set et sw=2 fdm=marker:
