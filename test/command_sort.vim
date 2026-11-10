scriptencoding utf-8

let s:suite = themis#suite('command_sort')
let s:assert = themis#helper('assert')

let s:T = [
      \ 'intro',
      \ '| k | n  | s   |',
      \ '|---|----|-----|',
      \ '| b | 10 | Bob |',
      \ '| a | 9  | amy |',
      \ '| c | 10 | Cat |',
      \ '| B | x  | bob |',
      \ 'outro']

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  messages clear
endfunction

function! s:suite.after_each() abort
  setlocal modifiable
endfunction

" The first cell of each row: the order of the rows.
function! s:order() abort
  return join(map(getline(4, 7), 'tableops#domain#table#split(v:val)[0]'), '')
endfunction

function! s:unchanged(msg) abort
  call s:assert.equals(TableopsTestLines(), s:T)
  call s:assert.equals(TableopsTestMessage(), '[tableops] ' . a:msg)
endfunction

function! s:around_unchanged() abort
  call s:assert.equals(TableopsTestLines()[0 : 2], s:T[0 : 2])
  call s:assert.equals(getline('$'), 'outro')
endfunction

function! s:suite.sort_cursor_column_first_middle_last() abort
  for [l:lnum, l:ch, l:args, l:want] in [
        \ [4, 'b', '', 'Babc'],
        \ [5, '9', 'n', 'Babc'],
        \ [6, 'Cat', 'i', 'abBc'],
        \ [7, 'bob', '', 'bcaB']]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'TableopsSortColumn' l:args
    call s:assert.equals(s:order(), l:want, l:args . l:ch)
    call s:around_unchanged()
    silent undo
    call s:assert.equals(TableopsTestLines(), s:T)
  endfor
endfunction

function! s:suite.sort_count_first_middle_last_from_anywhere() abort
  " the cursor on the separator row, the header or another column
  for [l:n, l:flags, l:lnum, l:ch, l:want] in [
        \ [1, '', 3, '----', 'Babc'],
        \ [2, 'n', 2, 's', 'Babc'],
        \ [3, 'i', 7, 'B', 'abBc'],
        \ [3, '', 4, '10', 'bcaB']]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'normal ' . l:n . "\<Plug>(tableops-sort-column)" . l:flags . "\<CR>"
    call s:assert.equals(s:order(), l:want, l:n . l:flags)
    call s:around_unchanged()
  endfor
endfunction

function! s:suite.sort_args_column_and_flags() abort
  call cursor(3, 2)
  TableopsSortColumn 2 n
  call s:assert.equals(s:order(), 'Babc')
  silent undo
  TableopsSortColumn n 2
  call s:assert.equals(s:order(), 'Babc')
  silent undo
  TableopsSortColumn 3 i
  call s:assert.equals(s:order(), 'abBc')
  silent undo
  " numeric wins over icase: no numbers, so no change
  let l:tick = changenr()
  TableopsSortColumn 3 ni
  call s:assert.equals(s:order(), 'bacB')
  call s:assert.equals(changenr(), l:tick)
  " string order: '10' < '9' < 'x', equal keys keep their order
  TableopsSortColumn 2
  call s:assert.equals(s:order(), 'bcaB')
endfunction

function! s:suite.sort_reverse() abort
  call cursor(4, 1)
  " numbers reversed, equal keys in their order, no number last
  TableopsSortColumn! 2 n
  call s:assert.equals(s:order(), 'bcaB')
  silent undo
  TableopsSortColumn! 3
  call s:assert.equals(s:order(), 'Bacb')
  silent undo
  TableopsSortColumn!
  call s:assert.equals(s:order(), 'cbaB')
endfunction

function! s:suite.sort_keeps_the_cursor_line_and_column() abort
  call TableopsTestCursor(5, '9')
  TableopsSortColumn n
  call s:assert.equals(line('.'), 5)
  call s:assert.equals(tableops#domain#table#cell_index(getline('.'), col('.')), 1)
  call s:assert.equals(TableopsTestChar(), '9')
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, 'Bob')
  TableopsSortColumn 1
  call s:assert.equals([line('.'), TableopsTestChar()], [4, 'b'])
endfunction

function! s:suite.sort_errors_change_nothing() abort
  call cursor(4, 1)
  TableopsSortColumn 4
  call s:unchanged('no column 4 (the table has 3)')
  execute "normal 4\<Plug>(tableops-sort-column)\<CR>"
  call s:unchanged('no column 4 (the table has 3)')
  TableopsSortColumn 0
  call s:unchanged('no column 0 (the table has 3)')
  TableopsSortColumn x
  call s:unchanged('usage: TableopsSortColumn[!] [N] [n][i]')
  TableopsSortColumn 1 2
  call s:unchanged('usage: TableopsSortColumn[!] [N] [n][i]')
  call cursor(1, 1)
  TableopsSortColumn
  call s:unchanged('not in a table')
  TableopsSortColumn 1
  call s:unchanged('not in a table')
  call cursor(4, 1)
  setlocal nomodifiable
  TableopsSortColumn
  call s:unchanged('''modifiable'' is off (E21)')
endfunction

function! s:suite.sort_with_a_range() abort
  call cursor(1, 1)
  2,7TableopsSortColumn 1
  call s:assert.equals(s:order(), 'Babc')
  call s:assert.equals([line('.'), col('.')], [1, 1])
  silent undo
  call cursor(1, 1)
  2,7TableopsSortColumn
  call s:unchanged('not in a table')
  2,8TableopsSortColumn 1
  call s:unchanged('range must be inside one table')
endfunction

function! s:suite.sort_one_row_or_sorted_is_no_change() abort
  let l:one = ['| k |', '|---|', '| z |']
  call TableopsTestBuffer(l:one)
  let l:tick = changenr()
  call cursor(3, 3)
  TableopsSortColumn
  call s:assert.equals(TableopsTestLines(), l:one)
  call s:assert.equals(changenr(), l:tick)
  let l:sorted = ['| k |', '|---|', '| a |', '| b |']
  call TableopsTestBuffer(l:sorted)
  let l:tick = changenr()
  call cursor(3, 3)
  TableopsSortColumn
  call s:assert.equals(changenr(), l:tick)
endfunction

function! s:suite.sort_headerless_sorts_every_row() abort
  call TableopsTestBuffer(['| b |', '| c |', '| a |'])
  TableopsSortColumn
  call s:assert.equals(TableopsTestLines(), ['| a |', '| b |', '| c |'])
endfunction

function! s:suite.sort_that_would_change_the_structure_is_refused() abort
  " header-less: | - | would come first (unreadable) or second (a separator)
  for l:t in [['| b |', '| x |', '| - |'], ['| x |', '| ! |', '| - |']]
    call TableopsTestBuffer(l:t)
    messages clear
    let l:tick = changenr()
    TableopsSortColumn 1
    call s:assert.equals(TableopsTestLines(), l:t, string(l:t))
    call s:assert.equals(changenr(), l:tick)
    call s:assert.equals(TableopsTestMessage(),
          \ '[tableops] result would change the table structure')
  endfor
  " where it stays a row, the sort is done
  call TableopsTestBuffer(['| b |', '| x |', '| - |'])
  TableopsSortColumn!
  call s:assert.equals(TableopsTestLines(), ['| x |', '| b |', '| - |'])
endfunction
