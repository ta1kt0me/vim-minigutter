function! minigutter#job#execute(command) abort
  let options = {
        \   'stdoutbuffer': [],
        \ }

  call job_start(a:command, {
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
  call minigutter#sign#update(self.stdoutbuffer)
endfunction
