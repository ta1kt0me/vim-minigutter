scriptencoding utf-8

if exists('g:loaded_minigutter') || !has('signs') || &cp
  finish
endif
let g:loaded_minigutter = 1

" Initialisation {{{

if v:version < 703 || (v:version == 703 && !has("patch105"))
  call minigutter#utility#warn('requires Vim 7.3.105')
  finish
endif

function! s:set(var, default) abort
  if !exists(a:var)
    if type(a:default)
      execute 'let' a:var '=' string(a:default)
    else
      execute 'let' a:var '=' a:default
    endif
  endif
endfunction

call s:set('g:minigutter_enabled',                     1)
call s:set('g:minigutter_max_signs',                 500)
call s:set('g:minigutter_signs',                       1)
call s:set('g:minigutter_highlight_lines',             0)
call s:set('g:minigutter_sign_column_always',          0)
if g:minigutter_sign_column_always && exists('&signcolumn')
  " Vim 7.4.2201.
  set signcolumn=yes
  let g:minigutter_sign_column_always = 0
  call minigutter#utility#warn('please replace "let g:minigutter_sign_column_always=1" with "set signcolumn=yes"')
endif
call s:set('g:minigutter_override_sign_column_highlight', 1)
call s:set('g:minigutter_sign_added',                '+')
call s:set('g:minigutter_sign_modified',             '~')
call s:set('g:minigutter_sign_removed',              '_')

if minigutter#utility#supports_overscore_sign()
  call s:set('g:minigutter_sign_removed_first_line', '‾')
else
  call s:set('g:minigutter_sign_removed_first_line', '_^')
endif

call s:set('g:minigutter_sign_modified_removed',    '~_')
call s:set('g:minigutter_diff_args',                  '')
call s:set('g:minigutter_diff_base',                  '')
call s:set('g:minigutter_map_keys',                    1)
call s:set('g:minigutter_terminal_reports_focus',      1)
call s:set('g:minigutter_async',                       1)
call s:set('g:minigutter_log',                         0)

call s:set('g:minigutter_git_executable', 'git')
if !executable(g:minigutter_git_executable)
  call minigutter#utility#warn('cannot find git. Please set g:minigutter_git_executable.')
endif

let default_grep = 'grep'
call s:set('g:minigutter_grep', default_grep)
if !empty(g:minigutter_grep)
  if executable(split(g:minigutter_grep)[0])
    if $GREP_OPTIONS =~# '--color=always'
      let g:minigutter_grep .= ' --color=never'
    endif
  else
    if g:minigutter_grep !=# default_grep
      call minigutter#utility#warn('cannot find '.g:minigutter_grep.'. Please check g:minigutter_grep.')
    endif
    let g:minigutter_grep = ''
  endif
endif

call minigutter#highlight#define_sign_column_highlight()
call minigutter#highlight#define_highlights()
call minigutter#highlight#define_signs()

" Prevent infinite loop where:
" - executing a job in the foreground launches a new window which takes the focus;
" - when the job finishes, focus returns to gvim;
" - the FocusGained event triggers a new job (see below).
if minigutter#utility#windows() && !minigutter#async#available()
  set noshelltemp
endif

" }}}

" Primary functions {{{

command! -bar GitGutterAll call minigutter#all(1)
command! -bar GitGutter    call minigutter#process_buffer(bufnr(''), 1)

command! -bar GitGutterDisable call minigutter#disable()
command! -bar GitGutterEnable  call minigutter#enable()
command! -bar GitGutterToggle  call minigutter#toggle()

" }}}

" Line highlights {{{

command! -bar GitGutterLineHighlightsDisable call minigutter#highlight#line_disable()
command! -bar GitGutterLineHighlightsEnable  call minigutter#highlight#line_enable()
command! -bar GitGutterLineHighlightsToggle  call minigutter#highlight#line_toggle()

" }}}

" Signs {{{

command! -bar GitGutterSignsEnable  call minigutter#sign#enable()
command! -bar GitGutterSignsDisable call minigutter#sign#disable()
command! -bar GitGutterSignsToggle  call minigutter#sign#toggle()

" }}}

" Hunks {{{

command! -bar -count=1 GitGutterNextHunk call minigutter#hunk#next_hunk(<count>)
command! -bar -count=1 GitGutterPrevHunk call minigutter#hunk#prev_hunk(<count>)

command! -bar GitGutterStageHunk   call minigutter#hunk#stage()
command! -bar GitGutterUndoHunk    call minigutter#hunk#undo()
command! -bar GitGutterPreviewHunk call minigutter#hunk#preview()

" Hunk text object
onoremap <silent> <Plug>GitGutterTextObjectInnerPending :<C-U>call minigutter#hunk#text_object(1)<CR>
onoremap <silent> <Plug>GitGutterTextObjectOuterPending :<C-U>call minigutter#hunk#text_object(0)<CR>
xnoremap <silent> <Plug>GitGutterTextObjectInnerVisual  :<C-U>call minigutter#hunk#text_object(1)<CR>
xnoremap <silent> <Plug>GitGutterTextObjectOuterVisual  :<C-U>call minigutter#hunk#text_object(0)<CR>


