import os
import ospaths
import strutils
from times import epochTime

import zip/zipfiles

import ZonedDateTime

proc printf(formatstr: cstring) {.importc, header:"<stdio.h>", varargs.}

proc listPosixTZStringsFromZip(zoneinfo_zip: string) =
  var zip: ZipArchive
  if not zip.open(zoneinfo_zip):
    raise newException(IOError, "failed to open: " & zoneinfo_zip)
  let lts = epochTime()
  for zonename in walkFiles(zip):
    var data: TZFileContent
    try:
      var fp = getStream(zip, zonename)
      if not isNil(fp):
        data = readTZData(fp, zonename)
      else:
        echo "can't read " & zonename & " from " & zoneinfo_zip
    except:
      #echo getCurrentExceptionMsg()
      continue
    if data.version == 2:
      var tzinfo = initTZInfo(data.posixTZ, tzPosix)
      let lt = localFromTime(lts, tzinfo)
      printf("%-45.45s | %-45.45s | %s\n", zonename,  data.posixTZ, $lt)
  zip.close()


when isMainModule:
  if paramCount() < 1:
    echo "example invocation: ./listPosixTZStrings zoneinfo.zip"
    echo "to list all Posix TZ strings available in the Olson timezone"
    echo " Zipfile."
    quit(0)

  listPosixTZStringsFromZip(paramstr(1))