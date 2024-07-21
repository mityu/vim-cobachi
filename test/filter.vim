import autoload "cobachi/filter.vim" as F

const s:assert = themis#helper('assert')

let s:suite = themis#suite('filter#Substring()')

function s:suite.check_match()
  const [items, highlights] = s:F.Substring('a', ['a', 'aa', 'b'])
  call s:assert.equals(items, ['a', 'aa'])
  call s:assert.length_of(highlights, 2)
  call s:assert.equals(highlights[0], [[1, 1]])
  call s:assert.equals(highlights[1], [[1, 1], [2, 1]])
endfunction

function s:suite.check_ignorecase()
  const [items, highlights] = s:F.Substring('a', ['A'])
  call s:assert.equals(items, ['A'])
  call s:assert.length_of(highlights, 1)
  call s:assert.equals(highlights[0], [[1, 1]])
endfunction

function s:suite.check_split_input()
  const [items, highlights] = s:F.Substring('ab xyz', ['xyzabc', 'abc', 'xyz', 'abc xyz'])
  call s:assert.equals(items, ['xyzabc', 'abc xyz'])
  call s:assert.length_of(highlights, 2)
  call s:assert.equals(highlights[0]->sort(), [[1, 3], [4, 2]])
  call s:assert.equals(highlights[1]->sort(), [[1, 2], [5, 3]])
endfunction

let s:suite = themis#suite('filter#Regex()')

function s:suite.before()
  set ignorecase
endfunction

function s:suite.after()
  set ignorecase&
endfunction

function s:suite.check_match_substring()
  const [items, highlights] = s:F.Regex('a', ['a', 'aa', 'b'])
  call s:assert.equals(items, ['a', 'aa'])
  call s:assert.length_of(highlights, 2)
  call s:assert.equals(highlights[0], [[1, 1]])
  call s:assert.equals(highlights[1], [[1, 1], [2, 1]])
endfunction

function s:suite.check_match_regex()
  const [items, highlights] = s:F.Regex('a$', ['a', 'aa', 'ab', 'b'])
  call s:assert.equals(items, ['a', 'aa'])
  call s:assert.length_of(highlights, 2)
  call s:assert.equals(highlights[0], [[1, 1]])
  call s:assert.equals(highlights[1], [[2, 1]])
endfunction

function s:suite.check_ignorecase()
  const [items, highlights] = s:F.Regex('a', ['A'])
  call s:assert.equals(items, ['A'])
  call s:assert.length_of(highlights, 1)
  call s:assert.equals(highlights[0], [[1, 1]])
endfunction

function s:suite.check_split_input()
  const [items, highlights] = s:F.Regex('ab\S xyz', ['xyzabc', 'abc', 'xyz', 'abc xyz'])
  call s:assert.equals(items, ['xyzabc', 'abc xyz'])
  call s:assert.length_of(highlights, 2)
  call s:assert.equals(highlights[0]->sort(), [[1, 3], [4, 3]])
  call s:assert.equals(highlights[1]->sort(), [[1, 3], [5, 3]])
endfunction
