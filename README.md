DateTime
========

DateTime functions for nim

A collection of some functions to do Date/Time calculations inspired by
various sources:

-   the [datetime](https://docs.python.org/3/library/datetime.html)
    module from Python
-   CommonLisps
    [calendrica-3.0.cl](https://github.com/espinielli/pycalcal) ported
    to Python and to [Nim](https://github.com/skilchen/nimcalcal)
-   the [dateutil](https://pypi.python.org/pypi/python-dateutil) package
    for Python
-   the [times](https://nim-lang.org/docs/times.html) module from Nim
    standard library
-   Skrylars [rfc3339](https://github.com/skrylar/rfc3339) module from
    Github
-   the [IANA Time Zone database](https://www.iana.org/time-zones)

This module provides simple types and procedures to represent date/time
values and to perform calculations with them, such as absolute and
relative differences between DateTime instances and TimeDeltas or
TimeIntervals.

The parsing and formatting procedures are from Nims standard library and
from the rfc3339 module. Additionally it implements a simple version of
strftime inspired mainly by the
[LuaDate](https://github.com/wscherphof/lua-date) module and Pythons
[strftime](https://docs.python.org/3/library/datetime.html#strftime-strptime-behavior)
function.

My main goals are:

-   epochTime() is the only platform specific date/time functions
    in use.
-   dealing with timezone offsets is the responsibility of the user of
    this module. it allows you to store an offset to UTC and a DST flag
    but no attempt is made to detect these things from the
    running platform.
-   some rudimentary support to handle Olson timezone definitions and/or
    Posix TZ descriptions (such as: `CET-1CEST,M3.5.0,M10.5.0/3` as used
    in most EU countries, or more exotic ones such as
    `<+0330>-3:30<+0430>,J80/0,J264/0` as found in the Olson file for
    Asia/Tehran ...) Dealing with timezones is a highly
    complicated matter. I personally don't believe, that automatic
    handling of eg. DST changes is a good approach. Almost the only
    useful feature, i have seen in automatisms is the automatic
    adjustment of the wall clock time in personal computers. Maybe some
    time in the future the DST shifting will be abolished in favor of a
    permanent shift of the timezones further away from solar mean time,
    since most people actually seem to prefer the distribution of light
    and darkness in the DST periods.
-   if you compile with -d:useLeapSeconds it uses the leap second data
    from the Olson timezone files. Don't ask me, what that
    actually means...
-   hopefully correct implementation of the used algorithms.
-   it should run both on the c and the js backend. The Olson timezone
    stuff currently does not work on the js backend, because i don't
    know enough javascript to handle the binary file i/o stuff.
-   providing a good Date/Time handling infrastructure is a hard matter.
    The new java.time API took seven years until it was finally released
    to the public. And although i do like some of the design parts of
    it, i have to admit that it is not easy at all to use the new API.
-   My plans are to implement more of the good parts of Pythons dateutil
    and to look what i can take from the R and the Julia communities
    where some time series specialists are at work, who know much more
    about Date/Time related issues than i do.

