" Messages. echomsg keeps them in :messages; echohl is reset in finally.

let s:save_cpo = &cpoptions
set cpoptions&vim

" At most 50 columns with the prefix: with 'showcmd' and 'ruler' a longer
" message can cause a hit-enter prompt in an 80-column Vim.
let s:width = 50

function! tableops#compat#notify#text(msg) abort
  let l:text = '[tableops] ' . substitute(a:msg, '[[:cntrl:]]', ' ', 'g')
  if strdisplaywidth(l:text) <= s:width
    return l:text
  endif
  let l:n = s:width - 3
  while strdisplaywidth(strcharpart(l:text, 0, l:n)) > s:width - 3
    let l:n -= 1
  endwhile
  return strcharpart(l:text, 0, l:n) . '...'
endfunction

function! s:emit(group, msg) abort
  if a:group !=# ''
    execute 'echohl' a:group
  endif
  try
    let l:full = '[tableops] ' . substitute(a:msg, '[[:cntrl:]]', ' ', 'g')
    let l:short = tableops#compat#notify#text(a:msg)
    " :messages keeps the full text; the screen shows the short one
    echomsg l:full
    if l:short !=# l:full
      redraw
      echo l:short
    endif
  finally
    echohl None
  endtry
endfunction

function! tableops#compat#notify#info(msg) abort
  call s:emit('', a:msg)
endfunction

function! tableops#compat#notify#warn(msg) abort
  call s:emit('WarningMsg', a:msg)
endfunction

function! tableops#compat#notify#error(msg) abort
  call s:emit('ErrorMsg', a:msg)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
