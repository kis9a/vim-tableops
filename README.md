# vim-tableops

Edit Markdown tables by column and by cell.

Delete, insert, move and sort whole columns of a Markdown table, put the
pattern of a column in `@/`, reformat the table, and move between cells or
select one. The table is read into a list of cells, changed as a list and
written back, so `\|` in a cell, the alignment of the separator row
(`:---:`) and the width of wide characters are kept.

```
| name | 年齢 | city \| area |                            | name | city \| area |
|:-----|-----:|:------------:|  :TableopsDeleteColumn 2  |:-----|:------------:|
| foo  |   12 | tokyo        |            ->             | foo  | tokyo        |
```

A count or an argument is a column number, so the cursor can be anywhere
in the table. One `u` undoes a whole command, and lines outside the table
never change.

## Installation

```vim
" vim-plug
Plug 'kis9a/vim-tableops'
```

Vim 9.0+ / Neovim 0.9+ (an older one loads nothing). No other plugin is
needed.

## Features

### Commands

| Command | Description |
|---|---|
| `:[range]TableopsFormat` | Align the table (with a range: every table in it) |
| `:[range]TableopsDeleteColumn [N ...]` | Delete column N, or the cursor column; several at once (`2 4`) |
| `:[range]TableopsInsertColumn[!] [N]` | Insert an empty column right of column N (`!`: left) |
| `:TableopsMoveColumn {N}` | Move the cursor column N columns (`-1` left, `1` right); stops at the edge |
| `:[range]TableopsSortColumn[!] [N] [n][i]` | Sort the rows by column N: `n` numeric, `i` ignore case, `!` reverse; stable |
| `:[range]TableopsSearchColumn [N]` | Put the pattern of column N in `@/` and highlight it |
| `:[range]TableopsColumns` | Show the column numbers: `1:name  2:年齢  3:city \\| area` |

- Without a range a command works on the table of the cursor line; a range
  only chooses the table (its first line), never a column.
- Column numbers start at 1. Without one, the cursor column is used. A
  number that is 0, not a number, or larger than the number of columns is
  an error and nothing changes. Outside a table: `not in a table`.
- After a delete, insert or move the cursor stays in its cell (when its
  cell was deleted, the cell now at its place on the same line).
- Only the lines that change are written; an aligned table is not touched.
- A change that would make the table read differently is refused
  (`result would change the table structure`): in a table without a
  header, a delete or sort that leaves a row of `-` cells first or second
  (it would become a separator row).

### Counts

A count is a column number (1-based), like the argument of a command:

| Operation | No count | Count N |
|---|---|---|
| Delete | cursor column | column N |
| Insert after / before | right / left of the cursor column | right / left of column N |
| Sort | by the cursor column | by column N |
| Search (`@/`) | cursor column | column N |
| Move left / right | 1 column | N columns (a distance, as for `h` / `l`) |

The cursor may be on any row and cell of the table, the separator row
too. (Unlike vim-table-mode, where a count means "N columns to the right".)

The delete, insert and move mappings repeat with `.` (no vim-repeat):
`.` uses the same count (`3{key}..` deletes the original columns 3 to 5),
a count-less `.` uses the cursor column again, and `2.` uses 2. A Visual
delete is not repeated by `.`.

### Mappings

No keys are mapped. These `<Plug>` mappings exist (`:help tableops-mappings`):

| `<Plug>` | Modes | Does |
|---|---|---|
| `<Plug>(tableops-format)` | n | `:TableopsFormat` |
| `<Plug>(tableops-delete-column)` | n x | Delete the column; in Visual mode every column the selection touches |
| `<Plug>(tableops-insert-column-after)` | n | Insert a column on the right |
| `<Plug>(tableops-insert-column-before)` | n | Insert a column on the left |
| `<Plug>(tableops-move-column-left)` | n | Move the column left |
| `<Plug>(tableops-move-column-right)` | n | Move the column right |
| `<Plug>(tableops-sort-column)` | n | Stops on `:TableopsSortColumn [N] ` for the flags |
| `<Plug>(tableops-search-column)` | n | `:TableopsSearchColumn` |
| `<Plug>(tableops-columns)` | n | `:TableopsColumns` |
| `<Plug>(tableops-cell-left)` / `-right` | n x o | Previous / next cell; wraps to the previous / next row in n and x |
| `<Plug>(tableops-cell-up)` / `-down` | n x o | Same cell on the row above / below; skips the separator row |
| `<Plug>(tableops-inner-cell)` | x o | The cell text without the blanks around it |
| `<Plug>(tableops-a-cell)` | x o | The cell with its blanks, through the closing `\|` |

In Operator-pending mode left and right never leave the line (`d]|` does
not join rows) and up and down are linewise (`d}|` deletes the cursor row
and the row below) but never take the separator row (`d}|` on the header
is cancelled). When there is no target (outside a table, at the edge, on
or across the separator row, `i|` on a zero-width cell `||`) the operator
is cancelled: `c` does not start Insert mode and `y` keeps the unnamed
register. `i|` on a blank cell `|   |` selects its blanks. A `.` cannot be
cancelled: `d}|` then `.` on the last row deletes that row, and `ci|NEW`
then `.` on the separator row (or outside the table) writes `NEW` there.

