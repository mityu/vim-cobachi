vim9script

import "../cobachi.vim" as Cobachi

def StrcolList(haystack: string, needle: string): list<list<number>>
  var matches = []
  var start = 0
  const width = strlen(needle)
  while true
    const m = stridx(haystack, needle, start)
    if m == -1
      break
    endif
    matches->add([m + 1, width])  # Convert index into column.
    start = m + width
  endwhile
  return matches
enddef

# Ignorecase substring filter.
export def Substring(text: string, items: list<string>): Cobachi.FilterResult
  const matchers = text->tolower()->split()

  if empty(matchers)
    return [items, []]
  endif

  var filtered = []
  var matchposlist = []
  foreach(items, (idx: number, v: string) => {
    var matchpos = []
    for matcher in matchers
      var m = StrcolList(v->tolower(), matcher)
      if m->empty()
        return
      endif
      matchpos->extend(m)
    endfor
    matchposlist->add(matchpos)
    filtered->add(v)
  })
  return [filtered, matchposlist]
enddef

export def Regex(text: string, items: list<string>): Cobachi.FilterResult
  const matchers = text
    ->split('\v%(^|[^\\])%(\\\\)*\zs\s+')
    ->filter((_: number, v: string): bool => v !=# '')
    ->map((_: number, v: string): string =>
      substitute(v, '\v%(^|[^\\])%(\\\\)*\zs\\\ze\s', '', 'g'))

  if empty(matchers)
    return [items, []]
  endif

  var filtered = []
  var matchposlist = []
  foreach(items, (idx: number, v: string) => {
    var matchpos = []
    for matcher in matchers
      var m = matchstrpos(v, matcher)
      if m == ['', -1, -1]
        return
      endif
      matchpos->add([m[1] + 1, m[2] - m[1]])
      while true
        m = matchstrpos(v, matcher, m[2])
        if m == ['', -1, -1]
          break
        endif
        matchpos->add([m[1] + 1, m[2] - m[1]])
      endwhile
    endfor
    matchposlist->add(matchpos)
    filtered->add(v)
  })
  return [filtered, matchposlist]
enddef
