scriptencoding utf-8

let s:suite = themis#suite('visual')
let s:assert = themis#helper('assert')

let s:H = ['a', 'b', 'c', 'd']
let s:S = ['---', ':--', '--:', ':-:']
let s:R1 = ['1', '2', '3', '4']
let s:R2 = ['5', '6', '7', '8']

function! s:row(cells, cols) abort
  return '|' . join(map(copy(a:cols), '" " . a:cells[v:val] . " "'), '|') . '|'
endfunction

function! s:expect(cols) abort
  return ['intro',
        \ s:row(s:H, a:cols),
        \ '|' . join(map(copy(a:cols), 's:S[v:val]'), '|') . '|',
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
  set selection&
  setlocal modifiable
endfunction

" Select with {keys} from the cursor and delete with the x mode mapping.
function! s:delete(keys) abort
  execute 'normal ' . a:keys . "\<Plug>(tableops-delete-column)"
endfunction

function! s:suite.v_two_columns() abort
  call TableopsTestCursor(4, '2')
  call s:delete('vf3')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
  " the cursor end was deleted: the cell now at its place
  call s:assert.equals([line('.'), TableopsTestChar()], [4, '4'])
  silent undo
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

function! s:suite.v_backwards_and_across_rows() abort
  call TableopsTestCursor(4, '3')
  call s:delete('vF2')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(5, '8')
  call s:delete('vkF2')
  call s:assert.equals(TableopsTestLines(), s:expect([0]))
endfunction

function! s:suite.v_one_cell() abort
  call TableopsTestCursor(2, 'c')
  call s:delete('v')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 1, 3]))
endfunction

function! s:suite.linewise_uses_the_columns_of_both_ends() abort
  call TableopsTestCursor(4, '2')
  call s:delete('Vjf7')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
  " the cursor end stays on its line, on the cell now at its place
  call s:assert.equals([line('.'), TableopsTestChar()], [5, '8'])
endfunction

function! s:suite.blockwise() abort
  call TableopsTestCursor(2, 'b')
  call s:delete("\<C-v>jjf3")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
  call s:assert.equals(line('.'), 4)
  silent undo
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

function! s:suite.blockwise_to_the_end_of_line() abort
  call TableopsTestCursor(4, '3')
  call s:delete("\<C-v>j$")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 1]))
  " $ reaches the last column of the longest row
  call TableopsTestBuffer(['| a | b | c |', '|---|---|---|', '| 1 | 2 |'])
  call TableopsTestCursor(3, '2')
  call s:delete("\<C-v>k$")
  call s:assert.equals(TableopsTestLines(), ['| a |', '|---|', '| 1 |'])
endfunction

function! s:suite.selection_exclusive() abort
  " inclusive: ll ends on the | before 3; an end on a | is the cell on its
  " left
  call TableopsTestCursor(4, '2')
  call s:delete('vll')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " exclusive: that | is not selected
  call TableopsTestBuffer(s:T)
  set selection=exclusive
  call TableopsTestCursor(4, '2')
  call s:delete('vll')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call s:delete("\<C-v>jll")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " f| moves one further with exclusive, so the | is selected: it is the
  " end, so it counts as the cell on its left
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call s:delete('vf|')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " the cursor before the start: the start is selected
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '3')
  call s:delete('vF2')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
endfunction

function! s:suite.full_width_characters_by_screen_column() abort
  let l:wide = ['| 名前名前 | b | c |', '|----------|---|---|', '| ab       | 1 | 2 |']
  call TableopsTestBuffer(l:wide)
  " b is screen column 14 (byte 18); on the last row that is the 1
  call TableopsTestCursor(1, 'b')
  call s:delete("\<C-v>jj")
  call s:assert.equals(TableopsTestLines(), ['| 名前名前 | c |', '|----------|---|', '| ab       | 2 |'])
  call TableopsTestBuffer(l:wide)
  call TableopsTestCursor(3, '1')
  call s:delete("\<C-v>kk")
  call s:assert.equals(TableopsTestLines(), ['| 名前名前 | c |', '|----------|---|', '| ab       | 2 |'])
  call TableopsTestBuffer(l:wide)
  call TableopsTestCursor(1, '前', 2)
  call s:delete('vjjf1')
  call s:assert.equals(TableopsTestLines(), ['| c |', '|---|', '| 2 |'])
