when defined(js):
  proc paramStr*(i: int): string =
    var args {.importc.}: seq[cstring]
    {.emit: "`args` = process.argv;" .}
    return $args[i + 1]
  proc paramCount*(): int =
    var args {.importc.}: seq[cstring]
    {.emit: "`args` = process.argv;" .}
    return len(args) - 2
