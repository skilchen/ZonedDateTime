proc lalign*(s: string, count: Natural, padding = ' '): string {.noSideEffect.} =
  ## Left-Aligns a string `s` with `padding`, so that it is of length `count`.
  ##
  ## `padding` characters (by default spaces) are added after `s` resulting in
  ## left alignment. If ``s.len >= count``, no spaces are added and `s` is
  ## returned unchanged. If you need to right align a string use the `align
  ## proc <#align>`_. Example:
  ##
  ## .. code-block:: nim
  ##   assert alignLeft("abc", 4) == "abc "
  ##   assert alignLeft("a", 0) == "a"
  ##   assert alignLeft("1232", 6) == "1232  "
  ##   assert alignLeft("1232", 6, '#') == "1232##"
  if s.len < count:
    result = newString(count)
    if s.len > 0:
      result[0 .. (s.len - 1)] = s
    for i in s.len ..< count:
      result[i] = padding
  else:
    result = s