endfunction

function! s:suite.count_is_ignored() abort
  call TableopsTestCursor(4, '2')
  call s:delete('vf33')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3]))
endfunction

function! s:suite.errors_change_nothing_and_leave_visual() abort
  " two tables
  let l:two = ['| a | b |', '| 1 | 2 |', '', '| x | y |', '| 3 | 4 |']
  call TableopsTestBuffer(l:two)
  call cursor(1, 3)
  " r after the mapping replaces one character only when Visual mode is gone
  execute "normal v4j\<Plug>(tableops-delete-column)rZ"
  call s:assert.equals(TableopsTestMessage(), '[tableops] selection must be inside one table')
  call s:assert.equals(TableopsTestLines(), l:two[0 : 3] + ['| Z | 4 |'])
  " a line outside the table
  call TableopsTestBuffer(s:T)
  call cursor(1, 1)
  call s:delete('vjjj')
  call s:assert.equals(TableopsTestMessage(), '[tableops] selection must be inside one table')
  call s:assert.equals(TableopsTestLines(), s:T)
  call cursor(6, 1)
  call s:delete('vl')
  call s:assert.equals(TableopsTestMessage(), '[tableops] not in a table')
  call s:assert.equals(TableopsTestLines(), s:T)
  " every column
  call TableopsTestCursor(4, '1')
  call s:delete('v$')
  call s:assert.equals(TableopsTestMessage(), '[tableops] cannot delete every column')
  call s:assert.equals(TableopsTestLines(), s:T)
  " not modifiable
  setlocal nomodifiable
  call TableopsTestCursor(4, '1')
  call s:delete('v')
  call s:assert.equals(TableopsTestMessage(), '[tableops] ''modifiable'' is off (E21)')
  call s:assert.equals(TableopsTestLines(), s:T)
endfunction

function! s:suite.success_leaves_visual() abort
  call TableopsTestCursor(4, '2')
  execute "normal vf3\<Plug>(tableops-delete-column)rZ"
  call s:assert.equals(TableopsTestLines(), s:expect([0, 3])[0 : 2] + ['| 1 | Z |', '| 5 | 8 |', 'outro'])
endfunction

" ---- an end on a | (E2) ------------------------------------------------------

function! s:suite.an_end_on_a_bar_is_the_cell_on_its_left() abort
  " va| selects ' 2 |': one column
  call TableopsTestCursor(4, '2')
  call s:delete("v\<Plug>(tableops-a-cell)")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " vf|
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call s:delete('vf|')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " across rows, ending on a | of the next row
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call s:delete('vjf|')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " backwards: the start is the cursor; on a | it is the cell on its right
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '3')
  call s:delete('vF|')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 1, 3]))
  " a start on a | is the cell on its right
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call cursor(4, col('.') - 2)
  call s:delete('vll')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " only a | selected: the cell on its right
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call cursor(4, col('.') - 2)
  call s:delete('v')
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
endfunction

function! s:suite.blockwise_right_edge_on_a_bar() abort
  call TableopsTestCursor(4, '2')
  call s:delete("\<C-v>jf|")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " the block's left edge on a |: the cell on its right
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call cursor(4, col('.') - 2)
  call s:delete("\<C-v>jf|")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
  " a block one | wide: the cell on its right
  call TableopsTestBuffer(s:T)
  call TableopsTestCursor(4, '2')
  call cursor(4, col('.') - 2)
  call s:delete("\<C-v>j")
  call s:assert.equals(TableopsTestLines(), s:expect([0, 2, 3]))
endfunction
