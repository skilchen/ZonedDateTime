import os
import ospaths
import strutils

import ZonedDateTime

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

proc listPosixTZStrings(zoneinfo_dir: string) =
  for filename in os.walkDirRec(zoneinfo_dir):
    try:
      let tzdata = readTZFile(filename)
      if tzdata.version == 2:
        printf("%-60s: %s\n", replace(filename, zoneinfo_dir, ""), tzdata.posixTZ)
        # echo replace(filename, zoneinfo_dir, ""), " ".repeat(60 - len(filename)), " ", tzdata.posixTZ
    except:
      stderr.write(getCurrentExceptionMsg() & "\L")
      discard

when isMainModule:
  if paramCount() < 1:
    echo "example invocation: ./listPosixTZStrings /usr/share/zoneinfo"
    echo "to list all Posix TZ strings available in the Olson timezone"
    echo "files."
    quit(0)

  listPosixTZStrings(paramstr(1))