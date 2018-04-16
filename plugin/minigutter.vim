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

function! s:execute_diff() abort
  let command = ['sh', '-c', "git --no-pager diff -U0 --no-color -- ".expand("%:p")." | rg \"^@@ \""]
  let options = {
        \   'stdoutbuffer': [],
        \ }

  call job_start(command, {
        \   'out_cb':   function('s:on_stdout', options),
        \   'err_cb':   function('s:on_stderr', options),
        \   'close_cb': function('s:on_exit', options)
        \ })
endfunction

function! s:on_stdout(_channel, data) dict abort
  call add(self.stdoutbuffer, a:data)
endfunction

function! s:on_stderr(_channel, msg) abort
  echom printf('Command Error: %s', a:msg)
endfunction

function! s:on_exit(_channel) dict abort
  call s:sign(self.stdoutbuffer)
endfunction

function! s:sign(data) abort
  let modifications = []
  for line in a:data
    let matches = matchlist(line, '^@@ -\(\d\+\),\?\(\d*\) +\(\d\+\),\?\(\d*\) @@')
    if len(matches) == 0
      continue
    endif

    let from_line = str2nr(matches[1])
    let from_count = (matches[2] == '') ? 1 : str2nr(matches[2])
    let to_line = str2nr(matches[3])
    let to_count = (matches[4] == '') ? 1 : str2nr(matches[4])

    if from_count == 0 && to_count > 0
      call s:process_added(modifications, from_count, to_count, to_line)
    elseif from_count > 0 && to_count == 0
      call s:process_removed(modifications, from_count, to_count, to_line)
    elseif from_count > 0 && to_count > 0 && from_count == to_count
      call s:process_modified(modifications, from_count, to_count, to_line)
    elseif from_count > 0 && to_count > 0 && from_count < to_count
      call s:process_modified_and_added(modifications, from_count, to_count, to_line)
    elseif from_count > 0 && to_count > 0 && from_count > to_count
      call s:process_modified_and_removed(modifications, from_count, to_count, to_line)
    endif
  endfor

  exe ":sign unplace * file=" . expand("%:p")

  for modification in modifications
    let sig = ""
    let stat = modification[1]

    if stat == "added"
      let sig = "AddGit"
    elseif stat == "removed"
      let sig = "RemoveGit"
    elseif stat == "modified"
      let sig = "ModifyGit"
    elseif stat == "modified_removed"
      let sig = "ModifyRemoveGit"
    endif

    let cmd = ":sign place " . modification[0] . " line=" . modification[0] . " name=".sig." file=" . expand("%:p")
    exe cmd
  endfor
endfunction

function! s:process_added(modifications, from_count, to_count, to_line) abort
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'added'])
    let offset += 1
  endwhile
endfunction

function! s:process_removed(modifications, from_count, to_count, to_line) abort
  if a:to_line == 0
    call add(a:modifications, [1, 'removed_first_line'])
  else
    call add(a:modifications, [a:to_line, 'removed'])
  endif
endfunction

function! s:process_modified(modifications, from_count, to_count, to_line) abort
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
endfunction

function! s:process_modified_and_added(modifications, from_count, to_count, to_line) abort
  let offset = 0
  while offset < a:from_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'added'])
    let offset += 1
  endwhile
endfunction

function! s:process_modified_and_removed(modifications, from_count, to_count, to_line) abort
  let offset = 0
  while offset < a:to_count
    let line_number = a:to_line + offset
    call add(a:modifications, [line_number, 'modified'])
    let offset += 1
  endwhile
  let a:modifications[-1] = [a:to_line + offset - 1, 'modified_removed']
endfunction

augroup minigutter
  autocmd FileChangedShellPost,CursorHold,BufRead,BufWritepost * :call s:execute_diff()
augroup END

" }}}

" vim:set et sw=2 fdm=marker:
