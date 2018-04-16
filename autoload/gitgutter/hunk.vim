function! minigutter#hunk#set_hunks(bufnr, hunks) abort
  call minigutter#utility#setbufvar(a:bufnr, 'hunks', a:hunks)
  call s:reset_summary(a:bufnr)
endfunction

function! minigutter#hunk#hunks(bufnr) abort
  return minigutter#utility#getbufvar(a:bufnr, 'hunks', [])
endfunction

function! minigutter#hunk#reset(bufnr) abort
  call minigutter#utility#setbufvar(a:bufnr, 'hunks', [])
  call s:reset_summary(a:bufnr)
endfunction


function! minigutter#hunk#summary(bufnr) abort
  return minigutter#utility#getbufvar(a:bufnr, 'summary', [0,0,0])
endfunction

function! s:reset_summary(bufnr) abort
  call minigutter#utility#setbufvar(a:bufnr, 'summary', [0,0,0])
endfunction

function! minigutter#hunk#increment_lines_added(bufnr, count) abort
  let summary = minigutter#hunk#summary(a:bufnr)
  let summary[0] += a:count
  call minigutter#utility#setbufvar(a:bufnr, 'summary', summary)
endfunction

function! minigutter#hunk#increment_lines_modified(bufnr, count) abort
  let summary = minigutter#hunk#summary(a:bufnr)
  let summary[1] += a:count
  call minigutter#utility#setbufvar(a:bufnr, 'summary', summary)
endfunction

function! minigutter#hunk#increment_lines_removed(bufnr, count) abort
  let summary = minigutter#hunk#summary(a:bufnr)
  let summary[2] += a:count
  call minigutter#utility#setbufvar(a:bufnr, 'summary', summary)
endfunction


function! minigutter#hunk#next_hunk(count) abort
  let bufnr = bufnr('')
  if minigutter#utility#is_active(bufnr)
    let current_line = line('.')
    let hunk_count = 0
    for hunk in minigutter#hunk#hunks(bufnr)
      if hunk[2] > current_line
        let hunk_count += 1
        if hunk_count == a:count
          execute 'normal!' hunk[2] . 'Gzv'
          return
        endif
      endif
    endfor
    call minigutter#utility#warn('No more hunks')
  endif
endfunction

function! minigutter#hunk#prev_hunk(count) abort
  let bufnr = bufnr('')
  if minigutter#utility#is_active(bufnr)
    let current_line = line('.')
    let hunk_count = 0
    for hunk in reverse(copy(minigutter#hunk#hunks(bufnr)))
      if hunk[2] < current_line
        let hunk_count += 1
        if hunk_count == a:count
          let target = hunk[2] == 0 ? 1 : hunk[2]
          execute 'normal!' target . 'Gzv'
          return
        endif
      endif
    endfor
    call minigutter#utility#warn('No previous hunks')
  endif
endfunction

" Returns the hunk the cursor is currently in or an empty list if the cursor
" isn't in a hunk.
function! s:current_hunk() abort
  let bufnr = bufnr('')
  let current_hunk = []

  for hunk in minigutter#hunk#hunks(bufnr)
    if minigutter#hunk#cursor_in_hunk(hunk)
      let current_hunk = hunk
      break
    endif
  endfor

  return current_hunk
endfunction

function! minigutter#hunk#cursor_in_hunk(hunk) abort
  let current_line = line('.')

  if current_line == 1 && a:hunk[2] == 0
    return 1
  endif

  if current_line >= a:hunk[2] && current_line < a:hunk[2] + (a:hunk[3] == 0 ? 1 : a:hunk[3])
    return 1
  endif

  return 0
endfunction

function! minigutter#hunk#text_object(inner) abort
  let hunk = s:current_hunk()

  if empty(hunk)
    return
  endif

  let [first_line, last_line] = [hunk[2], hunk[2] + hunk[3] - 1]

  if ! a:inner
    let lnum = last_line
    let eof = line('$')
    while lnum < eof && empty(getline(lnum + 1))
      let lnum +=1
    endwhile
    let last_line = lnum
  endif

  execute 'normal! 'first_line.'GV'.last_line.'G'
endfunction


function! minigutter#hunk#stage() abort
  call s:hunk_op(function('s:stage'))
  silent! call repeat#set("\<Plug>GitGutterStageHunk", -1)<CR>
endfunction

function! minigutter#hunk#undo() abort
  call s:hunk_op(function('s:undo'))
  silent! call repeat#set("\<Plug>GitGutterUndoHunk", -1)<CR>
endfunction

function! minigutter#hunk#preview() abort
  call s:hunk_op(function('s:preview'))
  silent! call repeat#set("\<Plug>GitGutterPreviewHunk", -1)<CR>
endfunction


function! s:hunk_op(op)
  let bufnr = bufnr('')

  if minigutter#utility#is_active(bufnr)
    " Get a (synchronous) diff.
    let [async, g:minigutter_async] = [g:minigutter_async, 0]
    let diff = minigutter#diff#run_diff(bufnr, 1)
    let g:minigutter_async = async

    call minigutter#hunk#set_hunks(bufnr, minigutter#diff#parse_diff(diff))

    if empty(s:current_hunk())
      call minigutter#utility#warn('cursor is not in a hunk')
    else
      call a:op(minigutter#diff#hunk_diff(bufnr, diff))
    endif
  endif
endfunction


function! s:stage(hunk_diff)
  let bufnr = bufnr('')
  let diff = s:adjust_header(bufnr, a:hunk_diff)
  " Apply patch to index.
  call minigutter#utility#system(
        \ minigutter#utility#cd_cmd(bufnr, g:minigutter_git_executable.' apply --cached --unidiff-zero - '),
        \ diff)

  " Refresh minigutter's view of buffer.
  call minigutter#process_buffer(bufnr, 1)
endfunction


function! s:undo(hunk_diff)
  " Apply reverse patch to buffer.
  let hunk  = minigutter#diff#parse_hunk(split(a:hunk_diff, '\n')[4])
  let lines = map(split(a:hunk_diff, '\n')[5:], 'v:val[1:]')
  let lnum  = hunk[2]
  let added_only   = hunk[1] == 0 && hunk[3]  > 0
  let removed_only = hunk[1]  > 0 && hunk[3] == 0

  if removed_only
    call append(lnum, lines)
  elseif added_only
    execute lnum .','. (lnum+len(lines)-1) .'d'
  else
    call append(lnum-1, lines[0:hunk[1]])
    execute (lnum+hunk[1]) .','. (lnum+hunk[1]+hunk[3]) .'d'
  endif
endfunction


function! s:preview(hunk_diff)
  let hunk_lines = split(s:discard_header(a:hunk_diff), "\n")
  let hunk_lines_length = len(hunk_lines)
  let previewheight = min([hunk_lines_length, &previewheight])

  silent! wincmd P
  if !&previewwindow
    noautocmd execute 'bo' previewheight 'new'
    set previewwindow
  else
    execute 'resize' previewheight
  endif

  setlocal noreadonly modifiable filetype=diff buftype=nofile bufhidden=delete noswapfile
  execute "%delete_"
  call append(0, hunk_lines)
  normal! gg
  setlocal readonly nomodifiable

  noautocmd wincmd p
endfunction


function! s:adjust_header(bufnr, hunk_diff)
  let filepath = minigutter#utility#repo_path(a:bufnr, 0)
  return s:adjust_hunk_summary(s:fix_file_references(filepath, a:hunk_diff))
endfunction


" Replaces references to temp files with the actual file.
function! s:fix_file_references(filepath, hunk_diff)
  let lines = split(a:hunk_diff, '\n')

  let left_prefix  = matchstr(lines[2], '[abciow12]').'/'
  let right_prefix = matchstr(lines[3], '[abciow12]').'/'
  let quote        = lines[0][11] == '"' ? '"' : ''

  let left_file  = quote.left_prefix.a:filepath.quote
  let right_file = quote.right_prefix.a:filepath.quote

  let lines[0] = 'diff --git '.left_file.' '.right_file
  let lines[2] = '--- '.left_file
  let lines[3] = '+++ '.right_file

  return join(lines, "\n")."\n"
endfunction

if $VIM_GITGUTTER_TEST
  function! minigutter#hunk#fix_file_references(filepath, hunk_diff)
    return s:fix_file_references(a:filepath, a:hunk_diff)
  endfunction
endif


function! s:adjust_hunk_summary(hunk_diff) abort
  let line_adjustment = s:line_adjustment_for_current_hunk()
  let diff = split(a:hunk_diff, '\n', 1)
  let diff[4] = substitute(diff[4], '+\@<=\(\d\+\)', '\=submatch(1)+line_adjustment', '')
  return join(diff, "\n")
endfunction


function! s:discard_header(hunk_diff)
  return join(split(a:hunk_diff, '\n', 1)[5:], "\n")
endfunction


" Returns the number of lines the current hunk is offset from where it would
" be if any changes above it in the file didn't exist.
function! s:line_adjustment_for_current_hunk() abort
  let bufnr = bufnr('')
  let adj = 0
  for hunk in minigutter#hunk#hunks(bufnr)
    if minigutter#hunk#cursor_in_hunk(hunk)
      break
    else
      let adj += hunk[1] - hunk[3]
    endif
  endfor
  return adj
endfunction