" Returns the git-diff hunks for the file or an empty list if there
" aren't any hunks.
"
" The return value is a list of lists.  There is one inner list per hunk.
"
"   [
"     [from_line, from_count, to_line, to_count],
"     [from_line, from_count, to_line, to_count],
"     ...
"   ]
"
" where:
"
" `from`  - refers to the staged file
" `to`    - refers to the working tree's file
" `line`  - refers to the line number where the change starts
" `count` - refers to the number of lines the change covers
function! GitGutterGetHunks()
  let bufnr = bufnr('')
  return minigutter#utility#is_active(bufnr) ? minigutter#hunk#hunks(bufnr) : []
endfunction

" Returns an array that contains a summary of the hunk status for the current
" window.  The format is [ added, modified, removed ], where each value
" represents the number of lines added/modified/removed respectively.
function! GitGutterGetHunkSummary()
  return minigutter#hunk#summary(winbufnr(0))
endfunction

" }}}

command! -bar GitGutterDebug call minigutter#debug#debug()

" Maps {{{

nnoremap <silent> <expr> <Plug>GitGutterNextHunk &diff ? ']c' : ":\<C-U>execute v:count1 . 'GitGutterNextHunk'\<CR>"
nnoremap <silent> <expr> <Plug>GitGutterPrevHunk &diff ? '[c' : ":\<C-U>execute v:count1 . 'GitGutterPrevHunk'\<CR>"

if g:minigutter_map_keys
  if !hasmapto('<Plug>GitGutterPrevHunk') && maparg('[c', 'n') ==# ''
    nmap [c <Plug>GitGutterPrevHunk
  endif
  if !hasmapto('<Plug>GitGutterNextHunk') && maparg(']c', 'n') ==# ''
    nmap ]c <Plug>GitGutterNextHunk
  endif
endif


nnoremap <silent> <Plug>GitGutterStageHunk   :GitGutterStageHunk<CR>
nnoremap <silent> <Plug>GitGutterUndoHunk    :GitGutterUndoHunk<CR>
nnoremap <silent> <Plug>GitGutterPreviewHunk :GitGutterPreviewHunk<CR>

if g:minigutter_map_keys
  if !hasmapto('<Plug>GitGutterStageHunk') && maparg('<Leader>hs', 'n') ==# ''
    nmap <Leader>hs <Plug>GitGutterStageHunk
  endif
  if !hasmapto('<Plug>GitGutterUndoHunk') && maparg('<Leader>hu', 'n') ==# ''
    nmap <Leader>hu <Plug>GitGutterUndoHunk
  endif
  if !hasmapto('<Plug>GitGutterPreviewHunk') && maparg('<Leader>hp', 'n') ==# ''
    nmap <Leader>hp <Plug>GitGutterPreviewHunk
  endif

  if !hasmapto('<Plug>GitGutterTextObjectInnerPending') && maparg('ic', 'o') ==# ''
    omap ic <Plug>GitGutterTextObjectInnerPending
  endif
  if !hasmapto('<Plug>GitGutterTextObjectOuterPending') && maparg('ac', 'o') ==# ''
    omap ac <Plug>GitGutterTextObjectOuterPending
  endif
  if !hasmapto('<Plug>GitGutterTextObjectInnerVisual') && maparg('ic', 'x') ==# ''
    xmap ic <Plug>GitGutterTextObjectInnerVisual
  endif
  if !hasmapto('<Plug>GitGutterTextObjectOuterVisual') && maparg('ac', 'x') ==# ''
    xmap ac <Plug>GitGutterTextObjectOuterVisual
  endif
endif

" }}}

" Autocommands {{{

augroup minigutter
  autocmd!

  autocmd TabEnter * let t:minigutter_didtabenter = 1

  autocmd BufEnter *
        \ if exists('t:minigutter_didtabenter') && t:minigutter_didtabenter |
        \   let t:minigutter_didtabenter = 0 |
        \   call minigutter#all(!g:minigutter_terminal_reports_focus) |
        \ else |
        \   call minigutter#init_buffer(bufnr('')) |
        \   call minigutter#process_buffer(bufnr(''), !g:minigutter_terminal_reports_focus) |
        \ endif

  autocmd CursorHold,CursorHoldI            * call minigutter#process_buffer(bufnr(''), 0)
  autocmd FileChangedShellPost,ShellCmdPost * call minigutter#process_buffer(bufnr(''), 1)

  " Ensure that all buffers are processed when opening vim with multiple files, e.g.:
  "
  "   vim -o file1 file2
  autocmd VimEnter * if winnr() != winnr('$') | call minigutter#all(0) | endif

  autocmd FocusGained * call minigutter#all(1)

  autocmd ColorScheme * call minigutter#highlight#define_sign_column_highlight() | call minigutter#highlight#define_highlights()

  " Disable during :vimgrep
  autocmd QuickFixCmdPre  *vimgrep* let g:minigutter_enabled = 0
  autocmd QuickFixCmdPost *vimgrep* let g:minigutter_enabled = 1
augroup END

" }}}

" vim:set et sw=2 fdm=marker:
