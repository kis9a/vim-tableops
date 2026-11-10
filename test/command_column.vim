scriptencoding utf-8

let s:suite = themis#suite('command_column')
let s:assert = themis#helper('assert')

" A formatted table of 4 columns, one character wide, between two lines.
let s:H = ['a', 'b', 'c', 'd']
let s:S = ['---', ':--', '--:', ':-:']
let s:R1 = ['1', '2', '3', '4']
let s:R2 = ['5', '6', '7', '8']

function! s:row(cells, cols) abort
  return '|' . join(map(copy(a:cols), 'v:val < 0 ? "   " : " " . a:cells[v:val] . " "'), '|') . '|'
endfunction

" The buffer with the original columns {cols} (0-based; -1: a new empty one).
function! s:expect(cols) abort
  return ['intro',
        \ s:row(s:H, a:cols),
        \ '|' . join(map(copy(a:cols), 'v:val < 0 ? "---" : s:S[v:val]'), '|') . '|',
        \ s:row(s:R1, a:cols),
        \ s:row(s:R2, a:cols),
        \ 'outro']
endfunction

let s:T = s:expect([0, 1, 2, 3])

function! s:suite.before_each() abort
  call TableopsTestBuffer(s:T)
  messages clear
endfunction

function! s:suite.after_each() abort
  setlocal modifiable
endfunction

function! s:unchanged(msg) abort
  call s:assert.equals(TableopsTestLines(), s:T)
  call s:assert.equals(TableopsTestMessage(), '[tableops] ' . a:msg)
endfunction

function! s:undo_restores() abort
  silent undo
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

" ---- the fixture -------------------------------------------------------------

function! s:suite.fixture_is_formatted() abort
  call s:assert.equals(s:T[1:4], ['| a | b | c | d |', '|---|:--|--:|:-:|',
        \ '| 1 | 2 | 3 | 4 |', '| 5 | 6 | 7 | 8 |'])
endfunction

" ---- delete: no count / count x first, middle, last -------------------------

function! s:suite.delete_cursor_column_first_middle_last() abort
  for [l:ch, l:cols] in [['1', [1, 2, 3]], ['2', [0, 2, 3]], ['4', [0, 1, 2]]]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(4, l:ch)
    TableopsDeleteColumn
    call s:assert.equals(TableopsTestLines(), s:expect(l:cols), l:ch)
    call s:assert.equals(line('.'), 4)
    call s:undo_restores()
  endfor
endfunction

function! s:suite.delete_count_first_middle_last_from_anywhere() abort
  " the cursor is on the separator row or on another column
  for [l:n, l:cols, l:lnum, l:ch] in [
        \ [1, [1, 2, 3], 3, '-:'], [2, [0, 2, 3], 5, '8'], [4, [0, 1, 2], 2, 'a'],
        \ [3, [0, 1, 3], 3, ':--']]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'normal ' . l:n . "\<Plug>(tableops-delete-column)"
    call s:assert.equals(TableopsTestLines(), s:expect(l:cols), l:n)
    call s:undo_restores()
  endfor
endfunction

function! s:suite.delete_args_first_middle_last() abort
  for [l:args, l:cols] in [['1', [1, 2, 3]], ['3', [0, 1, 3]], ['4', [0, 1, 2]]]
    call TableopsTestBuffer(s:T)
    call cursor(3, 1)
    execute 'TableopsDeleteColumn' l:args
    call s:assert.equals(TableopsTestLines(), s:expect(l:cols), l:args)
  endfor
endfunction

function! s:suite.delete_many_is_one_undo_and_order_free() abort
  call TableopsTestCursor(4, '1')
  TableopsDeleteColumn 2 4
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2]))
  call s:undo_restores()
  call TableopsTestCloseUndo()
  TableopsDeleteColumn 4 2 2
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2]))
  call s:undo_restores()
endfunction

function! s:suite.delete_cursor_stays_on_its_cell() abort
  call TableopsTestCursor(4, '3')
  TableopsDeleteColumn 1 2
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '3'])
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(5, '7')
  execute "normal 4\<Plug>(tableops-delete-column)"
  call s:assert.equals([line('.'), TableopsTestChar()], [5, '7'])
endfunction

function! s:suite.delete_cursor_goes_to_the_neighbour() abort
  " the cell is gone: the cell now at its place
  call TableopsTestCursor(4, '2')
  TableopsDeleteColumn
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '3'])
  " the last cell is gone: the new last cell
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(5, '8')
  TableopsDeleteColumn 3 4
  call s:assert.equals([line('.'), TableopsTestChar()], [5, '6'])
  " on the separator row: the start of the cell
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(3, '--:')
  TableopsDeleteColumn 2
  call s:assert.equals([line('.'), col('.')], [3, 6])
