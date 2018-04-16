function! minigutter#sign#update(data) abort
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
