scriptencoding utf-8

let s:suite = themis#suite('command_search')
let s:assert = themis#helper('assert')

" The last row has 2 cells and a closing |: column 3 must not match it.
let s:T = [
      \ 'intro',
      \ '| a | b \| c | d |',
      \ '|---|--------|---|',
      \ '| 1 | 2      | 3 |',
      \ '| x | y |',
      \ 'outro']

" What @/ matches on each line of the buffer.
let s:want = {
      \ 1: ['', '| a ', '|---', '| 1 ', '| x ', ''],
      \ 2: ['', '| b \| c ', '|--------', '| 2      ', '| y ', ''],
      \ 3: ['', '| d ', '|---', '| 3 ', '', ''],
      \ }

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  let @/ = 'before'
  let v:hlsearch = 0
  messages clear
endfunction

function! s:suite.after_each() abort
  set magic& ignorecase& smartcase&
endfunction

function! s:matches() abort
  return map(getline(1, '$'), 'matchstr(v:val, @/)')
endfunction

function! s:found(n, label) abort
  call s:assert.equals(@/, tableops#domain#column#pattern(a:n - 1), a:label)
  call s:assert.equals(v:hlsearch, 1, a:label)
  call s:assert.equals(histget('/', -1), @/, a:label)
  call s:assert.equals(s:matches(), s:want[a:n], a:label)
  call s:assert.equals(TableopsTestLines(), s:T, a:label)
endfunction

function! s:not_found(msg) abort
  call s:assert.equals(@/, 'before')
  call s:assert.equals(v:hlsearch, 0)
  call s:assert.equals(TableopsTestMessage(), '[tableops] ' . a:msg)
endfunction

function! s:suite.search_cursor_column_first_middle_last() abort
  for [l:n, l:lnum, l:ch] in [[1, 4, '1'], [2, 2, 'c'], [3, 4, '3']]
    let v:hlsearch = 0
    call TableopsTestCursor(l:lnum, l:ch)
    TableopsSearchColumn
    call s:found(l:n, 'cursor ' . l:n)
  endfor
endfunction

function! s:suite.search_count_first_middle_last_from_anywhere() abort
  for [l:n, l:lnum, l:ch] in [[1, 3, '--------'], [2, 5, 'x'], [3, 2, 'a'], [2, 4, '|']]
    let v:hlsearch = 0
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'normal ' . l:n . "\<Plug>(tableops-search-column)"
    call s:found(l:n, 'count ' . l:n)
  endfor
endfunction

function! s:suite.search_without_count_from_the_mapping() abort
  call TableopsTestCursor(3, '--------')
  execute "normal \<Plug>(tableops-search-column)"
  call s:found(2, 'mapping')
endfunction

function! s:suite.search_args_first_middle_last() abort
  call cursor(3, 1)
  for l:n in [1, 2, 3]
    let v:hlsearch = 0
    execute 'TableopsSearchColumn' l:n
    call s:found(l:n, 'arg ' . l:n)
  endfor
endfunction

function! s:suite.search_with_a_range() abort
  call cursor(1, 1)
  2,5TableopsSearchColumn 3
  call s:found(3, 'range')
endfunction

function! s:suite.search_n_moves_down_the_column() abort
  call cursor(2, 1)
  TableopsSearchColumn 2
  call cursor(1, 1)
  let l:seen = []
  for l:_ in range(5)
    normal! n
    call add(l:seen, [line('.'), col('.')])
  endfor
  call s:assert.equals(l:seen, [[2, 5], [3, 5], [4, 5], [5, 5], [2, 5]])
endfunction

function! s:suite.search_does_not_depend_on_options() abort
  call cursor(2, 1)
  TableopsSearchColumn 2
  set nomagic ignorecase smartcase
  call s:assert.equals(s:matches(), s:want[2])
  TableopsSearchColumn 3
  call s:assert.equals(s:matches(), s:want[3])
endfunction

function! s:suite.search_errors_keep_the_pattern() abort
  call cursor(4, 3)
  TableopsSearchColumn 4
  call s:not_found('no column 4 (the table has 3)')
  execute "normal 4\<Plug>(tableops-search-column)"
  call s:not_found('no column 4 (the table has 3)')
  TableopsSearchColumn x
  call s:not_found('column must be a number: x')
  TableopsSearchColumn 1 2
  call s:not_found('give one column number')
  call cursor(1, 1)
  TableopsSearchColumn
  call s:not_found('not in a table')
  execute "normal \<Plug>(tableops-search-column)"
  call s:not_found('not in a table')
  call cursor(6, 1)
  TableopsSearchColumn 1
  call s:not_found('not in a table')
endfunction

function! s:suite.column_pattern() abort
  call s:assert.equals(tableops#column_pattern(1, 1), '')
  call s:assert.equals(tableops#column_pattern(2, 7), tableops#domain#column#pattern(1))
  call s:assert.equals(@/, 'before')
endfunction
