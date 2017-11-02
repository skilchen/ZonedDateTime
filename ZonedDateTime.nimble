# Package

version       = "0.1.0"
author        = "skilchen"
description   = "DateTime types and operations with rudimentary time zone support"
license       = "MIT"

# bin           = @["DateTime"]

# Dependencies

requires "nim >= 0.17.2"
requires "struct >= 0.1.1"

task tests, "Run some DateTime examples and tests":
  exec "nim c -r ZonedDateTime"

task nimtimestest, "Run the same tests as in Nims ttimes.nim":
  exec "nim c -d:testing -r tests/tzoneddatetime"

task docgen, "generate the internal documentation for the ZonedDateTime module":
  exec "nim doc ZonedDateTime"