endfunction

function! s:suite.delete_too_large_or_bad_column() abort
  call TableopsTestCursor(4, '2')
  execute "normal 5\<Plug>(tableops-delete-column)"
  call s:unchanged('no column 5 (the table has 4)')
  TableopsDeleteColumn 2 5
  call s:unchanged('no column 5 (the table has 4)')
  TableopsDeleteColumn 0
  call s:unchanged('no column 0 (the table has 4)')
  TableopsDeleteColumn x
  call s:unchanged('column must be a number: x')
  TableopsDeleteColumn -1
  call s:unchanged('column must be a number: -1')
endfunction

function! s:suite.delete_every_column_is_an_error() abort
  call TableopsTestCursor(4, '2')
  TableopsDeleteColumn 4 3 2 1
  call s:unchanged('cannot delete every column')
endfunction

function! s:suite.delete_outside_a_table() abort
  call cursor(1, 1)
  TableopsDeleteColumn
  call s:unchanged('not in a table')
  TableopsDeleteColumn 2
  call s:unchanged('not in a table')
  execute "normal \<Plug>(tableops-delete-column)"
  call s:unchanged('not in a table')
  execute "normal 2\<Plug>(tableops-delete-column)"
  call s:unchanged('not in a table')
  call cursor(6, 1)
  execute "normal \<Plug>(tableops-delete-column)"
  call s:unchanged('not in a table')
endfunction

function! s:suite.delete_with_a_range() abort
  " the range picks the table; the cursor outside does not move
  call cursor(1, 2)
  2,5TableopsDeleteColumn 3
  call s:assert.equals(TableopsTestLines(), s:expect([0, 1, 3]))
  call s:assert.equals([line('.'), col('.')], [1, 2])
  call s:undo_restores()
  " no column and no cursor column
  2,5TableopsDeleteColumn
  call s:unchanged('not in a table')
  " the range leaves the table
  call cursor(4, 3)
  2,6TableopsDeleteColumn 2
  call s:unchanged('range must be inside one table')
  1,3TableopsDeleteColumn 2
  call s:unchanged('not in a table')
endfunction