The cursor of a zero-width cell `||` is its closing `|`.

In Visual mode `<Plug>(tableops-delete-column)` finds the columns by the
screen column of both ends of the selection (`v`, `V` or `CTRL-V`; wide
characters do not shift it). Both ends must be in one table. A `|` at the
end of the selection (or the right edge of a block) is the cell on its
left, at the start the cell on its right: `va|` or `vf|` from a cell
deletes that one column.

### Functions

`tableops#format_at(lnum)` formats the table of a line and is silent
outside a table; `tableops#column_pattern(lnum, col)` returns the pattern
of a column. The command functions return a Result with `ok`, `code` and
`changed` (0 on a failure). See `:help tableops-functions`.

### Options

None; `let g:loaded_tableops = 1` disables the plugin.

## Configuration

### Key Mappings (Example)

Keys for Markdown buffers only. The `b:tableops_maps` guard and
`b:undo_ftplugin` keep a second `FileType` event (`:e`, `:set ft=markdown`)
from raising E227 with `<unique>`:

```vim
function! s:tableops_maps() abort
  if exists('b:tableops_maps')
    return
  endif
  let b:tableops_maps = 1
  let l:undo = ['unlet! b:tableops_maps']
  for [l:modes, l:lhs, l:name] in [
        \ ['n',   '<Leader>tf',    'format'],
        \ ['nx',  '<Leader>tx',    'delete-column'],
        \ ['n',   '<Leader>ta',    'insert-column-after'],
        \ ['n',   '<Leader>ti',    'insert-column-before'],
        \ ['n',   '<Leader>t<lt>', 'move-column-left'],
        \ ['n',   '<Leader>t>',    'move-column-right'],
        \ ['n',   '<Leader>to',    'sort-column'],
        \ ['n',   '<Leader>t/',    'search-column'],
        \ ['n',   '<Leader>tc',    'columns'],
        \ ['nxo', '[<Bar>',        'cell-left'],
        \ ['nxo', ']<Bar>',        'cell-right'],
        \ ['nxo', '{<Bar>',        'cell-up'],
        \ ['nxo', '}<Bar>',        'cell-down'],
        \ ['xo',  'i<Bar>',        'inner-cell'],
        \ ['xo',  'a<Bar>',        'a-cell']]
    for l:m in split(l:modes, '\zs')
      execute printf('%smap <buffer> <unique> %s <Plug>(tableops-%s)',
            \ l:m, l:lhs, l:name)
      call add(l:undo, printf('silent! %sunmap <buffer> %s', l:m, l:lhs))
    endfor
  endfor
  " ours first: an existing one may end in ':autocmd! ... <buffer>'
  let b:undo_ftplugin = join(l:undo, '|')
        \ . (exists('b:undo_ftplugin') && b:undo_ftplugin !=# ''
        \ ? '|' . b:undo_ftplugin : '')
endfunction
augroup my_tableops
  autocmd!
  autocmd FileType markdown call s:tableops_maps()
augroup END
" Neovim: the file opened at startup gets its FileType before this point
if &filetype ==# 'markdown'
  call s:tableops_maps()
endif
```

| Key | Does |
|---|---|
| `<Leader>tf` | Format |
| `<Leader>tx` | Delete the column (n, x) |
| `<Leader>ta` / `<Leader>ti` | Insert a column after / before |
| `<Leader>t<` / `<Leader>t>` | Move the column left / right |
| `<Leader>to` | Sort (order) |
| `<Leader>t/` | Search the column |
| `<Leader>tc` | Show the column numbers |
| `[\|` `]\|` `{\|` `}\|` | Cell left / right / up / down (n, x, o) |
| `i\|` `a\|` | Cell text objects (x, o) |

Write `|` as `<Bar>` in a mapping and `<` as `<lt>`. Join the undo
commands with `|` and no blanks: `:unmap` takes trailing blanks as part of
the key. Put them before an existing `b:undo_ftplugin`: one that ends in
`autocmd! {group} * <buffer>` would swallow a `|` and what follows (E1155).
In Neovim the file given on the command line gets its `FileType` while
the vimrc is still running (around `plug#end()`), so call the function
once for the current buffer after the augroup. Define the augroup after `filetype plugin on` (vim-plug: after
`plug#end()`); otherwise the ftplugin's own `FileType` autocommand runs
after it, executes `b:undo_ftplugin` and removes the maps. `{|` and `}|` make the plain `{` and `}` wait for `'timeoutlen'`
in these buffers.

### Short Command Names (Example)

The plugin defines only the `Tableops` names. Aliases like these pass the
range, `!` and the arguments through (`:help tableops-aliases`):

