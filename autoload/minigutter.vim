let s:t_string = type('')

" Primary functions {{{

function! minigutter#all(force) abort
  for bufnr in s:uniq(tabpagebuflist())
    let file = expand('#'.bufnr.':p')
    if !empty(file)
      call minigutter#init_buffer(bufnr)
      call minigutter#process_buffer(bufnr, a:force)
    endif
  endfor
endfunction


" Finds the file's path relative to the repo root.
function! minigutter#init_buffer(bufnr)
  if minigutter#utility#is_active(a:bufnr)
    let p = minigutter#utility#repo_path(a:bufnr, 0)
    if type(p) != s:t_string || empty(p)
      call minigutter#utility#set_repo_path(a:bufnr)
    endif
  endif
endfunction


function! minigutter#process_buffer(bufnr, force) abort
  " NOTE a:bufnr is not necessarily the current buffer.

  if minigutter#utility#is_active(a:bufnr)
    if a:force || s:has_fresh_changes(a:bufnr)

      let diff = ''
      try
        let diff = minigutter#diff#run_diff(a:bufnr, 0)
      catch /minigutter not tracked/
        call minigutter#debug#log('Not tracked: '.minigutter#utility#file(a:bufnr))
      catch /minigutter diff failed/
        call minigutter#debug#log('Diff failed: '.minigutter#utility#file(a:bufnr))
        call minigutter#hunk#reset(a:bufnr)
      endtry

      if diff != 'async'
        call minigutter#diff#handler(a:bufnr, diff)
      endif

    endif
  endif
endfunction


function! minigutter#disable() abort
  " get list of all buffers (across all tabs)
  let buflist = []
  for i in range(tabpagenr('$'))
    call extend(buflist, tabpagebuflist(i + 1))
  endfor

  for bufnr in s:uniq(buflist)
    let file = expand('#'.bufnr.':p')
    if !empty(file)
      call s:clear(bufnr)
    endif
  endfor

  let g:minigutter_enabled = 0
endfunction

function! minigutter#enable() abort
  let g:minigutter_enabled = 1
  call minigutter#all(1)
endfunction

function! minigutter#toggle() abort
  if g:minigutter_enabled
    call minigutter#disable()
  else
    call minigutter#enable()
  endif
endfunction

" }}}

function! s:has_fresh_changes(bufnr) abort
  return getbufvar(a:bufnr, 'changedtick') != minigutter#utility#getbufvar(a:bufnr, 'tick')
endfunction

function! s:reset_tick(bufnr) abort
  call minigutter#utility#setbufvar(a:bufnr, 'tick', 0)
endfunction

function! s:clear(bufnr)
  call minigutter#sign#clear_signs(a:bufnr)
  call minigutter#sign#remove_dummy_sign(a:bufnr, 1)
  call minigutter#hunk#reset(a:bufnr)
  call s:reset_tick(a:bufnr)
endfunction

if exists('*uniq')  " Vim 7.4.218
  function! s:uniq(list)
    return uniq(sort(a:list))
  endfunction
else
  function! s:uniq(list)
    let processed = []
    for e in a:list
      if index(processed, e) == -1
        call add(processed, e)
      endif
    endfor
    return processed
  endfunction
endif