function! s:suite.delete_nomodifiable() abort
  call TableopsTestCursor(4, '2')
  setlocal nomodifiable
  TableopsDeleteColumn
  call s:unchanged('''modifiable'' is off (E21)')
  execute "normal \<Plug>(tableops-delete-column)"
  call s:unchanged('''modifiable'' is off (E21)')
endfunction

function! s:suite.delete_example_of_the_requirement() abort
  call TableopsTestBuffer([
        \ '| name | 年齢 | city \| area |',
        \ '|:-----|-----:|:------------:|',
        \ '| foo  |   12 | tokyo        |'])
  call TableopsTestCursor(3, '12')
  TableopsDeleteColumn
  call s:assert.equals(TableopsTestLines(), [
        \ '| name | city \| area |',
        \ '|:-----|:------------:|',
        \ '| foo  | tokyo        |'])
  call s:assert.equals([line('.'), TableopsTestChar()], [3, 't'])
endfunction

function! s:suite.delete_headerless_and_indented() abort
  call TableopsTestBuffer(['  | a | b | c |', '  | 1 | 2 |'])
  call TableopsTestCursor(2, '1')
  TableopsDeleteColumn 2
  call s:assert.equals(TableopsTestLines(), ['  | a | c |', '  | 1 |   |'])
endfunction

function! s:suite.delete_crlf_and_malformed() abort
  call TableopsTestBuffer(['| a | b |' . "\r", '| 1 | 2 |'])
  TableopsDeleteColumn 1
  call s:assert.equals(TableopsTestLines(), ['| a | b |' . "\r", '| 1 | 2 |'])
  call s:assert.equals(TableopsTestMessage(), '[tableops] CR line endings: try :e ++ff=dos')
  call TableopsTestBuffer(['|---|---|', '| 1 | 2 |'])
  TableopsDeleteColumn 1
  call s:assert.equals(TableopsTestLines(), ['|---|---|', '| 1 | 2 |'])
  call s:assert.equals(TableopsTestMessage(), '[tableops] the table starts with a separator row')
endfunction

function! s:suite.delete_leaves_the_lines_around() abort
  " the lines around the table are not touched
  call TableopsTestBuffer(['intro', '| a | b |', '| 1 | 2 |', 'outro'])
  call TableopsTestCursor(3, '2')
  TableopsDeleteColumn
  call s:assert.equals(TableopsTestLines(), ['intro', '| a |', '| 1 |', 'outro'])
endfunction

" ---- insert ------------------------------------------------------------------

function! s:suite.insert_cursor_column_first_middle_last() abort
  for [l:ch, l:after, l:before] in [
        \ ['1', [0, -1, 1, 2, 3], [-1, 0, 1, 2, 3]],
        \ ['2', [0, 1, -1, 2, 3], [0, -1, 1, 2, 3]],
        \ ['4', [0, 1, 2, 3, -1], [0, 1, 2, -1, 3]]]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(4, l:ch)
    TableopsInsertColumn
    call s:assert.equals(TableopsTestLines(), s:expect(l:after), l:ch)
    call s:assert.equals([line('.'), TableopsTestChar()], [4, l:ch])
    call s:undo_restores()
    call TableopsTestCursor(4, l:ch)
    TableopsInsertColumn!
    call s:assert.equals(TableopsTestLines(), s:expect(l:before), l:ch . '!')
    call s:assert.equals([line('.'), TableopsTestChar()], [4, l:ch])
    call s:undo_restores()
  endfor
endfunction

function! s:suite.insert_count_first_middle_last_from_anywhere() abort
  for [l:n, l:after, l:before, l:lnum, l:ch] in [
        \ [1, [0, -1, 1, 2, 3], [-1, 0, 1, 2, 3], 3, ':-:'],
        \ [2, [0, 1, -1, 2, 3], [0, -1, 1, 2, 3], 5, '8'],
        \ [4, [0, 1, 2, 3, -1], [0, 1, 2, -1, 3], 2, 'a']]
    call TableopsTestBuffer(s:T)
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'normal ' . l:n . "\<Plug>(tableops-insert-column-after)"
    call s:assert.equals(TableopsTestLines(), s:expect(l:after), l:n)
    call s:undo_restores()
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'normal ' . l:n . "\<Plug>(tableops-insert-column-before)"
    call s:assert.equals(TableopsTestLines(), s:expect(l:before), l:n)
    call s:undo_restores()
    call TableopsTestCursor(l:lnum, l:ch)
    execute 'TableopsInsertColumn' l:n
    call s:assert.equals(TableopsTestLines(), s:expect(l:after), l:n)
    call s:undo_restores()
  endfor
endfunction

function! s:suite.insert_errors() abort
  call TableopsTestCursor(4, '2')
  TableopsInsertColumn 5
  call s:unchanged('no column 5 (the table has 4)')
  execute "normal 9\<Plug>(tableops-insert-column-before)"
  call s:unchanged('no column 9 (the table has 4)')
  TableopsInsertColumn 1 2
  call s:unchanged('give one column number')
  TableopsInsertColumn! x
  call s:unchanged('column must be a number: x')
  call cursor(1, 1)
  TableopsInsertColumn
  call s:unchanged('not in a table')
  execute "normal \<Plug>(tableops-insert-column-after)"
  call s:unchanged('not in a table')
  call cursor(4, 1)
  setlocal nomodifiable
  TableopsInsertColumn
  call s:unchanged('''modifiable'' is off (E21)')
endfunction

function! s:suite.insert_into_a_headerless_table() abort
  call TableopsTestBuffer(['| a | b |', '| 1 | 2 |'])
  TableopsInsertColumn 1
  call s:assert.equals(TableopsTestLines(), ['| a |   | b |', '| 1 |   | 2 |'])
endfunction

" ---- move --------------------------------------------------------------------

function! s:suite.move_right_and_left() abort
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn 1
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 1, 3]))
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '2'])
  call s:undo_restores()
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn -1
  call s:assert.equals(TableopsTestLines(), s:expect([1, 0, 2, 3]))
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '2'])
  call s:undo_restores()
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn +9
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3, 1]))
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '2'])
endfunction

function! s:suite.move_with_count_is_a_distance() abort
  call TableopsTestCursor(5, '5')
  execute "normal 2\<Plug>(tableops-move-column-right)"
  call s:assert.equals(TableopsTestLines(), s:expect([1, 2, 0, 3]))
  call s:assert.equals([line('.'), TableopsTestChar()], [5, '5'])
  execute "normal \<Plug>(tableops-move-column-left)"
  call s:assert.equals(TableopsTestLines(), s:expect([1, 0, 2, 3]))
  call s:assert.equals([line('.'), TableopsTestChar()], [5, '5'])
endfunction

function! s:suite.move_at_the_edge_zero_and_errors() abort
  call TableopsTestCursor(4, '1')
  let l:tick = changenr()
  TableopsMoveColumn -1
  call s:unchanged('column is already at the edge')
  call s:assert.equals(changenr(), l:tick)
  messages clear
  TableopsMoveColumn 0
  call s:assert.equals(TableopsTestLines(), s:T)
  call s:assert.equals(TableopsTestMessage() =~# 'tableops', 0)
  TableopsMoveColumn x
  call s:unchanged('usage: TableopsMoveColumn {N}')
  TableopsMoveColumn 1 2
  call s:unchanged('usage: TableopsMoveColumn {N}')
  call cursor(1, 1)
  TableopsMoveColumn 1
  call s:unchanged('not in a table')
  call cursor(4, 1)
  setlocal nomodifiable
  TableopsMoveColumn 1
  call s:unchanged('''modifiable'' is off (E21)')
endfunction

function! s:suite.move_a_huge_distance_stops_at_the_edge() abort
  " c + delta must not overflow (and move the wrong way)
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn 99999999999999999999
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3, 1]))
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '2'])
  call s:undo_restores()
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn -99999999999999999999
  call s:assert.equals(TableopsTestLines(), s:expect([1, 0, 2, 3]))
  call s:undo_restores()
  call TableopsTestCursor(4, '2')
  TableopsMoveColumn 9223372036854775807
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3, 1]))
endfunction

