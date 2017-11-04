import ospaths
import strutils

# Package

version       = "0.1.0"
author        = "skilchen"
description   = "DateTime types and operations with rudimentary time zone support"
license       = "MIT"


# Dependencies
requires "nim >= 0.17.3"
requires "zip >= 0.1.1"
requires "struct >= 0.1.1"
requires "struct"


task tests, "Run some DateTime examples and tests":
  exec "nim c -r ZonedDateTime"

task nimtimestest, "Run the same tests as in Nims ttimes.nim":
  exec "nim c -d:testing -r tests/tzoneddatetime"

task docgen, "generate the internal documentation for the ZonedDateTime module":
  exec "nim doc2 ZonedDateTime"

task test, "run all available tests":
  for fn in listFiles("tests"):
    if fn.endsWith(".nim"):
      exec "nim c -d:testing -r " & fn

