function! minigutter#execute_diff() abort
  let command = ['sh', '-c', "git --no-pager diff -U0 --no-color -- ".expand("%:p")." | rg \"^@@ \""]
  call minigutter#job#execute(command)
endfunction