" ---- a result that would read back as another table --------------------------

function! s:suite.delete_that_would_make_a_separator_row_is_refused() abort
  " header-less: row 2 would be only '-' cells, and 'name' a header
  let l:t = ['| name | score |', '| foo  | -     |', '| bar  | 3     |']
  call TableopsTestBuffer(l:t)
  call cursor(1, 3)
  let l:tick = changenr()
  let l:r = tableops#delete_column(1, 1, 0, '1')
  call s:assert.equals([l:r.ok, l:r.code], [0, 'ambiguous'])
  call s:assert.equals(TableopsTestLines(), l:t)
  call s:assert.equals(changenr(), l:tick)
  call s:assert.equals(TableopsTestMessage(),
        \ '[tableops] result would change the table structure')
  " in Visual mode too
  messages clear
  call cursor(2, 3)
  execute "normal v\<Plug>(tableops-delete-column)"
  call s:assert.equals(TableopsTestLines(), l:t)
  call s:assert.equals(TableopsTestMessage(),
        \ '[tableops] result would change the table structure')
  " the header would be a separator row: the table could not be read
  let l:t = ['| - | a |', '|---|---|', '| 1 | 2 |']
  call TableopsTestBuffer(l:t)
  TableopsDeleteColumn 2
  call s:assert.equals(TableopsTestLines(), l:t)
  call s:assert.equals(changenr(), l:tick)
  " a delete that keeps the shape still works
  call TableopsTestBuffer(['| name | score |', '| foo  | -     |', '| bar  | 3     |'])
  TableopsDeleteColumn 2
  call s:assert.equals(TableopsTestLines(), ['| name |', '| foo  |', '| bar  |'])
endfunction

" ---- every Result has changed (E7) --------------------------------------------

function! s:suite.every_result_has_changed() abort
  let l:calls = [
        \ ['outside', 1, 'tableops#format(1, 1, 0)'],
        \ ['outside', 1, 'tableops#delete_column(1, 1, 0, "")'],
        \ ['outside', 1, 'tableops#delete_column_count(0)'],
        \ ['outside', 1, 'tableops#insert_column(1, 1, 0, 0, "")'],
        \ ['outside', 1, 'tableops#insert_column_count(0, 0)'],
        \ ['outside', 1, 'tableops#move_column("1")'],
        \ ['outside', 1, 'tableops#sort_column(1, 1, 0, 0, "")'],
        \ ['outside', 1, 'tableops#columns(1, 1, 0)'],
        \ ['outside', 1, 'tableops#delete_column_visual()'],
        \ ['bad', 4, 'tableops#delete_column(4, 4, 0, "9")'],
        \ ['bad', 4, 'tableops#insert_column(4, 4, 0, 0, "1 2")'],
        \ ['bad', 4, 'tableops#move_column("x")'],
        \ ['bad', 4, 'tableops#sort_column(4, 4, 0, 0, "q")'],
        \ ['bad', 4, 'tableops#delete_column(4, 4, 0, "1 2 3 4")'],
        \ ['ok', 4, 'tableops#columns(4, 4, 0)'],
        \ ['ok', 4, 'tableops#format_at(1)'],
        \ ['ok', 4, 'tableops#move_column("0")'],
        \ ['ok', 4, 'tableops#move_column("-1")'],
        \ ]
  for [l:kind, l:lnum, l:expr] in l:calls
    call TableopsTestBuffer(s:T)
    call cursor(l:lnum, 3)
    silent let l:r = eval(l:expr)
    call s:assert.has_key(l:r, 'changed', l:expr)
    call s:assert.equals([l:r.ok, l:r.changed], [l:kind ==# 'ok', 0], l:expr)
  endfor
  setlocal nomodifiable
  call cursor(4, 3)
  silent let l:r = tableops#delete_column(4, 4, 0, '')
  call s:assert.equals([l:r.ok, l:r.code, l:r.changed], [0, 'not_modifiable', 0])
endfunction