```vim
command! -range -bar TF <line1>,<line2>TableopsFormat
command! -range -nargs=* -bar TX <line1>,<line2>TableopsDeleteColumn <args>
command! -range -nargs=? -bang -bar TI <line1>,<line2>TableopsInsertColumn<bang> <args>
command! -nargs=1 -bar TM TableopsMoveColumn <args>
command! -range -nargs=* -bang -bar TO <line1>,<line2>TableopsSortColumn<bang> <args>
command! -range -nargs=? -bar TS <line1>,<line2>TableopsSearchColumn <args>
command! -range -bar TC <line1>,<line2>TableopsColumns
```

No argument contains `|`, so `-bar` is fine on all of them.

### Using with vim-rxops

[vim-rxops](https://github.com/kis9a/vim-rxops) works on the matches of
`@/`, so the column pattern turns its `...Matches` commands into column
commands. With its aliases `DM`, `KM`, `YM` and `SM`:

```vim
:TableopsSearchColumn 2
vip
:DM            " the command line is :'<,'>DM
```

```
| name | city \| area |
|:-----|:------------:|
| foo  | tokyo        |
```

- `:'<,'>KM` keeps only the column, one cell per line; `:'<,'>YM` yanks
  it; `:'<,'>SM /tokyo/Kyoto/` substitutes only inside it.
- Select the table first (`vip`): without a range rxops works on the whole
  buffer.
- The pattern of column N (very magic, `C` is one cell character):

  ```
  \v^\s*%(\|C*){N-1}\zs\|%(\s*$)@!C*      C = %(\\\||\\%(\|)@!|[^|\\])
  ```

  It matches the `|` before the cell and the cell text up to the next `|`,
  reads `\|` as part of the cell, and never matches the closing `|`. So
  `DM` on the last column leaves the closing `|`, which then closes the new
  last column.

### Formatting on InsertLeave

The plugin defines no autocommands. To align the table each time you
leave Insert mode:

```vim
augroup my_tableops_format
  autocmd!
  autocmd InsertLeave *.md call tableops#format_at(line('.'))
augroup END
```

The formatting joins the undo step of what you typed: one `u` undoes the
typing and the formatting together. `|` lines in code blocks are formatted
too. A block insert (`<C-v>jI`) is not aligned: InsertLeave runs before
Vim copies the text to the other rows; run `:TableopsFormat` after it.

## Text format

- A table is a run of lines that start with `|` (after blanks). The indent
  of its first line is kept for every row.
- The second line is the separator row when every cell is empty or
  `---` / `:---` / `---:` / `:---:` and at least one has a `-`
  (`| --- | |` is one). Then the first line is the header; otherwise the
  table has no header and none is added.
- `\|` is always a character of the cell (`\\|` is `\` and `\|`); other
  `\` are ordinary. The closing `|` is optional. Short rows get empty cells.
- Output: `| a | b |` with one blank on each side, the closing `|` always,
  columns as wide as the widest cell (`strwidth()`, at least 1; not
  changed by `'showbreak'`, `'list'` or the window width).
  `---:` columns are right-aligned; all others, centered `:---:` ones
  too, are padded on the right. The separator row is `|:---|---:|`, each
  cell the column width + 2 long, with its colons kept.
- Refused: a table whose first line is a separator row, and a table with
  CR line endings (open the file with `:e ++ff=dos`).

## Privacy

Nothing is sent anywhere, and no file is read or written.

## Limitations

- GFM tables without the leading `|`, reST and grid tables are not
  supported. Code blocks are not detected.
- Tables with CR line endings or starting with a separator row are refused.
- A tab inside a cell cannot be aligned; widths follow the current
  `'ambiwidth'`.
- `.` repeats with the current `'operatorfunc'`: another `g@` operator
  started and cancelled in between takes it over. A Visual delete is not
  repeated by `.`.
- An Operator-pending cell motion or a cell text object repeated with `.`
  cannot be cancelled when its target is gone: `d}|` then `.` on the last
  row deletes that row; `ci|` then `.` on the separator row writes into it.
- Each cell motion reads the whole table again: about 25 ms per motion in
  a table of 10,000 rows.
- A delete or sort that would turn a row of `-` cells into the separator
  row of a header-less table (or put it first) is refused.
- `:TableopsSearchColumn` sets only `v:hlsearch`; `'hlsearch'` must be on
  for the highlight. On a row without the closing `|`, an empty last cell
  is not matched.
- In an unformatted row with an empty cell (`|a||b|`), the `|` after the
  empty cell belongs to the empty cell: `n` after `:TableopsSearchColumn`
  stops there, and a column command run there targets the column on its
  left. Format the table first.
- The numeric sort reads the first number: `1,000` sorts as 1.
- Vim 9.0 and Neovim 0.9 are not tested; the tests run on Vim 9.2 and
  Neovim 0.12.

See `:help tableops-limitations`.

## Development

```sh
make deps && make test && make lint
```

`make test` runs vim-themis on Vim and Neovim.

## LICENSE

MIT. See [LICENSE](LICENSE).
