vim9script

export type FilterResult = list<any>  # [list<string>, list<list<number>>]
type FilterFn = func(string, list<string>): FilterResult

def PrintError(msg: string)
  echohl Error
  for m in msg->split("\n")
    echomsg '[cobachi]' m
  endfor
  echohl None
enddef

# Create new buffer for FF and returns its bufnr.
def CreateNewBuffer(): number
  const prefix = 'cobachi://buffer-'
  var idx = 0
  while true
    if !bufexists(prefix .. idx)
      break
    endif
    ++idx
  endwhile
  const bufnr = bufadd(prefix .. idx)
  setbufvar(bufnr, '&undofile', 0)
  setbufvar(bufnr, '&swapfile', 0)
  setbufvar(bufnr, '&buftype', 'nofile')
  setbufvar(bufnr, '&bufhidden', 'wipe')
  bufload(bufnr)

  return bufnr
enddef

# Open given buffer on the current window and returns its windowID
def OpenWindow(bufnr: number): number
  const winid = win_getid()
  execute $'silent :{bufnr} buffer'
  setwinvar(winid, "&number", 0)
  setwinvar(winid, "&relativenumber", 0)
  setwinvar(winid, "&list", 0)
  setwinvar(winid, "&colorcolumn", "")
  setwinvar(winid, "&foldenable", 0)
  setwinvar(winid, "&foldcolumn", 0)
  setwinvar(winid, "&spell", 0)

  return winid
enddef

def FilterItems(Filter: FilterFn, filterText: string, items: list<string>): FilterResult
  if filterText ==# ''
    return [items, []]
  else
    return Filter(filterText, items)
  endif
enddef

export def OnFilterTextChanged()
  const text = getcmdline()
  const curpos = getcmdpos()
  const ff: FF = b:cobachi
  ff.OnFilterTextChanged(text, curpos)
enddef

class Later
  static const _nullid = 0

  var _timer: number
  var _Fn: func
  var _args: list<any>

  def new(Fn: func, args: list<any> = [])
    this._Fn = Fn
    this._args = args
    this._timer = timer_start(0, this._callback)
  enddef

  def Cancel()
    this._timer->timer_stop()
    this._timer = Later._nullid
  enddef

  def _callback(timer: number)
    this._timer = Later._nullid
    call(this._Fn, this._args)
  enddef
endclass

class Debounce
  static const _nullid = 0

  var _wait: number
  var _Fn: func
  var _args: list<any>
  var _timer: number

  def new(wait: number, Fn: func)
    this._wait = wait
    this._Fn = Fn
    this._args = []
    this._timer = Debounce._nullid
  enddef

  def Fire(args: list<any> = [])
    this.Cancel()
    this._args = args
    this._timer = timer_start(this._wait, this._call)
  enddef

  def Cancel()
    this._timer->timer_stop()
    this._timer = Debounce._nullid
  enddef

  def _call(timer: number)
    call(this._Fn, this._args)
  enddef
endclass

class Highlighter
  static const _propTypeName = 'cobachi-prop-type-matched-positions'
  static const _hlgroup = 'Special'
  var _later: Later

  def new()
    this._later = null_object
  enddef

  def Highlight(bufnr: number, highlights: list<list<list<number>>>)
    if prop_type_get(Highlighter._propTypeName, {bufnr: bufnr})->empty()
      prop_type_add(Highlighter._propTypeName, {
        bufnr: bufnr,
        highlight: Highlighter._hlgroup,
        override: true,
      })
    endif
    this._later = Later.new(this._doHighlight, [1, bufnr, highlights])
  enddef

  def _doHighlight(startline: number, bufnr: number, highlights: list<list<list<number>>>)
    const chunkSize = 100
    const targets = highlights->slice(0, chunkSize)
    const rest = highlights[chunkSize :]
    var line = startline
    for positions in targets
      for p in positions
        prop_add(line, p[0], {
          bufnr: bufnr,
          length: p[1],
          type: Highlighter._propTypeName,
        })
      endfor
      ++line
    endfor
    redraw
    if !rest->empty()
      this._later = Later.new(this._doHighlight, [startline + chunkSize, bufnr, rest])
    endif
  enddef

  def Cancel()
    if this._later != null_object
      this._later.Cancel()
    endif
  enddef
