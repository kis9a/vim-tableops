" vim-tableops -- Edit Markdown tables by column and by cell.

if exists('g:loaded_tableops')
  finish
endif
" Vim 9.0 / Neovim 0.9 or later; an older one defines nothing and leaves
" g:loaded_tableops unset.
if !has('nvim-0.9') && v:version < 900
  finish
endif
let g:loaded_tableops = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

" A command that already exists by this exact name is left alone (F14).
let s:defined = {}
function! s:command(name, attrs, body) abort
  if exists(':' . a:name) == 2
    return
  endif
  execute 'command!' a:attrs a:name a:body
  let s:defined[a:name] = 1
endfunction

" The range only chooses the table; column numbers are arguments.
call s:command('TableopsFormat', '-range -bar',
      \ 'call tableops#format(<line1>, <line2>, <range>)')
call s:command('TableopsDeleteColumn', '-range -nargs=* -bar',
      \ 'call tableops#delete_column(<line1>, <line2>, <range>, <q-args>)')
call s:command('TableopsInsertColumn', '-range -nargs=? -bang -bar',
      \ 'call tableops#insert_column(<line1>, <line2>, <range>, <bang>0, <q-args>)')
call s:command('TableopsMoveColumn', '-nargs=1 -bar',
      \ 'call tableops#move_column(<q-args>)')
call s:command('TableopsSortColumn', '-range -nargs=* -bang -bar',
      \ 'call tableops#sort_column(<line1>, <line2>, <range>, <bang>0, <q-args>)')
" :execute here, not in a function: v:hlsearch set in a function is
" restored when it returns.
call s:command('TableopsSearchColumn', '-range -nargs=? -bar',
      \ 'execute tableops#search_column(<line1>, <line2>, <range>, <q-args>)')
call s:command('TableopsColumns', '-range -bar',
      \ 'call tableops#columns(<line1>, <line2>, <range>)')

nnoremap <silent> <Plug>(tableops-format) <Cmd>call tableops#format(line('.'), line('.'), 0)<CR>

" Dot-repeatable through 'operatorfunc' and g@l; the count is the column
" number (the distance for move).
nnoremap <silent> <expr> <Plug>(tableops-delete-column) tableops#op#prepare('delete_column')
xnoremap <silent> <Plug>(tableops-delete-column) <Cmd>call tableops#delete_column_visual()<CR>
nnoremap <silent> <expr> <Plug>(tableops-insert-column-after) tableops#op#prepare('insert_after')
nnoremap <silent> <expr> <Plug>(tableops-insert-column-before) tableops#op#prepare('insert_before')
nnoremap <silent> <expr> <Plug>(tableops-move-column-left) tableops#op#prepare('move_left')
nnoremap <silent> <expr> <Plug>(tableops-move-column-right) tableops#op#prepare('move_right')

" Stops on the command line for the flags.
if has_key(s:defined, 'TableopsSortColumn')
  nnoremap <expr> <Plug>(tableops-sort-column) ':<C-u>TableopsSortColumn ' . (v:count ? v:count . ' ' : '')
endif

nnoremap <silent> <Plug>(tableops-search-column) <Cmd>execute tableops#search_column_count(v:count)<CR>
nnoremap <silent> <Plug>(tableops-columns) <Cmd>call tableops#columns(line('.'), line('.'), 0)<CR>

" Each mapping passes its own mode letter: mode(1) is not reliable in every
" setup (it is always 'ce' in Ex mode, vim -e).
for s:dir in ['left', 'right', 'up', 'down']
  for s:mode in ['n', 'x', 'o']
    execute printf('%snoremap <silent> <expr> <Plug>(tableops-cell-%s) tableops#cell_motion(''%s'', ''%s'')',
          \ s:mode, s:dir, s:dir, s:mode)
  endfor
endfor
unlet s:dir s:mode

xnoremap <silent> <expr> <Plug>(tableops-inner-cell) tableops#cell_object(1, 'x')
onoremap <silent> <expr> <Plug>(tableops-inner-cell) tableops#cell_object(1, 'o')
xnoremap <silent> <expr> <Plug>(tableops-a-cell) tableops#cell_object(0, 'x')
onoremap <silent> <expr> <Plug>(tableops-a-cell) tableops#cell_object(0, 'o')

delfunction s:command
unlet s:defined

let &cpoptions = s:save_cpo
unlet s:save_cpo
