scriptencoding utf-8

let s:suite = themis#suite('cpo')
let s:assert = themis#helper('assert')

let s:root = fnamemodify(expand('<sfile>:p:h:h'), ':p')

" Every autoload file, sourced again with 'cpoptions' C (no line
" continuation): each must set 'cpoptions' to the Vim default itself.
function! s:suite.autoload_files_load_with_cpo_C() abort
  let l:save = &cpoptions
  set cpoptions+=C
  try
    let l:files = glob(s:root . 'autoload/*.vim', 0, 1)
          \ + glob(s:root . 'autoload/tableops/**/*.vim', 0, 1)
    call s:assert.true(len(l:files) >= 8)
    for l:f in l:files
      execute 'source' fnameescape(l:f)
      call s:assert.equals(&cpoptions, l:save . 'C', l:f)
    endfor
    call TableopsTestBuffer(['|a|bb|', '|-|-|', '|ccc|d|'])
    call cursor(1, 2)
    TableopsFormat
    TableopsDeleteColumn 2
    TableopsSortColumn
    call s:assert.equals(TableopsTestLines(), ['| a   |', '|-----|', '| ccc |'])
    call s:assert.equals(&cpoptions, l:save . 'C')
  finally
    let &cpoptions = l:save
  endtry
endfunction