endclass

class FF
  var _Source: func(): list<string>
  var _Filter: FilterFn
  var _Action: func
  var _bufnr: number
  var _filterText: string
  var _filterCursorPos: number
  var _debounce: Debounce
  var _items: list<string>
  var _filtered: list<string>
  var _highlighter: Highlighter
  var _alterBufnr: number

  def new()
    this._Source = null_function
    this._Filter = null_function
    this._Action = null_function
    this._bufnr = 0
    this._filterText = ''
    this._filterCursorPos = 0
    this._debounce = Debounce.new(20, this._doFilter)
    this._items = []
    this._filtered = []
    this._highlighter = Highlighter.new()
    this._alterBufnr = 0
  enddef

  def Start(Src: func(): list<string>, Filter: FilterFn, Action: func)
    if getcmdwintype() !=# ''
      PrintError('Cobachi does not work on Command-line window.')
      return
    endif

    this._Source = Src
    this._Filter = Filter
    this._Action = Action
    this._alterBufnr = bufnr('%')
    this._bufnr = CreateNewBuffer()
    setbufvar(this._bufnr, 'cobachi', this)
    OpenWindow(this._bufnr)
    redraw
    setlocal filetype=cobachi  # Give users customization opportunity.
    this._items = this._Source()
    this._doFilter()  # Dry run
  enddef

  def OnFilterTextChanged(text: string, curpos: number)
    this._filterText = text
    this._filterCursorPos = curpos
    this._debounce.Fire()
  enddef

  def DoAction(action: string)
    if action ==# 'start-filtering'
      this._startFiltering()
    elseif action ==# 'accept'
      if this._filtered->empty()
        return
      endif
      const item = this._filtered[line('.') - 1]
      this._quit()
      this._Action(item)
    elseif action ==# 'quit'
      this._quit()
    else
      PrintError('[cobachi] No such action: ' .. action)
    endif
  enddef

  def _doFilter()
    this._highlighter.Cancel()
    const [filtered, highlights] =
      FilterItems(this._Filter, this._filterText, this._items->copy())
    this._filtered = filtered
    setlocal modifiable
    silent deletebufline(this._bufnr, 1, '$')
    setbufline(this._bufnr, 1, this._filtered)
    setlocal nomodifiable nomodified
    this._highlighter.Highlight(this._bufnr, highlights)
    redraw
  enddef

  def _startFiltering()
    augroup cobachi-observe-input
      autocmd!
      autocmd CmdlineChanged @ cobachi#OnFilterTextChanged()
    augroup END

    const filterText = this._filterText
    const curpos = this._filterCursorPos
    try
      input('> ', this._filterText)
    catch /\C^Vim:Interrupt$/
      # Cancel input; restore filter text and cursor pos then invoke re-filtering.
      defer this.OnFilterTextChanged(filterText, curpos)
    catch
      PrintError(v:throwpoint)
      PrintError(v:exception)
    endtry

    augroup cobachi-observe-input
      autocmd!
    augroup END
  enddef

  def _quit()
    if bufexists(this._alterBufnr)
      execute $'silent :{this._alterBufnr}buffer'
    else
      enew
    endif
  enddef
endclass

export def DoAction(action: string)
  const ff: FF = b:cobachi
  ff.DoAction(action)
enddef

const defaultOpts = {
  source: (): list<string> => [],
  filter: (_: string, items: list<string>) => [items, []],
  action: (item: string) => execute($'echo {string(item)}'),
}

export def Filter(optsGiven: dict<any>)
  const userOpts = get(g:, 'cobachi_default_opts', {})
  const opts = optsGiven->extend(userOpts, 'keep')->extend(defaultOpts, 'keep')
  FF.new().Start(opts.source, opts.filter, opts.action)
enddef
