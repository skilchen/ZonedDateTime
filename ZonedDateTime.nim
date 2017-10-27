##
## DateTime functions for nim
##
## A collection of some functions to do Date/Time calculations inspired by
## various sources:
##
## -  the `datetime <https://docs.python.org/3/library/datetime.html>`__
##    module from Python
## -  CommonLisps
##    `calendrica-3.0.cl <https://github.com/espinielli/pycalcal>`__ ported
##    to Python and to `Nim <https://github.com/skilchen/nimcalcal>`__
## -  the `dateutil <https://pypi.python.org/pypi/python-dateutil>`__
##    package for Python
## -  the `times <https://nim-lang.org/docs/times.html>`__ module from
##    Nim standard library
## -  Skrylars `rfc3339 <https://github.com/skrylar/rfc3339>`__ module from
##    Github
## -  the `IANA Time Zone database <https://www.iana.org/time-zones>`__

##
## This module provides simple types and procedures to represent date/time
## values and to perform calculations with them, such as absolute and
## relative differences between DateTime instances and TimeDeltas or
## TimeIntervals.
##
## The parsing and formatting procedures are from Nims standard library
## and from the rfc3339 module. Additionally it implements a simple version
## of strftime inspired mainly by the
## `LuaDate <https://github.com/wscherphof/lua-date>`__ module and Pythons
## `strftime <https://docs.python.org/3/library/datetime.html#strftime-strptime-behavior>`__
## function.
##
## My main goals are:
##
## -  epochTime() is the only platform specific date/time functions in use.
## -  dealing with timezone offsets is the responsibility of the user of
##    this module. it allows you to store an offset to UTC and a DST flag
##    but no attempt is made to detect these things from the running
##    platform.
## -  some rudimentary support to handle Olson timezone definitions and/or
##    Posix TZ descriptions (such as: ``CET-1CEST,M3.5.0,M10.5.0/3`` as used in
##    most EU countries, or more exotic ones such as ``<+0330>-3:30<+0430>,J80/0,J264/0``
##    as found in the Olson file for Asia/Tehran ...)
##    Dealing with timezones is a highly complicated matter. I personally don't believe,
##    that automatic handling of eg. DST changes is a good approach. Almost the only
##    useful feature, i have seen in automatisms is the automatic adjustment of the
##    wall clock time in personal computers. Maybe some time in the future the DST
##    shifting will be abolished in favor of a permanent shift of the timezones further
##    away from solar mean time, since most people actually seem to prefer the distribution
##    of light and darkness in the DST periods.
## -  if you compile with -d:useLeapSeconds it uses the leap second data from the
##    Olson timezone files. Don't ask me, what that actually mean...
## -  hopefully correct implementation of the used algorithms.
## -  it should run both on the c and the js backend. The Olson timezone stuff currently
##    does not work on the js backend, because i don't know enough javascript to handle
##    the binary file i/o stuff.
## -  providing a good Date/Time handling infrastructure is a hard matter. The new java.time
##    API took seven years until it was finally released to the public. And although i do like
##    some of the design parts of it, i have to admit that it is not easy at all to use the new
##    API.
## -  My plans are to implement more of the good parts of Pythons dateutil and to look what
##    i can take from the R and the Julia communities where some time series specialists are
##    at work, who know much more about Date/Time related issues than i do.
##

import strutils
import parseutils
import math
from times import epochTime

import streams
import struct


type
  TZFileHeader* = object ## Header of a compiled Olson TZ file
    magic*:      string ## The identification magic number of TZ Data files.
    version*:    int8 ## The version of the TZ Data File
    ttisgmtcnt*: int ## The number of UTC/local indicators stored in the file.
    ttisstdcnt*: int ## The number of standard/wall indicators stored in the file.
    leapcnt*:    int ## The number of leap seconds for which data is stored in the file.
    timecnt*:    int ## The number of "transition times" for which data is stored in the file.
    typecnt*:    int ## The number of "local time types" for which data is stored in the file (must not be zero).
    charcnt*:    int ## The number of characters of "timezone abbreviation strings" stored in the file.


  TimeTypeInfo* = object ## offsets and TZ name abbreviations as found in Olson TZ files
    gmtoff*: int
    isdst*: int8
    isstd*: bool
    isgmt*: bool
    abbrev*: string


  LeapSecondInfo* = tuple ## leap second descriptions in v2 Olson TZ files
    transitionTime: BiggestInt
    correction: int


  TZFileData* = object ## to collect data from Olson TZ files
    version*: int8
    header*: TZFileHeader
    transitionTimes*: seq[BiggestInt]
    timeInfoIdx*: seq[int]
    timeInfos*: seq[TimeTypeInfo]
    leapSecondInfos*: seq[LeapSecondInfo]


  TZFileContent* = object ## to collect v0 and v2 data in a Olson TZ file
    version*: int
    transitionData*: seq[TZFileData]
    posixTZ*: string


  TransitionInfo* = object ## point in time and description of a DST transition in Olson files
    time*: BiggestInt
    data*: TimeTypeInfo


  RuleType* = enum ## the three possibilities to express DST transitions in a Posix TZ string
    rJulian1, rJulian0, rMonth


  DstTransitionRule* = ref DstTransitionRuleObj
  DstTransitionRuleObj* = object ## variant object to store DST transition rules from Posix TZ strings
    case kind*: RuleType
    of rJulian0:
      dstYDay*: range[0..365]
    of rJulian1:
      dstNLYDay*: range[1..365]
    of rMonth:
      dstWDay*: range[0..6]
      dstWeek*: range[1..5]
      dstMonth*: range[1..12]
    dstTransitionTime*: int


  DstTransitions* = ref object ## the start and end of a DST period in a Posix TZ string
    dstStart*: DateTime
    dstEnd*: DateTime


  TZRuleData* = object ## to store the data in a Posix TZ string
    stdName*: string
    dstName*: string
    utcOffset*: int
    dstOffset*: int
    dstStartRule*: DstTransitionRule
    dstEndRule*: DstTransitionRule


  TZType* = enum ## the two kinds of TZ descriptions currently supported
    tzPosix, tzOlson


  TZInfo* = ref TZInfoObj
  TZInfoObj* = object ## a variant object to store either Olson or Posix TZ definitions
    case kind*: TZType
    of tzPosix:
      posixData*: TZRuleData
    of tzOlson:
      olsonData*: TZFileContent


  DateTime* = object
    year*: int
    month*: int
    day*: int
    hour*: int
    minute*: int
    second*: int
    microsecond*: int
    utcoffset*: int
    isDST*: bool
    offsetKnown*: bool
    zoneAbbrev*: string


const
  OneDay = 86400
  UnixEpochSeconds = 62135683200
  UnixEpochDays = 719468
  GregorianEpochSeconds = 1 * 24 * 60 * 60


type ISOWeekDate* = object
  year*: int
  week*: int
  weekday*: int

type TimeDelta* = object
  days*: int
  seconds*: int
  microseconds*: int

type TimeInterval* = object ## a time interval
  years*: float64        ## The number of years
  months*: float64       ## The number of months
  days*: float64         ## The number of days
  hours*: float64        ## The number of hours
  minutes*: float64      ## The number of minutes
  seconds*: float64      ## The number of seconds
  microseconds*: float64 ## The number of microseconds
  calculated: bool       ## to indicate if TimeInterval was manually set
                         ## or calculated internally

type TimeStamp* = object
  seconds*: float64
  microseconds*: float64



proc ifloor*[T](n: T): int =
  ## Return the whole part of m/n.
  return int(floor(n.float64))


proc quotient*[T, U](m: T, n:U): int =
  ## Return the whole part of m/n rounded towards negative infinity.
  ## (also known as "floor division")
  return ifloor(m.float64 / n.float64)


proc tdiv*[T, U](m: T, n:U): int =
  ## Return the whole part of m/n rounded towards zero.
  ## (also known as "truncating division")
  return int(m.float64 / n.float64)


proc modulo*[T, U](x: T, y: U): U =
  ## The modulo operation using floor division
  ##
  ## x - floor(x / y) * y
  return x.U - quotient(x.U, y.U).U * y


proc tmod*[T, U](x: T, y: U): U =
  ## The modulo operation using truncating division
  ##
  ## x - int(x / y) * y
  return x.U - tdiv(x.U, y.U).U * y


proc `$`*(dt: DateTime): string =
  ## get a standard string representation of
  ## `dt` DateTime. Somewhat similar to the
  ## format defined in RFC3339:
  ## yyyy-MM-ddThh:mm:ss[.ffffff][Z / (+/-hh:mm)]
  ##
  result = ""
  result.add(intToStr(dt.year, 4))
  result.add("-")
  result.add(intToStr(dt.month, 2))
  result.add("-")
  result.add(intToStr(dt.day, 2))
  result.add("T")
  result.add(intToStr(dt.hour, 2))
  result.add(":")
  result.add(intToStr(dt.minute, 2))
  result.add(":")
  result.add(intToStr(dt.second, 2))
  if dt.microsecond > 0:
    result.add(".")
    result.add(align($dt.microsecond, 6, '0'))
  if dt.utcoffset != 0 or dt.offsetKnown:
    if dt.utcoffset == 0 and not dt.isDST and isNil(dt.zoneAbbrev):
      result.add("Z")
    else:
      if dt.utcoffset < 0:
        result.add("+")
      else:
        result.add("-")
      let utcoffset = dt.utcoffset - (if dt.isDST: 3600 else: 0)
      let hr = quotient(abs(utcoffset), 3600)
      let mn = quotient(modulo(abs(utcoffset), 3600), 60)
      result.add(intToStr(hr, 2))
      result.add(":")
      result.add(intToStr(mn, 2))
      if not isNil(dt.zoneAbbrev):
        result.add(" ")
        result.add(dt.zoneAbbrev)


proc totalSeconds*(td: TimeDelta): float64 =
  ## the value of `td` Time difference
  ## expressed as fractional seconds
  ##
  result = float64(td.days.float64 * OneDay.float64)
  result += float64(td.seconds)
  result += float64(td.microseconds) / 1e6


proc initTimeDelta*(days, hours, minutes, seconds, microseconds: float64 = 0): TimeDelta =
  var s: float64 = 0.0
  s += days * OneDay
  s += hours * 3600
  s += minutes * 60
  s += seconds
  result.days = quotient(s, OneDay.float64)
  result.seconds = int(s - float64(OneDay.float64 * result.days.float64))
  if microseconds != 0:
    result.microseconds = int(microseconds)


proc `$`*(td: TimeDelta): string =
  ## a string representation of a Time difference
  ## format: [x days,] h:mm:ss.ffffff
  ##
  result = ""
  if td.days < 0:
    result.add "-"
    result.add($initTimeDelta(seconds = -1 * td.totalSeconds))
  else:
    if td.days != 0:
      result.add($td.days)
      if abs(td.days) > 1:
        result.add(" days, ")
      else:
        result.add(" day, ")
    var tmp = td.seconds
    let hours = quotient(tmp, 3600)
    tmp -= hours * 3600
    let minutes = quotient(tmp, 60)
    tmp -= minutes * 60
    result.add($hours)
    result.add(":")
    result.add(intToStr(minutes, 2))
    result.add(":")
    result.add(intToStr(tmp,2))

    if td.microseconds > 0:
      result.add(".")
      result.add(align($td.microseconds,6,'0'))


proc `$`*(ti: TimeInterval): string =
  ## string representation of a TimeInterval
  result = ""
  result.add("years: ")
  result.add($ti.years.int)
  result.add(", months: ")
  result.add($ti.months.int)
  result.add(", days: ")
  result.add($ti.days.int)
  result.add(", hours: ")
  result.add($ti.hours.int)
  result.add(", minutes: ")
  result.add($ti.minutes.int)
  result.add(", seconds: ")
  result.add($ti.seconds.int)
  result.add(", microseconds: ")
  result.add($ti.microseconds.int)


proc `$`*(isod: ISOWeekDate): string =
  ## the string representation of the so called
  ## ISO Week Date format. The four digit year
  ## (which can be different from the actual gregorian
  ## calendar year according to the rules for ISO long years
  ## with 53 weeks), followed by a litteral '-W', the two digit
  ## week number, a '-' and the weekday number according to ISO
  ## (1: Monday, .., 7 Sunday)
  ##
  result = ""
  result.add(intToStr(isod.year, 4))
  result.add("-W")
  result.add(intToStr(isod.week, 2))
  result.add("-")
  result.add($isod.weekday)


proc fromTimeStamp*(ts: TimeStamp): DateTime {.gcsafe.}
proc toTimeStamp*(dt: DateTime): TimeStamp {.gcsafe.}


proc initDateTime*(year, month, day, hour, minute, second, microsecond: int = 0;
                   utcoffset: int = 0, isDST: bool = false, offsetKnown = false): DateTime =
  result.year = year
  result.month = month
  result.day = day
  result.hour = hour
  result.minute = minute
  result.second = second
  result.microsecond = microsecond
  result = fromTimeStamp(toTimeStamp(result))
  result.utcoffset = utcoffset
  result.isDST = isDST
  result.offsetKnown = offsetKnown


proc initTimeStamp*(days, hours, minutes, seconds, microseconds: float64 = 0): TimeStamp =
  var s: float64 = 0.0
  s += days * OneDay
  s += hours * 3600
  s += minutes * 60
  s += seconds
  s += microseconds / 1e6
  result.seconds = int(s).float64
  result.microseconds = round(modulo(s, 1.0) * 1e6)

template initTimeStamp*(days, hours, minutes, seconds, microseconds: SomeInteger = 0): TimeStamp =
  initTimeStamp(float64(days), float64(hours), float64(minutes),
                float64(seconds), float64(microseconds))


proc initTimeInterval*(years, months, days, hours, seconds, minutes, microseconds: float64 = 0, calculated = false): TimeInterval =
  ## creates a new ``TimeInterval``.
  ##
  ## You can also use the convenience procedures called ``microseconds``,
  ## ``seconds``, ``minutes``, ``hours``, ``days``, ``months``, and ``years``.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##     let day = initInterval(hours = 24)
  ##     let tomorrow = now() + day
  ##     echo(tomorrow)
  ##
  ## in this variant we enforce truncating division
  ##
  var carry: float64 = 0
  result.microseconds = tmod(microseconds, 1e6)
  carry = tdiv(microseconds, 1e6).float64
  result.seconds = tmod(carry + seconds, 60).float64
  carry = tdiv(carry + seconds, 60).float64
  result.minutes = tmod(carry + minutes, 60).float64
  carry = tdiv(carry + minutes, 60).float64
  result.hours = tmod(carry + hours, 24).float64
  carry = tdiv(carry + hours, 24).float64
  result.days = carry + days
  result.months = tmod(months.int, 12).float64
  carry = tdiv(months, 12).float64
  result.years = carry + years
  result.calculated = calculated


proc `+`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Adds two ``TimeInterval`` objects together.
  ##
  var carry: BiggestFloat = 0
  var sm: BiggestFloat = 0
  sm = ti1.microseconds + ti2.microseconds
  result.microseconds = modulo(sm, 1e6)
  carry = quotient(sm, 1e6).float64
  sm = carry + ti1.seconds + ti2.seconds
  result.seconds = modulo(sm, 60).float64
  carry = quotient(sm, 60).float64
  sm = carry + ti1.minutes + ti2.minutes
  result.minutes = modulo(sm, 60).float64
  carry = quotient(sm, 60).float64
  sm = carry + ti1.hours + ti2.hours
  result.hours = modulo(sm, 24).float64
  carry = quotient(sm, 24).float64
  result.days = carry + ti1.days + ti2.days
  sm = ti1.months + ti2.months
  result.months = modulo(sm, 12).float64
  carry = quotient(sm, 12).float64
  result.years = carry + ti1.years + ti2.years


proc `<`(x, y: TimeInterval): bool =
  let xs:float64 = x.years * 366 * 86400 + x.months * 31 * 86400 +
           x.days * 86400 + x. hours * 3600 + x.minutes * 60 +
           x.seconds + float64(quotient(x.microseconds.float64, 1e6))
  let ys:float64 = y.years * 366 * 86400 + y.months * 31 * 86400 +
           y.days * 86400 + y. hours * 3600 + y.minutes * 60 +
           y.seconds + float64(quotient(y.microseconds.float64, 1e6))
  result = xs < ys


proc `-`*(ti: TimeInterval): TimeInterval =
  ## returns a new `TimeInterval` instance with
  ## all its values negated.
  ##
  result = TimeInterval(
    years: -ti.years,
    months: -ti.months,
    days: -ti.days,
    hours: -ti.hours,
    minutes: -ti.minutes,
    seconds: -ti.seconds,
    microseconds: -ti.microseconds,
    calculated: ti.calculated
  )


proc `-`*(ts: TimeStamp): TimeStamp =
  ## returns a new `TimeStamp` instance
  ## with all its values negated.
  ##
  result = TimeStamp(seconds: -ts.seconds,
                     microseconds: -ts.microseconds)


proc `-`*(ti1, ti2: TimeInterval): TimeInterval =
  ## Subtracts TimeInterval ``ti2`` from ``ti1``.
  ##
  ## Time components are compared one-by-one, see output:
  ##
  ## .. code-block:: nim
  ##     let a = fromUnixEpochSeconds(1_000_000_000)
  ##     let b = fromUnixEpochSeconds(1_500_000_000)
  ##     echo b.toTimeInterval - a.toTimeInterval
  ##     # (years: 15, months: 10, days: 5, hours: 0, minutes: 53, seconds: 20, microseconds: 0)
  ##
  var swapped = false
  var (ti1, ti2) = (ti1, ti2)
  if ti1 < ti2:
    swap(ti1, ti2)
    swapped = true
  result = ti1 + (-ti2)
  if swapped:
    result = -result
  result.calculated = true

proc microseconds*(ms: int): TimeInterval {.inline.} =
  ## TimeInterval of `ms` microseconds
  ##
  initTimeInterval(microseconds = ms.float64)


proc seconds*(s: int): TimeInterval {.inline.} =
  ## TimeInterval of `s` seconds
  ##
  ## ``echo now() + 5.second``
  initTimeInterval(seconds = s.float64)


proc minutes*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` minutes
  ##
  ## ``echo now() + 5.minutes``
  initTimeInterval(minutes = m.float64)


proc hours*(h: int): TimeInterval {.inline.} =
  ## TimeInterval of `h` hours
  ##
  ## ``echo now() + 2.hours``
  initTimeInterval(hours = h.float64)


proc days*(d: int): TimeInterval {.inline.} =
  ## TimeInterval of `d` days
  ##
  ## ``echo now() + 2.days``
  initTimeInterval(days = d.float64)


proc months*(m: int): TimeInterval {.inline.} =
  ## TimeInterval of `m` months
  ##
  ## ``echo now() + 2.months``
  initTimeInterval(months = m.float64)


proc years*(y: int): TimeInterval {.inline.} =
  ## TimeInterval of `y` years
  ##
  ## ``echo now() + 2.years``
  initTimeInterval(years = y.float64)


proc toTimeStamp*(td: TimeDelta): TimeStamp =
  ## converts `td` Time difference into
  ## a TimeStamp with values seconds and
  ## microseconds. Needed because 64bit
  ## floats have not enough precision to
  ## represent microsecond time resolution.
  ##
  result.seconds = float64(td.days.float64 * OneDay.float64)
  result.seconds += td.seconds.float64
  result.microseconds = td.microseconds.float64


proc setUTCOffset*(dt: var DateTime; hours: int = 0, minutes: int = 0) =
  ## set the offset to UTC as hours and minutes east of UTC. Negative
  ## values for locations west of UTC
  ##
  let offset = hours * 3600 + minutes * 60
  dt.utcoffset = offset
  dt.offsetKnown = true


proc setUTCOffset*(dt: var DateTime; seconds: int = 0) =
  ## set the offset to UTC as seconds east of UTC.
  ## negative values for locations west of UTC.
  ##
  dt.utcoffset = seconds
  dt.offsetKnown = true


proc isLeapYear*(year: int): bool =
  ## check if `year` is a leap year.
  ##
  ## algorithm from CommonLisp calendrica-3.0
  ##
  return (modulo(year, 4) == 0) and (modulo(year, 400) notin {100, 200, 300})


proc countLeapYears*(year: int): int =
  ## Returns the number of leap years before `year`.
  ##
  ## **Note:** For leap years, start date is assumed to be 1 AD.
  ## counts the number of leap years up to January 1st of a given year.
  ## Keep in mind that if specified year is a leap year, the leap day
  ## has not happened before January 1st of that year.
  ##
  ## from Nims standard library
  let years = year - 1
  if years >= 0:
    result = years div 4 - years div 100 + years div 400
  else:
    result = -(countLeapYears(-(years + 1)) + 1)


proc toOrdinalFromYMD*(year, month, day: int): int64 =
  ##| return the ordinal day number in the proleptic gregorian calendar
  ##| 0001-01-01 is day number 1
  ##| algorithm from CommonLisp calendrica-3.0
  ##
  result = 0
  result += (365 * (year - 1))
  result += quotient(year - 1, 4)
  result -= quotient(year - 1, 100)
  result += quotient(year - 1, 400)
  result += quotient((367 * month) - 362, 12)
  if month <= 2:
      result += 0
  else:
      if isLeapYear(year):
          result -= 1
      else:
          result -= 2
  result += day


proc toOrdinal*(dt: DateTime): int64 =
  ##| return the ordinal number of the date represented
  ##| in the `dt` DateTime value.
  ##| the same as python's toordinal() and
  ##| calendrica-3.0's fixed-from-gregorian
  ##
  return toOrdinalFromYMD(dt.year, dt.month, dt.day)


proc yearFromOrdinal*(ordinal: int64): int =
  ##| Return the Gregorian year corresponding to the gregorian ordinal.
  ##| algorithm from CommonLisp calendrica-3.0
  ##
  let d0   = ordinal - 1
  let n400 = quotient(d0, 146097)
  let d1   = modulo(d0, 146097)
  let n100 = quotient(d1, 36524)
  let d2   = modulo(d1, 36524)
  let n4   = quotient(d2, 1461)
  let d3   = modulo(d2, 1461)
  let n1   = quotient(d3, 365)
  let year = (400 * n400) + (100 * n100) + (4 * n4) + n1
  if n100 == 4 or n1 == 4:
    return year
  else:
    return year + 1


proc fromOrdinal*(ordinal: int64): DateTime =
  ##| Return the DateTime Date part corresponding to the gregorian ordinal.
  ##| the same as python's fromordinal and calendrica-3.0's
  ##| gregorian-from-fixed
  ##
  let year = yearFromOrdinal(ordinal)
  let prior_days = ordinal - toOrdinalFromYMD(year, 1, 1)
  var correction: int
  if (ordinal < toOrdinalFromYMD(year, 3, 1)):
    correction = 0
  else:
    if isLeapYear(year):
      correction = 1
    else:
      correction = 2
  let month = quotient((12 * (prior_days + correction)) + 373, 367)
  let day = int(1 + (ordinal - toOrdinalFromYMD(year, month, 1)))
  result.year = year
  result.month = month
  result.day = day


proc toDays*(year, month, day: int): int64 =
  ## calculate the number of days since the
  ## Unix epoch 1970-01-01
  ##
  ## inspired by `<http://howardhinnant.github.io/date/date.html>`__
  ##
  var yr = year
  if month <= 2:
    yr -= 1
  let era = (if yr >= 0: yr else: yr - 399) div 400
  let yoe = yr - era * 400
  let doy = (153 * (if month > 2: month - 3 else: month + 9) + 2) div 5 + day - 1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  result = era * 146097 + doe - UnixEpochDays

template toDays*(dt: DateTime): int64 =
  toDays(dt.year, dt.month, dt.day)

proc fromDays*(days: int64): DateTime =
  ## get a DateTime instance from the number of days
  ## since the Unix epoch 1970-01-01
  ##
  ## algorithm from `<http://howardhinnant.github.io/date/date.html>`__
  ##
  let z = days + UnixEpochDays
  let era = (if z >= 0: z else: z - 146096) div 146097
  let doe = z - era * 146097
  let yoe = (doe - doe div 1460 + doe div 36524  - doe div 146096) div 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe div 4 - yoe div 100)
  let mp = (5 * doy + 2) div 153
  let d = doy - (153 * mp + 2) div 5 + 1
  let m = if mp < 10: mp + 3 else: mp - 9
  result.year = int(if m <= 2: y + 1 else: y)
  result.month = int(m)
  result.day = int(d)


proc toTimeStamp*(dt: DateTime): TimeStamp =
  ##| return number of Seconds and MicroSeconds
  ##| since 0001-01-01T00:00:00
  ##
  result.seconds = float64(toOrdinal(dt)) * OneDay
  result.seconds += float64(dt.hour * 60 * 60)
  result.seconds += float64(dt.minute * 60)
  result.seconds += dt.second.float64
  result.microseconds = dt.microsecond.float64


proc toTimeDelta*(dt: DateTime): TimeDelta =
  ##| return number of Days, Seconds and MicroSeconds
  ##| since 0001-01-01T00:00:00
  ##
  result.days = int(toOrdinal(dt))
  result.seconds = dt.hour * 60 * 60
  result.seconds += dt.minute * 60
  result.seconds += dt.second
  result.microseconds = dt.microsecond


proc kday_on_or_before*(k: int, ordinal_date: int64): int64 =
  ##| Return the ordinal date of the k-day on or before ordinal date 'date'.
  ##| k=0 means Sunday, k=1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  #return ordinal_date - modulo(ordinal_date - k, 7)
  let od = ordinal_date - (quotient(GregorianEpochSeconds, 86400) - 1)
  return od - modulo(od - k, 7)


proc kday_on_or_after*(k: int, ordinal_date: int64): int64 =
  ##| Return the ordinal date of the k-day on or after ordinal date 'date'.
  ##| k=0 means Sunday, k=1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 6)


proc kday_nearest*(k: int, ordinal_date: int64): int64 =
  ##| Return the ordinal date of the k-day nearest ordinal date 'date'.
  ##| k=0 means Sunday, k=1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 3)


proc kday_after*(k: int, ordinal_date: int64): int64 =
  ##| Return the ordinal date of the k-day after ordinal date 'date'.
  ##| k=0 means Sunday, k=1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date + 7)


proc kday_before*(k: int, ordinal_date: int64): int64 =
  ##| Return the ordinal date of the k-day before ordinal date 'date'.
  ##| k=0 means Sunday, k=1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  return kday_on_or_before(k, ordinal_date - 1)


proc nth_kday*(nth, k, year, month, day: int): int64 =
  ##| Return the fixed date of n-th k-day after Gregorian date 'g_date'.
  ##| If n>0, return the n-th k-day on or after  'g_date'.
  ##| If n<0, return the n-th k-day on or before 'g_date'.
  ##| If n=0, raise Exception.
  ##| A k-day of 0 means Sunday, 1 means Monday, and so on.
  ##| from CommonLisp calendrica-3.0
  ##
  let ordinal = int(toOrdinalFromYMD(year, month, day))
  if nth > 0:
    return 7 * nth + kday_before(k, ordinal)
  elif nth < 0:
    return 7 * nth + kday_after(k, ordinal)
  else:
    raise newException(ValueError, "0 is not a valid parameter for nth_kday")

proc nth_kday*(nth, k: int; dt: DateTime): DateTime =
  result = fromOrdinal(nth_kday(nth, k, dt.year, dt.month, dt.day))
  result.utcoffset = dt.utcoffset
  result.offsetKnown = dt.offsetKnown
  result.isDST = dt.isDST

proc toOrdinalFromISO*(isod: ISOWeekDate): int64 =
  ##| get the ordinal number of the `isod` ISOWeekDate in
  ##| the proleptic gregorian calendar.
  ##| same as calendrica-3.0's fixed-from-iso
  ##
  return nth_kday(isod.week, 0, isod.year - 1, 12, 28) + isod.weekday


proc amod*[T](x, y: T): int =
  ##| Return the same as modulo(a, b) with b instead of 0.
  return int(y.float64 + modulo(x.float64, -y.float64))


proc toISOWeekDate*(dt: DateTime): ISOWeekDate =
  ##| Return the ISO week date (YYYY-Www-wd) corresponding to the DateTime 'dt'.
  ##| algorithm from CommonLisp calendrica-3.0's iso-from-fixed
  ##
  let ordinal = toOrdinal(dt)
  let approx = yearFromOrdinal(ordinal - 3)
  var year = approx
  if ordinal >= toOrdinalFromISO(ISOWeekDate(year: approx + 1, week: 1, weekday: 1)):
    year += 1
  let week = 1 + quotient(ordinal -
                          toOrdinalFromISO(ISOWeekDate(year: year, week: 1, weekday: 1)), 7)
  let day = amod(int64(ordinal) - (quotient(GregorianEpochSeconds, 86400) - 1), 7)
  result.year = year
  result.week = week
  result.weekday = day


template `<`*(x, y: TimeStamp): bool =
  x.seconds < y.seconds or
    x.seconds == y.seconds and
      x.microseconds < y.microseconds


template `==`*(x, y: TimeStamp): bool =
  x.seconds == y.seconds and
    x.microseconds == y.microseconds


template `<`*(x, y: DateTime): bool =
  toTimeStamp(x) < toTimeStamp(y)


template `==`*(x, y: DateTime): bool =
  toTimeStamp(x) == toTimeStamp(y)

proc `<=`*(x, y: DateTime): bool =
  var x = toTimeStamp(x)
  var y = toTimeStamp(y)
  result = (x < y) or (x == y)

template `>=`*(x, y: DateTime): bool =
  not (x < y)


template `cmp`*(x, y: DateTime): int =
  let x = toTimeStamp(x)
  let y = toTimeStamp(y)
  if x < y:
    return -1
  elif x > y:
    return 1
  else:
    return 0


proc getDaysInMonth*(year: int, month: int): int =
  ## Get the number of days in a ``month`` of a ``year``
  ## from times module in Nims standard library
  ##
  # http://www.dispersiondesign.com/articles/time/number_of_days_in_a_month
  case month
  of 2: result = if isLeapYear(year): 29 else: 28
  of 4, 6, 9, 11: result = 30
  else: result = 31


proc getDaysBeforeMonth*(month: int, leap: int): int =
  ## Get the number of days before the first day in ``month``
  case month
  of 1:
    result = 0
  of 2:
    result = 31
  of 3:
    result = 59 + leap
  of 4:
    result = 90 + leap
  of 5:
    result = 120 + leap
  of 6:
    result = 151 + leap
  of 7:
    result = 181 + leap
  of 8:
    result = 212 + leap
  of 9:
    result = 243 + leap
  of 10:
    result = 273 + leap
  of 11:
    result = 304 + leap
  else:
    result = 334 + leap


proc `+`*(dt: DateTime, td: TimeDelta): DateTime {.gcsafe.}
proc `-`*(dt: DateTime, td: TimeDelta): DateTime {.gcsafe.}

proc toTimeStamp*(dt: DateTime, ti: TimeInterval): TimeStamp =
  ## Calculates the number of fractional seconds the interval is worth
  ## relative to `dt`.
  ##
  ## adapted from Nims standard library
  ##
  var anew = dt
  var newinterv = ti

  newinterv.months += ti.years * 12
  var curMonth = anew.month

  result.seconds -= float64((dt.day - 1) * OneDay)
  # now we are on day 1 of curMonth

  if newinterv.months < 0:   # subtracting
    var tmpMonths = abs(newinterv.months)
    if tmpMonths > 12:
      let yrs = quotient(tmpMonths, 12)
      let f1 = toOrdinalFromYMD(dt.year, dt.month, dt.day)
      let f2 = toOrdinalFromYMD(dt.year - yrs, dt.month, dt.day)
      result.seconds -= float64((f1 - f2).float64 * OneDay.float64)
      newinterv.months = -float64(modulo(tmpMonths, 12))
      anew.year -= yrs

    for mth in countDown(-1 * newinterv.months.int, 1):
      # subtract the number of seconds in the previous month
      if curMonth == 1:
        curMonth = 12
        anew.year.dec()
      else:
        curMonth.dec()
      result.seconds -= float64(getDaysInMonth(anew.year, curMonth) * OneDay)
  else:  # adding
    if newinterv.months > 12:
      let yrs = quotient(newinterv.months, 12)
      let f1 = toOrdinalFromYMD(dt.year, dt.month, dt.day)
      let f2 = toOrdinalFromYMD(dt.year + yrs, dt.month, dt.day)
      result.seconds += float64((f2 - f1).float64 * OneDay.float64)
      newinterv.months = float64(modulo(newinterv.months, 12))
      anew.year += yrs

    # add number of seconds in current month
    for mth in 1 .. newinterv.months.int:
      result.seconds += float64(getDaysInMonth(anew.year, curMonth) * OneDay)
      if curMonth == 12:
        curMonth = 1
        anew.year.inc()
      else:
        curMonth.inc()
  if not newinterv.calculated:
    # add the number of seconds we first subtracted back to get to anew.day in the current month.
    # if no days were set in the TimeInterval, we have to make sure that anew.day fits in the
    # current month. if e.g. we startet on monthday 31 and ended in a month with only 28 days
    # we have to take the smaller of the two values to adjust the number of seconds.

    result.seconds += float64((min(getDaysInMonth(anew.year, curMonth), dt.day) - 1) * OneDay)
  else:
    # if a number of days was set in the timeinterval by an internal calculation,
    # we don't adjust for the maximal day number in the target month.
    result.seconds += float64((dt.day - 1) * OneDay)

  result.seconds += float64(newinterv.days.int * 24 * 60 * 60)
  result.seconds += float64(newinterv.hours.int * 60 * 60)
  result.seconds += float64(newinterv.minutes.int * 60)
  result.seconds += newinterv.seconds.float64
  result.microseconds += newinterv.microseconds.float64


proc fromTimeStamp*(ts: TimeStamp): DateTime =
  ##| return DateTime from TimeStamp (number of seconds since 0001-01-01T00:00:00)
  ##| algorithm from CommonLisp calendrica-3.0
  ##
  result = fromOrdinal(quotient(ts.seconds, OneDay))
  var tmp = modulo(ts.seconds, float64(OneDay))
  result.hour = quotient(tmp, 3600)
  tmp = modulo(tmp, 3600.0)
  result.minute = quotient(tmp, 60)
  tmp = modulo(tmp, 60.0)
  result.second = int(tmp)
  result.microsecond = int(ts.microseconds)


proc toTimeInterval*(dt: DateTime): TimeInterval =
  ## convert a DateTime Value into a TimeInterval since
  ## the start of the proleptic Gregorian calendar.
  ## This can be used to calculate what other people
  ## (eg. python's dateutil) call relative time deltas.
  ## The idea for this comes from Nims standard library
  ##
  result.years = dt.year.float64
  result.months = dt.month.float64
  result.days = dt.day.float64
  result.hours = dt.hour.float64
  result.minutes = dt.minute.float64
  result.seconds = dt.second.float64
  result.microseconds = dt.microsecond.float64
  result.calculated = true


proc normalizeTimeStamp(ts: var TimeStamp) =
  ## during various calculations in this module
  ## the value of microseconds will go below zero
  ## or above 1e6. We correct the stored value in
  ## seconds to keep the microseconds between 0
  ## and 1e6 - 1
  ##
  if ts.microseconds < 0:
    ts.seconds -= float64(quotient(ts.microseconds, -1_000_000) + 1)
    ts.microseconds = float64(modulo(ts.microseconds, 1_000_000))
  elif ts.microseconds >= 1_000_000:
    ts.seconds += float64(quotient(ts.microseconds, 1_000_000))
    ts.microseconds = float64(modulo(ts.microseconds, 1_000_000))


proc `-`*(x, y: TimeStamp): TimeStamp =
  ## substract TimeStamp `y` from `x`
  result.seconds = x.seconds - y.seconds
  result.microseconds = x.microseconds - y.microseconds
  normalizeTimeStamp(result)


proc `+`*(x, y: TimeStamp): TimeStamp =
  ## add TimeStamp `y` to `x`
  result.seconds = x.seconds + y.seconds
  result.microseconds = x.microseconds + y.microseconds
  normalizeTimeStamp(result)


proc `+`*(dt: DateTime, ti: TimeInterval): DateTime {.gcsafe.}
proc `+`*(dt: DateTime, ts: TimeStamp): DateTime {.gcsafe.}

proc toTimeInterval*(dt1, dt2: DateTime): TimeInterval =
  ## calculate the `TimeInterval` between two `DateTime`
  ## a loopless implementation inspired in the date part
  ## by the until Method of the new java.time.LocalDate class
  ##

  var (dt1, dt2) = (dt1, dt2)
  var sign = 1
  if dt2 < dt1:
    when defined(js):
      # inplace swapping doesn't work on the js backend
      let tmp = dt1
      dt1 = dt2
      dt2 = tmp
    else:
      (dt1, dt2) = (dt2, dt1)
    sign = -1

  let ts1 = initTimeStamp(hours = dt1.hour, minutes = dt1.minute,
                          seconds = dt1.second, microseconds = dt1.microsecond)
  let ts2 = initTimeStamp(hours = dt2.hour, minutes = dt2.minute,
                          seconds = dt2.second, microseconds = dt2.microsecond)
  let difftime = ts2 - ts1
  let diffdays = int(quotient(difftime.seconds, 86400))
  var diffseconds = int(difftime.seconds) - 86400 * diffdays
  let diffhours = quotient(diffseconds, 3600)
  let diffminutes = quotient(diffseconds - 3600 * diffhours, 60)
  diffseconds = diffseconds - 3600 * diffhours - 60 * diffminutes
  dt2 = dt2 + initTimeInterval(days = float(diffdays))

  var totalMonths = dt2.year * 12 - dt1.year * 12 + dt2.month - dt1.month
  var days = dt2.day - dt1.day
  if (totalMonths > 0 and days < 0):
    totalMonths.dec
    let tmpDate = dt1 + initTimeInterval(months = totalMonths.float64)
    days = int(dt2.toOrdinal() - tmpDate.toOrdinal())
  elif (totalMonths < 0 and days > 0):
    totalMonths.inc
    days = days - getDaysInMonth(dt2.year, dt2.month) + 1
  let years = totalMonths div 12
  let months = totalMonths mod 12

  return initTimeInterval(years = float64(sign * years),
                          months = float64(sign * months),
                          days = float64(sign * days),
                          hours = float64(sign * diffhours),
                          minutes = float64(sign * diffminutes),
                          seconds = float64(sign * diffseconds),
                          microseconds = float64(sign) * difftime.microseconds)


proc toTimeIntervalb*(dt1, dt2: DateTime): TimeInterval =
  result = dt2.toTimeinterval() - dt1.toTimeInterval


proc toUTC*(dt: DateTime): DateTime =
  ## correct the value in `dt` according to the
  ## offset to UTC stored in the value
  ## Offsets have to be subtracted from the stored
  ## value to get the corresponding time in UTC.
  ##
  var s = dt.toTimeStamp()
  s.seconds -= (dt.utcoffset + (if dt.isDST: 3600 else: 0)).float64
  result = fromTimeStamp(s)
  result.offSetKnown = true
  result.utcoffset = 0


proc fromUnixEpochSeconds*(ues: float64, hoffset, moffset: int = 0): DateTime =
  ## the Unix epoch started on 1970-01-01T00:00:00
  ## many programs use this date as the reference
  ## point in their datetime calculations.
  ##
  ## use this to get a DateTime in the proleptic
  ## Gregorian calendar using a value you get eg.
  ## from nim's epochTime(). epochTime() is the
  ## only platform dependent date/time related
  ## procedure used in this module.
  ##
  var seconds = floor(ues) + UnixEpochSeconds.float64
  seconds += float64(hoffset * 3600)
  seconds += float64(moffset * 60)

  when defined(js):
    let fraction = `mod`(ues, 1.0)
  else:
    let fraction = modulo[float64,float64](ues, 1.0)

  var ts: TimeStamp
  ts.seconds = seconds.float64
  ts.microseconds = fraction * 1e6
  if ts.microseconds >= 1e6:
    ts.seconds += 1
    ts.microseconds = ts.microseconds - 1e6
  fromTimeStamp(ts)


proc toUnixEpochSeconds*(dt: DateTime): float64 =
  ## get the number of fractional seconds since
  ## start of the Unix epoch on 1970-01-01T00:00:00
  ##
  let ts = toTimeStamp(dt)
  result = float64(ts.seconds - UnixEpochSeconds.float64)
  result += ts.microseconds.float64 / 1e6


proc toTime*(dt: DateTime): float64 =
  ## get the number of fractional seconds since
  ## start of the Unix epoch on 1970-01-01T00:00:00
  ## wall clock time.
  ##
  ## inspired by `<http://howardhinnant.github.io/date/date.html>`__
  ##
  let days = toDays(dt)
  result = days.float64 * 86400.0
  result += dt.hour.float64 * 3600.0
  result += dt.minute.float64 * 60.0
  result += dt.second.float64
  result += dt.microsecond.float64 / 1e6


proc fromTime*(t: float64): DateTime =
  ## get a DateTime from `t` number of
  ## wall clock seconds since the start
  ## of the Unix epoch on 1970-01-01T00:00:00
  ##
  let days = quotient(t, 86400)
  result = fromDays(days)
  let seconds = modulo(t, 86400.0)
  result.hour = quotient(seconds, 3600.0)
  result.minute = quotient(modulo(seconds, 3600.0), 60)
  result.second = int(modulo(seconds, 60.0))
  result.microsecond = int(modulo[float64,float64](t, 1.0) * 1e6)


proc `-`*(x, y: DateTime): TimeDelta =
  ## subtract DateTime `y` from `x` returning
  ## a TimeDelta which represents the time difference
  ## as a number of days, seconds and microseconds.
  ## As usual in calendrical calculations, this is done
  ## via a roundtrip from DateTime to TimeStamp values
  ## (the fractional number of seconds since the start
  ## of the proleptic Gregorian calendar.)
  ##
  let tdiff = toTimeStamp(x) - toTimeStamp(y)
  result = initTimeDelta(seconds = tdiff.seconds, microseconds=tdiff.microseconds)


template transferOffsetInfo(dt: DateTime) =
  result.offsetKnown = dt.offsetKnown
  result.utcoffset = dt.utcoffset
  result.isDST = dt.isDST

proc `+`*(dt: DateTime, td: TimeDelta): DateTime =
  ## add a TimeDelta `td` (represented as a number of
  ## days, seconds and microseconds) to a DateTime value in `dt`
  ##
  var s: TimeStamp = dt.toTimeStamp()
  let ts = td.toTimeStamp()
  s.seconds += ts.seconds
  s.microseconds += ts.microseconds
  normalizeTimeStamp(s)
  result = fromTimeStamp(s)
  transferOffsetInfo(dt)


proc `+`*(dt: DateTime, ts: TimeStamp): DateTime =
  dt + initTimeDelta(seconds = ts.seconds, microseconds = ts.microseconds)


proc `-`*(dt: DateTime, td: TimeDelta): DateTime =
  ## subtract TimeDelta `td` from DateTime value in `dt`
  ##
  result = fromTimeStamp(dt.toTimeStamp() - td.toTimeStamp())
  transferOffsetInfo(dt)


proc `nimPlus`*(dt: DateTime, ti: TimeInterval): DateTime =
  ## adds ``ti`` time to DateTime ``dt``.
  ##
  var ts = toTimeStamp(dt) + toTimeStamp(dt, ti)
  normalizeTimeStamp(ts)
  result = fromTimeStamp(ts)
  transferOffsetInfo(dt)


proc `+`*(dt: DateTime, ti: TimeInterval): DateTime =
  ## adds ``ti`` to DateTime ``dt``.
  ##
  let totalMonths = dt.year.float64 * 12 + dt.month.float64 - 1 + ti.years * 12 + ti.months
  let year = quotient(totalMonths, 12)
  let month = modulo(totalMonths, 12) + 1
  let day = min(getDaysInMonth(year, month), dt.day)
  let ordinal = float64(toOrdinalFromYMD(year, month, day)) + ti.days

  var seconds = float64(ordinal) * OneDay
  seconds += (dt.hour.float64 + ti.hours) * 3600.0
  seconds += (dt.minute.float64 + ti.minutes) * 60.0
  seconds += (dt.second.float64 + ti.seconds)
  let microseconds = dt.microsecond.float64 + ti.microseconds
  result = fromTime(seconds - float64(UnixEpochSeconds) + microseconds / 1e6)
  transferOffsetInfo(dt)


proc `-`*(dt: DateTime, ti: TimeInterval): DateTime =
  ## subtracts ``ti`` time from DateTime ``dt``.
  ## this is the same as adding the negated value of `ti`
  ## to `dt`
  ##
  var ts = toTimeStamp(dt) + toTimeStamp(dt, -ti)
  normalizeTimeStamp(ts)
  result = fromTimeStamp(ts)
  transferOffsetInfo(dt)


proc getWeekDay*(dt: DateTime): int =
  ## get the weeday number for the date stored in
  ## `dt`. The day 0001-01-01 was a monday, so we
  ## can take the ordinal number of the date in `dt`
  ## modulo 7 the get the corresponding weekday number.
  ##
  modulo(toOrdinal(dt), 7)


proc getYearDay*(dt: DateTime): int =
  ## get the day number in the year stored in the
  ## date in `dt`. Contrary to a similar function in
  ## nim's standard lib, this procedure gives the ordinal
  ## number of the stored day in the stored year. Not the
  ## number of days before the date stored in `dt`.
  ##
  let leap = int(isLeapYear(dt.year))
  getDaysBeforeMonth(dt.month, leap) + dt.day


proc easter*(year: int): DateTime =
  ##| Return Date of Easter in Gregorian year `year`.
  ##| adapted from CommonLisp calendrica-3.0
  ##
  let century = quotient(year, 100) + 1
  let shifted_epact = modulo(14 + (11 * modulo(year, 19)) -
                             quotient(3 * century, 4) +
                             quotient(5 + (8 * century), 25), 30)
  var adjusted_epact = shifted_epact
  if (shifted_epact == 0) or (shifted_epact == 1 and
                                (10 < modulo(year, 19))):
      adjusted_epact = shifted_epact + 1
  else:
      adjusted_epact = shifted_epact
  let paschal_moon = (toOrdinalFromYMD(year, 4, 19)) - adjusted_epact
  return fromOrdinal(kday_after(0, paschal_moon))


proc `*`(ti: TimeInterval, i: int): TimeInterval =
  let i = float64(i)
  result.years = ti.years * i
  result.months = ti.months * i
  result.days = ti.days * i
  result.hours = ti.hours * i
  result.minutes = ti.minutes * i
  result.seconds = ti.seconds * i
  result.microseconds = ti.microseconds * i


iterator countUp*(dtstart, dtend: DateTime, step: TimeInterval): DateTime =
  var current = dtstart
  var i = 1
  while current <= dtend:
    yield current
    current = dtstart + (step * i)
    inc(i)

iterator countDown*(dtstart, dtend: DateTime, step: TimeInterval): DateTime =
  var current = dtstart
  var i = 1
  while current >= dtend:
    yield current
    current = dtstart + (step * -i)
    inc(i)


proc now*(): DateTime =
  ## get a DateTime instance having the current date
  ## and time from the running system.
  ## This does not set the offset to UTC. It simply
  ## takes what epochTime() gives (a fractional number
  ## of seconds since the start of the Unix epoch (probably in UTC))
  ## and converts that number in a DateTime value.
  ##
  ## You have to add the offset to UTC yourself if epochTime() gives
  ## you a time in UTC. Example for the offset +02:00:
  ##
  ## .. code-block:: nim
  ##    var localtime = now() + 2.hours
  ##    # if you do care about this offset
  ##    # (eg. to convert localtime to UTC)
  ##    localtime.setUTCoffset(2, 0)
  ##    var utctime = localtime.toUTC()
  ##
  result = fromUnixEpochSeconds(epochTime())


proc parseToken(dt: var DateTime; token, value: string; j: var int) =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## Helper of the parse proc to parse individual tokens.
  var sv: int
  case token
  of "d":
    var pd = parseInt(value[j..j+1], sv)
    dt.day = sv
    j += pd
  of "dd":
    dt.day = value[j..j+1].parseInt()
    j += 2
  of "h", "H":
    var pd = parseInt(value[j..j+1], sv)
    dt.hour = sv
    j += pd
  of "hh", "HH":
    dt.hour = value[j..j+1].parseInt()
    j += 2
  of "m":
    var pd = parseInt(value[j..j+1], sv)
    dt.minute = sv
    j += pd
  of "mm":
    dt.minute = value[j..j+1].parseInt()
    j += 2
  of "M":
    var pd = parseInt(value[j..j+1], sv)
    dt.month = sv
    j += pd
  of "MM":
    var month = value[j..j+1].parseInt()
    j += 2
    dt.month = month
  of "MMM":
    case value[j..j+2].toLowerAscii():
    of "jan": dt.month =  1
    of "feb": dt.month =  2
    of "mar": dt.month =  3
    of "apr": dt.month =  4
    of "may": dt.month =  5
    of "jun": dt.month =  6
    of "jul": dt.month =  7
    of "aug": dt.month =  8
    of "sep": dt.month =  9
    of "oct": dt.month =  10
    of "nov": dt.month =  11
    of "dec": dt.month =  12
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMM), got: " & value)
    j += 3
  of "MMMM":
    if value.len >= j+7 and value[j..j+6].cmpIgnoreCase("january") == 0:
      dt.month =  1
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("february") == 0:
      dt.month =  2
      j += 8
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("march") == 0:
      dt.month =  3
      j += 5
    elif value.len >= j+5 and value[j..j+4].cmpIgnoreCase("april") == 0:
      dt.month =  4
      j += 5
    elif value.len >= j+3 and value[j..j+2].cmpIgnoreCase("may") == 0:
      dt.month =  5
      j += 3
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("june") == 0:
      dt.month =  6
      j += 4
    elif value.len >= j+4 and value[j..j+3].cmpIgnoreCase("july") == 0:
      dt.month =  7
      j += 4
    elif value.len >= j+6 and value[j..j+5].cmpIgnoreCase("august") == 0:
      dt.month =  8
      j += 6
    elif value.len >= j+9 and value[j..j+8].cmpIgnoreCase("september") == 0:
      dt.month =  9
      j += 9
    elif value.len >= j+7 and value[j..j+6].cmpIgnoreCase("october") == 0:
      dt.month =  10
      j += 7
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("november") == 0:
      dt.month =  11
      j += 8
    elif value.len >= j+8 and value[j..j+7].cmpIgnoreCase("december") == 0:
      dt.month =  12
      j += 8
    else:
      raise newException(ValueError,
        "Couldn't parse month (MMMM), got: " & value)
  of "s":
    var pd = parseInt(value[j..j+1], sv)
    dt.second = sv
    j += pd
  of "ss":
    dt.second = value[j..j+1].parseInt()
    j += 2
  of "t":
    if value[j] == 'P' and dt.hour > 0 and dt.hour < 12:
      dt.hour += 12
    j += 1
  of "tt":
    if value[j..j+1] == "PM" and dt.hour > 0 and dt.hour < 12:
      dt.hour += 12
    j += 2
  of "yyyy":
    dt.year = value[j..j+3].parseInt()
    j += 4
  of "z":
    dt.offsetKnown = true
    if value[j] == '+':
      dt.utcoffset = parseInt($value[j+1]) * 3600
    elif value[j] == '-':
      dt.utcoffset = 0 - parseInt($value[j+1]) * -3600
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (z), got: " & value[j])
    j += 2
  of "zz":
    dt.offsetKnown = true
    if value[j] == '+':
      dt.utcoffset = value[j+1..j+2].parseInt() * 3600
    elif value[j] == '-':
      dt.utcoffset = 0 - value[j+1..j+2].parseInt() * 3600
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zz), got: " & value[j])
    j += 3
  of "zzz":
    var factor = 0
    if value[j] == '+': factor = -1
    elif value[j] == '-': factor = 1
    elif value[j] == 'Z':
      dt.utcoffset = 0
      j += 1
      return
    else:
      raise newException(ValueError,
        "Couldn't parse timezone offset (zzz), got: " & value[j])
    dt.utcoffset = factor * value[j+1..j+2].parseInt() * 3600
    j += 4
    dt.utcoffset += factor * value[j..j+1].parseInt() * 60
    dt.offsetKnown = true
    j += 2
  else:
    # Ignore the token and move forward in the value string by the same length
    j += token.len


proc parse*(value, layout: string): DateTime =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## This function parses a date/time string using the standard format
  ## identifiers as listed below.
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    yyyy     four digit year.                                                                   ``2012 -> 2012``
  ##    z        Displays the timezone offset from UTC. ``Z`` is parsed as ``+0``                   ``GMT+7 -> +7``, ``GMT-5 -> -5``
  ##    zz       Same as above but with leading 0.                                                  ``GMT+7 -> +07``, ``GMT-5 -> -05``
  ##    zzz      Same as above but with ``:mm`` where *mm* represents minutes.                      ``GMT+7 -> +07:00``, ``GMT-5 -> -05:00``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.
  var i = 0 # pointer for format string
  var j = 0 # pointer for value string
  var token = ""
  # Assumes current day of month, month and year, but time is reset to 00:00:00.
  var dt = now()
  dt.hour = 0
  dt.minute = 0
  dt.second = 0
  dt.microsecond = 0

  while true:
    case layout[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      if token.len > 0:
        parseToken(dt, token, value, j)
      # Reset token
      token = ""
      # Break if at end of line
      if layout[i] == '\0': break
      # Skip separator and everything between single quotes
      # These are literals in both the layout and the value string
      if layout[i] == '\'':
        inc(i)
        while layout[i] != '\'' and layout.len-1 > i:
          inc(i)
          inc(j)
        inc(i)
      else:
        inc(i)
        inc(j)
    else:
      # Check if the letter being added matches previous accumulated buffer.
      if token.len < 1 or token[high(token)] == layout[i]:
        token.add(layout[i])
        inc(i)
      else:
        parseToken(dt, token, value, j)
        token = ""

  return dt


const WeekDayNames: array[7, string] = ["Sunday", "Monday", "Tuesday", "Wednesday",
     "Thursday", "Friday", "Saturday"]

const MonthNames: array[0..12, string] = ["", "January", "February", "March",
      "April", "May", "June", "July", "August", "September", "October",
      "November", "December"]


proc formatToken(dt: DateTime, token: string, buf: var string) =
  ## Helper of the format proc to parse individual tokens.
  ##
  ## Pass the found token in the user input string, and the buffer where the
  ## final string is being built. This has to be a var value because certain
  ## formatting tokens require modifying the previous characters.
  case token
  of "d":
    buf.add($dt.day)
  of "dd":
    if dt.day < 10:
      buf.add("0")
    buf.add($dt.day)
  of "ddd":
    buf.add($WeekDayNames[getWeekDay(dt)][0 .. 2])
  of "dddd":
    buf.add($WeekDayNames[getWeekDay(dt)])
  of "h":
    buf.add($(if dt.hour > 12: dt.hour - 12 else: dt.hour))
  of "hh":
    let amerHour = if dt.hour > 12: dt.hour - 12 else: dt.hour
    if amerHour < 10:
      buf.add('0')
    buf.add($amerHour)
  of "H":
    buf.add($dt.hour)
  of "HH":
    if dt.hour < 10:
      buf.add('0')
    buf.add($dt.hour)
  of "m":
    buf.add($dt.minute)
  of "mm":
    if dt.minute < 10:
      buf.add('0')
    buf.add($dt.minute)
  of "M":
    buf.add($dt.month)
  of "MM":
    if dt.month < 10:
      buf.add('0')
    buf.add($dt.month)
  of "MMM":
    buf.add($MonthNames[dt.month][0..2])
  of "MMMM":
    buf.add($MonthNames[dt.month])
  of "s":
    buf.add($dt.second)
  of "ss":
    if dt.second < 10:
      buf.add('0')
    buf.add($dt.second)
  of "t":
    if dt.hour >= 12:
      buf.add('P')
    else: buf.add('A')
  of "tt":
    if dt.hour >= 12:
      buf.add("PM")
    else: buf.add("AM")
  of "y", "yy", "yyy", "yyyy":
    buf.add(intToStr(dt.year, 4))
  of "yyyyy":
    buf.add(intToStr(dt.year, 5))
  of "z":
    let
      nonDstTz = dt.utcoffset - int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    buf.add($hours)
  of "zz":
    let
      nonDstTz = dt.utcoffset - int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
  of "zzz":
    let
      nonDstTz = dt.utcoffset + int(dt.isDst) * 3600
      hours = abs(nonDstTz) div 3600
      minutes = (abs(nonDstTz) div 60) mod 60
    if nonDstTz >= 0: buf.add('+')
    else: buf.add('-')
    if hours < 10: buf.add('0')
    buf.add($hours)
    buf.add(':')
    if minutes < 10: buf.add('0')
    buf.add($minutes)
  of "":
    discard
  else:
    raise newException(ValueError, "Invalid format string: " & token)


proc format*(dt: DateTime, f: string): string =
  ## literally taken from times.nim in the standard library.
  ## adapted to the names and types used in this module and
  ## remove every call to a platform dependent date/time
  ## function to prevent the pollution of DateTime values with
  ## Timezone data from the running system. Removed the possibility
  ## to parse dates with something other than 4-digit years. I don't
  ## want to deal with them.

  ## This function formats `dt` as specified by `f`. The following format
  ## specifiers are available:
  ##
  ## ==========  =================================================================================  ================================================
  ## Specifier   Description                                                                        Example
  ## ==========  =================================================================================  ================================================
  ##    d        Numeric value of the day of the month, it will be one or two digits long.          ``1/04/2012 -> 1``, ``21/04/2012 -> 21``
  ##    dd       Same as above, but always two digits.                                              ``1/04/2012 -> 01``, ``21/04/2012 -> 21``
  ##    ddd      Three letter string which indicates the day of the week.                           ``Saturday -> Sat``, ``Monday -> Mon``
  ##    dddd     Full string for the day of the week.                                               ``Saturday -> Saturday``, ``Monday -> Monday``
  ##    h        The hours in one digit if possible. Ranging from 0-12.                             ``5pm -> 5``, ``2am -> 2``
  ##    hh       The hours in two digits always. If the hour is one digit 0 is prepended.           ``5pm -> 05``, ``11am -> 11``
  ##    H        The hours in one digit if possible, randing from 0-24.                             ``5pm -> 17``, ``2am -> 2``
  ##    HH       The hours in two digits always. 0 is prepended if the hour is one digit.           ``5pm -> 17``, ``2am -> 02``
  ##    m        The minutes in 1 digit if possible.                                                ``5:30 -> 30``, ``2:01 -> 1``
  ##    mm       Same as above but always 2 digits, 0 is prepended if the minute is one digit.      ``5:30 -> 30``, ``2:01 -> 01``
  ##    M        The month in one digit if possible.                                                ``September -> 9``, ``December -> 12``
  ##    MM       The month in two digits always. 0 is prepended.                                    ``September -> 09``, ``December -> 12``
  ##    MMM      Abbreviated three-letter form of the month.                                        ``September -> Sep``, ``December -> Dec``
  ##    MMMM     Full month string, properly capitalized.                                           ``September -> September``
  ##    s        Seconds as one digit if possible.                                                  ``00:00:06 -> 6``
  ##    ss       Same as above but always two digits. 0 is prepended.                               ``00:00:06 -> 06``
  ##    t        ``A`` when time is in the AM. ``P`` when time is in the PM.
  ##    tt       Same as above, but ``AM`` and ``PM`` instead of ``A`` and ``P`` respectively.
  ##    y(yyyy)  This displays the 4-digit year                                                     ``padded with leading zero's if necessary``
  ##    z(zz)    Displays the timezone offset from UTC.                                             ``0 -> Z (if known), others -> +hh:mm or -hh:mm``
  ## ==========  =================================================================================  ================================================
  ##
  ## Other strings can be inserted by putting them in ``''``. For example
  ## ``hh'->'mm`` will give ``01->56``.  The following characters can be
  ## inserted without quoting them: ``:`` ``-`` ``(`` ``)`` ``/`` ``[`` ``]``
  ## ``,``. However you don't need to necessarily separate format specifiers, a
  ## unambiguous format string like ``yyyyMMddhhmmss`` is valid too.

  result = ""
  var i = 0
  var currentF = ""
  while true:
    case f[i]
    of ' ', '-', '/', ':', '\'', '\0', '(', ')', '[', ']', ',':
      formatToken(dt, currentF, result)

      currentF = ""
      if f[i] == '\0': break

      if f[i] == '\'':
        inc(i) # Skip '
        while f[i] != '\'' and f.len-1 > i:
          result.add(f[i])
          inc(i)
      else: result.add(f[i])

    else:
      # Check if the letter being added matches previous accumulated buffer.
      if currentF.len < 1 or currentF[high(currentF)] == f[i]:
        currentF.add(f[i])
      else:
        formatToken(dt, currentF, result)
        dec(i) # Move position back to re-process the character separately.
        currentF = ""

    inc(i)


proc strftime*(dt: DateTime, fmtstr: string): string =
  ## a limited reimplementation of strftime, mainly based
  ## on the version implemented in lua, with some influences
  ## from the python version and some convenience features,
  ## such as a shortcut to get a DateTime formatted according
  ## to the rules in RFC3339
  ##
  result = ""
  let fmtLength = len(fmtstr)
  var i = 0
  while i < fmtLength:
    if fmtstr[i] == '%':
      if i + 1 == fmtLength:
        result.add(fmtstr[i])
        break
      inc(i)
      case fmtstr[i]
      of '%':
        result.add("%")
      of 'a':
        result.add(WeekDayNames[getWeekDay(dt)][0..2])
      of 'A':
        result.add(WeekDayNames[getWeekDay(dt)])
      of 'b':
        result.add(MonthNames[dt.month][0..2])
      of 'B':
        result.add(MonthNames[dt.month])
      of 'C':
        result.add($(dt.year div 100))
      of 'd':
        result.add(intToStr(dt.day, 2))
      of 'f':
        result.add(align($dt.microsecond, 6, '0'))
      of 'F':
        result.add(intToStr(dt.year, 4))
        result.add("-")
        result.add(intToStr(dt.month, 2))
        result.add("-")
        result.add(intToStr(dt.day, 2))
      of 'g':
        let iso = toISOWeekDate(dt)
        result.add($(iso.year div 100))
      of 'G':
        let iso = toISOWeekDate(dt)
        result.add($iso.year)
      of 'H':
        result.add(intToStr(dt.hour, 2))
      of 'I':
        var hour: int
        if dt.hour == 0:
          hour = 12
        elif dt.hour > 12:
          hour = dt.hour - 12
        result.add(intToStr(dt.hour, 2))
      of 'j':
        let daynr = getYearDay(dt)
        result.add(intToStr(daynr, 3))
      of 'm':
        result.add(intToStr(dt.month, 2))
      of 'M':
        result.add(intToStr(dt.minute, 2))
      of 'p':
        if dt.hour < 12:
          result.add("AM")
        else:
          result.add("PM")
      of 'S':
        result.add(intToStr(dt.second, 2))
      of 'T':
        result.add(intToStr(dt.hour, 2))
        result.add(":")
        result.add(intToStr(dt.minute, 2))
        result.add(":")
        result.add(intToStr(dt.second, 2))
      of 'u':
        let iso = toISOWeekDate(dt)
        result.add($iso.weekday)
      of 'U':
        let first_sunday = kday_on_or_after(0, int64(toOrdinalFromYMD(dt.year, 1, 1)))
        let fixed = toOrdinal(dt).int64
        if fixed < first_sunday:
          result.add("00")
        else:
          result.add(intToStr(((fixed.int64 - first_sunday) div 7 + 1).int, 2))
      of 'V':
        let iso = toISOWeekDate(dt)
        result.add($iso.week)
      of 'w':
        result.add($getWeekDay(dt))
      of 'W':
        let first_monday = kday_on_or_after(1, toOrdinalFromYMD(dt.year, 1, 1).int64)
        let fixed = toOrdinal(dt).int64
        if fixed < first_monday:
          result.add("00")
        else:
          result.add(intToStr(((fixed - first_monday) div 7 + 1).int, 2))
      of 'y':
        result.add(intToStr(dt.year mod 100, 2))
      of 'Y':
        result.add(intToStr(dt.year, 4))
      of 'z':
        if dt.offsetKnown:
          let utcoffset = dt.utcoffset + int(dt.isDST) * 3600
          if utcoffset == 0 and not dt.isDST:
            result.add("Z")
          else:
            if utcoffset < 0:
              result.add("+")
            else:
              result.add("-")
            result.add(intToStr(abs(utcoffset) div 3600, 2))
            result.add(":")
            result.add(intToStr((abs(utcoffset) mod 3600) div 60, 2))
      else:
        discard

    elif fmtstr[i] == '$':
      inc(i)
      if len(fmtstr[i..^1]) >= 3 and fmtstr[i..i+2] == "iso":
        result.add(dt.strftime("%Y-%m-%dT%H:%M:%S"))
        inc(i, 2)
      elif len(fmtstr[i..^1]) >= 4 and fmtstr[i..i+3] == "wiso":
        result.add(dt.strftime("%G-W%V-%u"))
        inc(i, 3)
      elif len(fmtstr[i..^1]) >= 4 and fmtstr[i..i+3] == "http":
        result.add(dt.toUTC.strftime("%a, %d %b %Y %T GMT"))
        inc(i, 3)
      elif len(fmtstr[i..^1]) >=  5 and fmtstr[i..i+4] == "ctime":
        result.add(dt.toUTC.strftime("%a %b %d %T GMT %Y"))
        inc(i, 4)
      elif len(fmtstr[i..^1]) >= 6 and fmtstr[i..i+5] == "rfc850":
        result.add(dt.toUTC.strftime("%A, %d-%b-%y %T GMT"))
        inc(i, 5)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "rfc1123":
        result.add(dt.toUTC.strftime("%a, %d %b %Y %T GMT"))
        inc(i, 6)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "rfc3339":
        result.add(dt.strftime("%Y-%m-%dT%H:%M:%S"))
        if dt.microsecond > 0:
          result.add(".")
          result.add(align($dt.microsecond, 6, '0'))
        if dt.offsetKnown:
          let utcoffset = dt.utcoffset + int(dt.isDST) * 3600
          if utcoffset == 0:
            result.add("Z")
          else:
            if utcoffset < 0:
              result.add("-")
            else:
              result.add("+")
            let offset = abs(utcoffset)
            let hr = offset div 3600
            let mn = (offset mod 3600) div 60
            result.add(intToStr(hr, 2))
            result.add(":")
            result.add(intToStr(mn, 2))
        inc(i, 6)
      elif len(fmtstr[i..^1]) >= 7 and fmtstr[i..i+6] == "asctime":
        result.add(dt.strftime("%a %b %d %T %Y"))
        inc(i, 6)
    else:
      result.add(fmtstr[i])
    inc(i)


proc fromRFC3339*(self: string): DateTime =
  ## taken from Skrylars `rfc3339 <https://github.com/skrylar/rfc3339>`__
  ## module on github. with some corrections according to my own
  ## understanding of RFC3339
  ##
  ## Parses a string as an RFC3339 date, returning a DateTime object.
  var i = 0

  template getch(): char =
    inc i
    if i > self.len:
      break
    self[i-1]

  template getdigit(): char =
    let xx = getch
    if xx < '0' or xx > '9':
      break
    xx

  var scratch = newString(4)
  var work = DateTime()

  block date:
    var x: int
    # load year
    scratch[0] = getdigit
    scratch[1] = getdigit
    scratch[2] = getdigit
    scratch[3] = getdigit
    discard parseint(scratch, x)
    work.year = x

    if getch != '-': break

    # load month
    setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.month = x

    if getch != '-': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.day = x

    if getch != 'T': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.hour = x

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.minute = x

    if getch != ':': break

    #setLen(scratch, 2)
    scratch[0] = getdigit
    scratch[1] = getdigit
    discard parseint(scratch, x)
    work.second = x

    var ch = getch
    if ch == '.':
      var factor: float64 = 10.0
      var fraction: float64 = 0.0
      while true:
        setLen(scratch, 1)
        scratch[0] = getdigit
        discard parseint(scratch, x)
        fraction += float64(x) / factor
        factor *= 10
      work.microsecond = int(fraction * 1e6)
      dec(i)
      ch = getch
    case ch
      of 'z', 'Z':
        work.offsetKnown = true
        work.utcoffset = 0
      of '-', '+':
        work.offsetKnown = true
        setLen(scratch, 2)
        scratch[0] = getdigit
        scratch[1] = getdigit
        discard parseint(scratch, x)
        work.utcoffset = x * 3600

        if getch != ':': break

        scratch[0] = getdigit
        scratch[1] = getdigit
        discard parseint(scratch, x)
        work.utcoffset += x * 60

        if ch == '-':
          work.utcoffset *= -1
      else:
        discard
  return work


const DEFAULT_TRANSITION_TIME = 7200
const DEFAULT_DST_OFFSET = -3600


template myDebugEcho(x: varargs[untyped]) =
  when defined(debug):
    debugEcho(x)

proc getTransitions(rd: ptr TZRuleData, year: int): DstTransitions =
  ## gets the DST transition rules out of a Posix TZ description
  ##
  if isNil(rd.dstStartRule) or isNil(rd.dstEndRule):
    return
  result = DstTransitions()

  var year = year
  let sr = rd.dstStartRule
  let se = rd.dstEndRule

  proc swapNames() =
    let tmp = rd.dstName
    rd.dstName = rd.stdName
    rd.stdName = tmp

  proc getMonthWeekDayDate(dstRule: DstTransitionRule, offset: int, isEnd: bool): DateTime =
    var dt: DateTime
    # on the southern hemisphere the end of DST is in the next year
    if isEnd and dstRule.dstMonth < sr.dstMonth:
      year += 1
      #swapNames()
    if dstRule.dstWeek == 5:
      dt = initDateTime(year, dstRule.dstMonth + 1, 1)
      dt = nth_kday(-1, dstRule.dstWDay, dt - 1.days)
    else:
      dt = initDateTime(year, dstRule.dstMonth, 1)
      dt = nth_kday(dstRule.dstWeek, dstRule.dstWDay, dt)
    result = dt + seconds(dstRule.dstTransitionTime) + seconds(offset)

  proc getJulian0Date(dstRule: DstTransitionRule, offset: int, isEnd: bool): DateTime =
    if isEnd and dstRule.dstYDay < sr.dstYDay:
      year += 1
      #swapNames()
    var yd = toOrdinalfromYMD(year, 1, 1) + dstRule.dstYDay
    result = fromOrdinal(yd) + seconds(dstRule.dstTransitionTime) + seconds(offset)

  proc getJulian1Date(dstRule: DstTransitionRule, offset: int, isEnd: bool): DateTime =
    if isEnd and dstRule.dstNLYDay < sr.dstNLYDay:
      year += 1
      swapNames()
    var yd = toOrdinalfromYMD(year, 1, 1) + dstRule.dstNLYDay
    if isLeapYear(year) and yd > 59:
      # Day number 60 means March 1 in this system, but in a
      # leap year March 1 is day number 61, and so on
      inc(yd)
    result = fromOrdinal(yd) + seconds(dstRule.dstTransitionTime) + seconds(offset)

  case sr.kind
  of rMonth:
    result.dstStart = getMonthWeekDayDate(sr, rd.utcOffset, false)
  of rJulian0:
    result.dstStart = getJulian0Date(sr, rd.utcOffset, false)
  of rJulian1:
    result.dstStart = getJulian1Date(sr, rd.utcOffset, false)

  case se.kind
  of rMonth:
    result.dstEnd = getMonthWeekDayDate(se, rd.dstOffset, true)
  of rJulian0:
    result.dstEnd = getJulian0Date(se, rd.dstOffset, true)
  of rJulian1:
    result.dstEnd = getJulian1Date(se, rd.dstOffset, true)


proc getOffset(numberStr: string): int =
  ## handles the various possibilities to express
  ## UTC- or DST-offsets in the Posix TZ description
  ##
  let nlen = len(numberStr)
  var hours, minutes, seconds = 0

  case nlen
  of 1, 2:
    hours = parseInt(numberStr)
  of 3, 4:
    hours = parseInt(numberStr[0..1])
    minutes = parseInt(numberStr[2..^1])
  of 5, 6:
    hours = parseInt(numberStr[0..1])
    minutes = parseInt(numberStr[2..3])
    seconds = parseInt(numberStr[4..^1])
  else:
    result = -1
  result = hours * 3600 + minutes * 60 + seconds

proc parseOffset(tzstr: string, value: var int, start = 0): int =
  ## parses an UTC or DST offset as given in the Posix TZ description
  ##
  var curr = start
  var numberStr = ""
  var sign = 1
  var i = parseWhile(tzstr, numberStr, {'+', '-', '0'..'9'}, curr)
  if i == 0:
    return i
  if numberStr[0] == '-':
    sign = -1
  if i == 0:
    return 0
  if numberStr[0] in {'-', '+'}:
    numberStr = numberStr[1..^1]
  let offset = getOffset(numberStr)
  if offset < 0:
    return 0
  value = offset
  curr += i
  if len(numberStr) <= 2 and tzstr[curr] == ':':
    inc(curr)
    i = parseWhile(tzstr, numberStr, {'0'..'9'}, curr)
    if i == 0:
      return 0
    value += parseInt(numberStr) * 60
    curr += i

    if curr >= len(tzstr):
      value = sign * value
      return curr

    if tzstr[curr] == ':':
      inc(curr)
      i = parseWhile(tzstr, numberStr, {'0'..'9'}, curr)
      if i == 0:
        return 0
      value += parseInt(numberStr)
      curr += i
  value = sign * value
  return curr


proc parseMonthRule(tzstr: string, rule: var DstTransitionRule, start: int): int =
  ## parses the month rule in a DST transition rule according
  ## to the Posix TZ description
  ##
  var curr = start
  var i = 0
  var numberstr = ""
  i = parseUntil(tzstr, numberstr, '.', curr)
  if i == 0:
    return 0
  let month = parseInt(numberstr)
  if month < 1 or month > 12:
    return 0
  curr += i + 1

  i = parseUntil(tzstr, numberstr, '.', curr)
  if i == 0:
    return 0
  let week = parseInt(numberstr)
  if week < 1 or week > 5:
    return 0
  curr += i + 1

  i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
  if i == 0:
    return 0
  let wday = parseInt(numberstr)
  if wday < 0 or wday > 6:
    return 0
  inc(curr)
  rule = DstTransitionRule(kind: rMonth,
                          dstMonth: month,
                          dstWeek: week,
                          dstWDay: wday,
                          dstTransitionTime: DEFAULT_TRANSITION_TIME)
  return curr


proc parseDstRule(tzstr: string, rd: var TZRuleData, start: int, dstStart: bool): int =
  ## parses the DST Rule part of a Posix TZ description
  ##
  var curr = start
  var numberstr = ""
  var i = 0
  var rule: DstTransitionRule
  var yday: int

  if tzstr[start] == 'M':
    inc(curr)
    i = parseMonthRule(tzstr, rule, curr)
    if i == 0:
      return 0
    curr = i
  else:
    if tzstr[start] == 'J':
      inc(curr)
      i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
      if i == 0:
        return 0
      yday = parseInt(numberstr)
      if yday < 1 or yday > 365:
        return 0
      rule = DstTransitionRule(kind: rJulian1,
                                dstNLYDay: yday,
                                dstTransitionTime: DEFAULT_TRANSITION_TIME)
    else:
      i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
      if i == 0:
        return 0
      yday = parseInt(numberstr)
      if yday < 0 or yday > 365:
        return 0
      rule = DstTransitionRule(kind: rJulian0,
                                dstYDay: yday,
                                dstTransitionTime: DEFAULT_TRANSITION_TIME)
    curr += i

  var dstTransitionTime = DEFAULT_TRANSITION_TIME
  if tzstr[curr] == '/':
    inc(curr)
    i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
    if i == 0:
      return 0
    dstTransitionTime = parseInt(numberstr) * 3600
    curr += i

    if tzstr[curr] == ':':
      inc(curr)
      i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
      if i == 0:
        return 0
      curr += i
      dstTransitionTime += parseInt(numberstr) * 60
      if tzstr[curr] == ':':
        inc(curr)
        i = parseWhile(tzstr, numberstr, {'0'..'9'}, curr)
        if i == 0:
          return 0
        dstTransitionTime += parseInt(numberstr)
        curr += i
    rule.dstTransitionTime = dstTransitionTime

  if dstStart:
    rd.dstStartRule = rule
  else:
    rd.dstEndRule = rule

  return curr


proc parsetz*(tzstr: string, ruleData: var TZRuleData): bool =
  ## parses a Posix TZ definition, as described in the manual page
  ## for `tzset<https://linux.die.net/man/3/tzset>`__
  ##
  var i: int = 0
  var curr: int = i
  var strlen = len(tzstr)
  myDebugEcho(align("TZ name: ", 15), tzstr[curr..^1])
  if tzstr[0] == '<':
    i = parseUntil(tzstr, ruleData.stdName, '>')
    if i == 0:
      raise newException(ValueError, "parsing TZ name failed")
    ruleData.stdName.add(">")
    curr = i + 1
  else:
    i = parseUntil(tzstr, ruleData.stdName, {'+', '-', '0'..'9'}, 0)
    if i == 0:
      raise newException(ValueError, "parsing TZ name failed")
    curr = i

  if curr >= strlen:
    raise newException(ValueError, "no UTC offset found")

  myDebugEcho(align("UTC offset: ", 15), tzstr[curr..^1])
  i = parseOffset(tzstr, ruleData.utcOffset, curr)
  if i == 0:
    raise newException(ValueError, "parsing UTC offset failed")
  curr = i

  if curr >= strlen:
    return true

  myDebugEcho(align("DST name: ", 15), tzstr[curr..^1])
  if tzstr[0] == '<':
    i = parseUntil(tzstr, ruleData.dstName, '>', curr)
    if i == 0:
      raise newException(ValueError, "parsing DST name failed")
    ruleData.dstName.add(">")
    curr += i + 1
  else:
    i = parseUntil(tzstr, ruleData.dstName, {',', '+', '-', '0'..'9'}, curr)
    if i == 0:
      raise newException(ValueError, "parsing DST name failed")
    curr += i

  ruleData.dstOffset = ruleData.utcOffset + DEFAULT_DST_OFFSET

  if curr >= strlen:
    ruleData.dstStartRule =
      DstTransitionRule(kind: rMonth,
                        dstWday: 0,
                        dstWeek: 5,
                        dstMonth: 3,
                        dstTransitionTime: DEFAULT_TRANSITION_TIME)
    ruleData.dstEndRule =
      DstTransitionRule(kind: rMonth,
                        dstWday: 0,
                        dstWeek: 5,
                        dstMonth: 10,
                        dstTransitionTime: DEFAULT_TRANSITION_TIME)
    return true

  var startRuleFlag = true
  if tzstr[curr] == ',':
    myDebugEcho(align("DST rule: ", 15), tzstr[curr..^1], " ", startRuleFlag)
    ruleData.dstOffset = ruleData.utcOffset + DEFAULT_DST_OFFSET
    inc(curr)
    i = parseDstRule(tzstr, ruleData, curr, startRuleFlag)
    if i == 0:
      raise newException(ValueError, "parsing DST start rule failed")
    curr = i
    startRuleFlag = false
  else:
    myDebugEcho(align("DST offset: ", 15), tzstr[curr..^1])

    i = parseOffset(tzstr, ruleData.dstOffset, curr)
    if i == 0:
      raise newException(ValueError, "parsing DST offset failed")
    ruleData.dstOffset = ruleData.utcOffset + ruleData.dstOffset
    curr = i

  myDebugEcho(align("DST rule: ", 15), tzstr[curr..^1], " ", startRuleFlag)
  if tzstr[curr] == ',':
    inc(curr)
    i = parseDstRule(tzstr, ruleData, curr, startRuleFlag)
    if i == 0:
      if startRuleFlag:
        raise newException(ValueError, "parsing DST start rule failed")
      else:
        raise newException(ValueError, "parsing DST end rule failed")

    curr = i
    startRuleFlag = false

  myDebugEcho(align("DST rule: ", 15), tzstr[curr..^1], " ", startRuleFlag)
  if tzstr[curr] == ',':
    inc(curr)
    i = parseDstRule(tzstr, ruleData, curr, startRuleFlag)
    if i == 0:
      if startRuleFlag:
        raise newException(ValueError, "parsing DST start rule failed")
      else:
        raise newException(ValueError, "parsing DST end rule failed")
    curr = i

  return true


proc find_transition*(tz: ptr TZRuleData, t: float64): DstTransitions =
  ## finds the closest DST transition before a time `t` expressed
  ## in seconds since 1970-01-01T00:00:00 UTC given the rules
  ## in a Posix TZ definition, as described in the manual page
  ## for `tzset<https://linux.die.net/man/3/tzset>`__
  ##
  let dt = fromTime(t)
  result = getTransitions(tz, dt.year)


proc find_transition*(tz: ptr TZRuleData, dt: DateTime): DstTransitions =
  ## finds the closest DST transition before `dt` expressed
  ## in a Posix TZ definition, as described in the manual page
  ## for `tzset<https://linux.die.net/man/3/tzset>`__
  ##
  result = getTransitions(tz, dt.year)


proc readTZFile*(filename: string): TZFileContent =
  ## reads a compiled Olson TZ Database file
  ##
  ## adapted from similar code in Pythons
  ## `dateutil <https://pypi.python.org/pypi/python-dateutil>`__
  ## package and in the `IANA Time Zone database <https://www.iana.org/time-zones>`__
  ##
  var data = readFile(filename)
  var fp = newStringStream($data)

  result.transitionData = @[]
  result.posixTZ = "UTC"

  var v2 = false

  proc readBlock(fp: StringStream, blockNr = 1): TZFileData =
    var magic = fp.readStr(4)

    if $magic != "TZif":
      raise newException(ValueError, $filename & " is not a timezone file")

    let version = fp.readInt8() - ord('0')
    if version == 2:
      v2 = true

    discard fp.readStr(15)

    # from man 5 tzfile
    #[
      Timezone information files begin with a 44-byte header structured as follows:
            *  The magic four-byte sequence "TZif" identifying this as a timezone information file.
            *  A single character identifying the version of the file's format: either an ASCII NUL ('\0') or a '2' (0x32).
            *  Fifteen bytes containing zeros reserved for future use.
            *  Six four-byte values of type long, written in a "standard" byte order (the high-order byte of the value is  written  first).   These
                values are, in order:
                tzh_ttisgmtcnt
                      The number of UTC/local indicators stored in the file.
                tzh_ttisstdcnt
                      The number of standard/wall indicators stored in the file.
                tzh_leapcnt
                      The number of leap seconds for which data is stored in the file.
                tzh_timecnt
                      The number of "transition times" for which data is stored in the file.
                tzh_typecnt
                      The number of "local time types" for which data is stored in the file (must not be zero).
                tzh_charcnt
                      The number of characters of "timezone abbreviation strings" stored in the file.
    ]#

    var rData = TZFileData()

    rData.version = version

    var hdr = TZFileHeader()
    hdr.magic = magic
    if v2 and blockNr == 1:
      hdr.version = 0
    else:
      hdr.version = 2
    hdr.ttisgmtcnt = unpack(">i", fp.readStr(4))[0].getInt()
    hdr.ttisstdcnt = unpack(">i", fp.readStr(4))[0].getInt()
    hdr.leapcnt = unpack(">i", fp.readStr(4))[0].getInt()
    hdr.timecnt = unpack(">i", fp.readStr(4))[0].getInt()
    hdr.typecnt = unpack(">i", fp.readStr(4))[0].getInt()
    hdr.charcnt = unpack(">i", fp.readStr(4))[0].getInt()

    rData.header = hdr

    #[
      The  above  header  is  followed  by tzh_timecnt four-byte values of type long,
      sorted in ascending order. These values are written in "standard" byte order.
      Each is used as a transition time (as returned by time(2)) at which the rules
      for computing local time  change.
    ]#

    var transition_times: seq[BiggestInt] = @[]
    for i in 1..hdr.timecnt:
      if blockNr == 1:
        transition_times.add(unpack(">i", fp.readStr(4))[0].getInt)
      else:
        transition_times.add(unpack(">q", fp.readStr(8))[0].getQuad)
    rData.transitionTimes = transition_times

    #[
      Next come tzh_timecnt one-byte values of type unsigned
      char; each one tells which of the different types of
      ``local time`` types described in the file is associated
      with the same-indexed transition time. These values
      serve as indices into an array of ttinfo structures that
      appears next in the file.
    ]#

    var transition_idx: seq[int] = @[]
    for i in 1..hdr.timecnt:
      transition_idx.add(fp.readUInt8().int)
    rData.timeInfoIdx = transition_idx

    #[
      Each structure is written as a four-byte value for tt_gmtoff of type long,
      in a standard byte order, followed by a one-byte value for
      tt_isdst and a one-byte value for tt_abbrind.  In each structure,
      tt_gmtoff gives the number of seconds to be added  to  UTC,
      tt_isdst tells whether tm_isdst should be set by localtime(3), and
      tt_abbrind serves as an index into the array of timezone abbreviation
      characters that follow the ttinfo structure(s) in the file.
    ]#
    var ttinfos: seq[TimeTypeInfo] = @[]
    var abbrIdx: seq[int] = @[]

    for i in 1..hdr.typecnt:
      var tmp: TimeTypeInfo
      tmp.gmtoff = unpack(">i", fp.readStr(4))[0].getInt()
      tmp.isdst = fp.readInt8()
      abbrIdx.add(fp.readUInt8().int)
      ttinfos.add(tmp)

    var timezone_abbreviations = fp.readStr(hdr.charcnt)

    for i in 0 .. high(abbrIdx):
      let x = abbrIdx[i]
      ttinfos[i].abbrev = $timezone_abbreviations[x .. find(timezone_abbreviations, "\0", start=x) - 1]

    #[
      Then there are tzh_leapcnt pairs of four-byte values, written in standard byte order;
      the first value of each pair gives the time (as returned by time(2)) at which a leap
      second occurs;
      the second gives the total number of leap seconds to be applied after the given
      time. The pairs of values are sorted in ascending order by time.
    ]#
    var leapSecInfos: seq[LeapSecondInfo] = @[]
    for i in 1..hdr.leapcnt:
      var tmp: LeapSecondInfo
      if blockNr == 1:
        tmp.transitionTime = unpack(">i", fp.readStr(4))[0].getInt()
      else:
        tmp.transitionTime = unpack(">q", fp.readStr(8))[0].getQuad()
      tmp.correction = unpack(">i", fp.readStr(4))[0].getInt()
      leapSecInfos.add(tmp)

    rData.leapSecondInfos = leapSecInfos

    #[
      Then there are tzh_ttisstdcnt standard/wall indicators, each stored as a one-byte value;
      they tell whether the transition times associated with local time types were specified
      as standard time or wall clock time, and are used when a timezone file is used in
      handling POSIX-style timezone environment variables.
    ]#

    for i in 1..hdr.ttisstdcnt:
      let isStd = fp.readInt8()
      if isStd == 1:
        ttinfos[i - 1].isStd = true
      else:
        ttinfos[i - 1].isStd = false

    #[
      Finally, there are tzh_ttisgmtcnt UTC/local indicators, each stored as a one-byte value;
      they tell whether the transition times associated with local time types were specified as
      UTC or local time, and are used when a timezone file is used in handling POSIX-style time‐
      zone environment variables.
    ]#
    for i in 1..hdr.ttisgmtcnt:
      let isGMT = fp.readInt8()
      if isGMT == 1:
        ttinfos[i - 1].isGmt = true
      else:
        ttinfos[i - 1].isGmt = false

    rData.timeInfos = ttinfos
    result = rData

  result.transitionData.add(readBlock(fp, 1))
  if v2:
    result.version = 2
    result.transitionData.add(readBlock(fp, 2))
    discard fp.readLine()
    result.posixTZ = fp.readLine()
  fp.close()


proc find_transition*(tdata: TZFileData, epochSeconds: int): TransitionInfo =
  ## finds the closest DST transition before a time expressed
  ## in seconds since 1970-01-01T00:00:00 UTC.
  ##
  let d = tdata.transitionTimes
  var lo = 0
  var hi = len(d)
  while lo < hi:
    let mid = (lo + hi) div 2
    if epochSeconds < d[mid]:
      hi = mid
    else:
      lo = mid + 1
  var idx = lo - 1
  if idx < 0:
    idx = 0
  result.time = d[idx]
  result.data = tdata.timeInfos[tdata.timeInfoIdx[idx]]

proc find_transition*(tdata: TZFiledata, dt: DateTime): TransitionInfo =
  ## finds the closest DST transition before `dt`
  ##
  var seconds = toUnixEpochSeconds(dt)
  let utc_seconds = seconds + float64(dt.utcOffset - int(dt.isDST) * 3600)
  result = find_transition(tdata, int(utc_seconds))


# from localtime.c
const EPOCH_YEAR = 1970
const YEARSPERREPEAT* = 400
const SECSPERMIN = 60
const MINSPERHOUR =60
const HOURSPERDAY = 24
const DAYSPERWEEK* = 7
const DAYSPERNYEAR = 365
const DAYSPERLYEAR = 366
const SECSPERHOUR = SECSPERMIN * MINSPERHOUR
const SECSPERDAY = SECSPERHOUR * HOURSPERDAY
const MONSPERYEAR = 12

const MONTH_LENGTHS: array[2, array[MONSPERYEAR, int]] = [
  [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
  [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]]


proc isLeap(y: int): int =
  ## The standard way c-programmers do the test for
  ## leapyearyness. Takes advantage of the short
  ## circuiting boolen operations.
  ##
  if y mod 4 == 0 and (y mod 100 != 0 or y mod 400 == 0):
    result = 1
  else:
    result = 0

proc leaps_thru_end_of(y: int): int =
  ## counts the leap years thru the end of year `y`
  ##
  ## taken from localtime.c in the IANA TZ db distro
  ## (notably the part concerning negative years)
  ##
  if y >= 0:
    result = y div 4 - y div 100 + y div 400
  else:
    result = -(leaps_thru_end_of(-(y + 1)) + 1)

proc localFromTime*(t: float64, zoneInfo: TZInfo = nil): DateTime =
  ## gets a `DateTime` instance from a number of seconds
  ## since 1970-01-01T00:00:00+00:00 UTC, interpreted in
  ## the timezone given in parameter `zoneInfo`.
  ##
  ## adapted from the code in localtime.c in the
  ## `IANA TZ database <https://www.iana.org/time-zones>`__
  ##  distribution.
  ##
  var fracsecs = t mod 1.0
  var t = int64(t)
  var y = EPOCH_YEAR
  var tdays: int64 = t div SECSPERDAY
  var rem: int64 = t mod SECSPERDAY
  let year_lengths = [365, 366]

  var timeOffset = 0
  var utcOffset = 0
  var isDST = false

  result.microsecond = int(fracsecs * 1e6)

  if not isNil zoneInfo:
    case zoneInfo.kind
    of tzOlson:
      var odata = zoneInfo[].olsonData
      var idx = 0
      if odata.version == 2:
        idx = 1
      let trdata = odata.transitionData[idx]
      let ti = find_transition(trdata, int(t))
      timeOffset = ti.data.gmtoff
      utcOffset = timeOffset
      if ti.data.isdst == 1:
        utcOffset -= 3600
        isDST = true
      result.zoneAbbrev = ti.data.abbrev
    of tzPosix:
      var pdata = zoneInfo.posixData
      let ti = find_transition(addr(pdata), float64(t))
      if isNil(ti):
        # no DST transition rule found
        utcOffset = -pdata.utcoffset
        timeOffset = utcOffset
        isDST = false
        result.zoneAbbrev = pdata.stdName
      else:
        # we found a DST transition rule
        if t.float64 >= toUnixEpochSeconds(ti.dstStart) and t.float64 < toTime(ti.dstEnd):
          timeOffset = -pdata.dstOffset
          utcOffset = -pdata.utcOffset
          isDST = true
          result.zoneAbbrev = pdata.dstName
        else:
          timeOffset = -pdata.utcOffset
          utcOffset = timeOffset
          isDST = false
          result.zoneAbbrev = pdata.stdName

  var corr = 0
  var hit = 0
  when defined(useLeapSeconds):
    var i = 0
    if not isNil(zoneInfo) and zoneInfo.kind == tzOlson:
      let zoneData = zoneInfo.olsonData.transitionData[1]
      i = zoneData.header.leapcnt
      if i > 0 and len(zoneData.leapSecondInfos) == i:
        dec(i)
        let lsis = zoneData.leapSecondInfos
        while i >= 0:
          let lp = lsis[i]
          if t >= lp.transitionTime:
            if t == lp.transitionTime:
              if (i == 0 and lp.correction > 0) or
                 (lp.correction > lsis[i - 1].correction):
                hit = 1
              if hit != 0:
                while i > 0 and
                      lsis[i].transitionTime == lsis[i - 1].transitionTime + 1 and
                      lsis[i].correction == lsis[i - 1].correction + 1:
                  inc(hit)
                  dec(i)
            corr = lp.correction
            break
          dec(i)
  while tdays < 0 or tdays >= year_lengths[isLeap(y)]:
    var newy: int
    var tdelta: int64
    var idelta: int64
    var leapdays: int

    tdelta = tdays div DAYSPERLYEAR
    idelta = tdelta
    if idelta == 0:
      idelta = if tdays < 0: -1 else: 1
    newy = y
    newy += idelta.int

    leapdays = leaps_thru_end_of(newy - 1) - leaps_thru_end_of(y - 1)
    tdays -= (newy - y) * DAYSPERNYEAR
    tdays -= leapdays
    y = newy

  var idays = tdays

  # apply correction from timezone data
  rem += timeOffset - corr

  while rem < 0:
    rem += SECSPERDAY
    dec(idays)
  while rem >= SECSPERDAY:
    rem -= SECSPERDAY
    inc(idays)
  while idays < 0:
    dec(y)
    idays += year_lengths[isLeap(y)]
  while idays >= year_lengths[isLeap(y)]:
    idays -= year_lengths[isLeap(y)]
    inc(y)
  result.year = y
  result.hour = int(rem div SECSPERHOUR)
  rem = rem mod SECSPERHOUR
  result.minute = int(rem div SECSPERMIN)

  # here we would apply leap second correction from timezone data
  result.second = rem mod SECSPERMIN + hit

  var ip = MONTH_LENGTHS[isLeap(y)]
  var month = 0
  while idays >= ip[month]:
    idays -= ip[month]
    inc(month)
  result.month = month + 1

  result.day = int(idays + 1)

  # here we will set the offset from the timezone data
  result.utcoffset = -utcOffset
  result.isDST = isDST
  if isNil(zoneInfo):
    result.offsetKnown = false
  else:
    result.offsetKnown = true

import os, ospaths
type TimeZoneError* = object of Exception

proc getTZInfo(tzname: string, tztype: TZType = tzPosix): TZInfo =
  case tztype
  of tzPosix:
    var tzname = tzname
    if tzname.toLowerAscii() == "utc":
      tzname.add("0")
    var rule = TZRuleData()
    if not parsetz(tzname, rule):
      raise newException(TimeZoneError, "can't parse " & tzname & " as a Posix TZ value")
    var tzinfo = TZInfo(kind: tzPosix, posixData: rule)

    result = tzinfo
  of tzOlson:
    var fullpath = ""
    if fileExists(tzname):
      fullpath = tzname
    else:
      let timezoneDirs = [
        "/usr/share/zoneinfo",
        "/usr/local/share/zoneinfo",
        "/usr/local/etc/zoneinfo"
      ]
      for dir in timezoneDirs:
        if fileExists(dir / tzname):
          fullpath = dir / tzname
          break
    if fullpath == "":
      raise newException(TimeZoneError, "can't load " & tzname & " as Olson Timezone data. Giving up ...")

    let tz = readTZFile(fullpath)
    var tzinfo = TZInfo(kind: tzOlson, olsonData: tz)
    result = tzinfo


proc astimezone*(dt: DateTime, tzname: string, tztype: TZType = tzPosix): DateTime =
  ## convert the DateTime in `dt` into the same time in another timezone
  ## given in `tzname`. `tzname` is either the name of an Olson timezone
  ## or a Posix TZ description as described in the `tzset<https://linux.die.net/man/3/tzset>`__
  ## man page.
  ##
  ## Olson timezone files are looked up in the directory /usr/share/zoneinfo.
  ## Other locations can be added to ``timezoneDirs``.
  ##
  ## It is itentional, that the `TZ` and `TZDIR` environment variables are not consulted.
  ##
  ## inspired by the somewhat similar function in Python
  ##
  let utctime = toTime(dt) + float64(dt.utcoffset - int(dt.isDST) * 3600)
  try:
    let tzinfo = getTZInfo(tzname, tztype)
    result = localFromTime(utctime, tzinfo)
  except:
    stderr.write(getCurrentExceptionMsg())
    stderr.write("\L")
    result = fromTime(utctime)


template asUTC*(dt: DateTime): DateTime =
  ## return a `DateTime` with the currently stored instant
  ## converted to UTC time.
  ##
  dt.astimezone("UTC0", tzPosix)


proc setTimezone*(dt: DateTime, tzname: string, tztype: TZType = tzPosix): DateTime =
  ## return a `DateTime` with the same date/time as `dt` but with the timezone settings
  ## changed to `tzname` of zone type `tztype`
  ##
  try:
    let tzinfo = getTZInfo(tzname, tztype)
    result = localFromTime(toUnixEpochSeconds(dt), tzinfo)
    let abbrev = result.zoneAbbrev
    result = result + seconds(result.utcoffset - int(result.isDST) * 3600)
    result.zoneAbbrev = abbrev
  except:
    stderr.write(getCurrentExceptionMsg())
    stderr.write("\L")
    result = dt


when defined(js):
  proc paramStr(n: int): string =
    var args {.importc.}: seq[cstring]
    {.emit: "`args` = process.argv;" .}
    return $args[n+1]


when isMainModule:
  # some experiments and tests ...
  #

  echo "what's the datetime of the first day in backwards"
  echo "extrapolated (proleptic) gregorian calendar?"

  var dt = fromOrdinal(1)
  echo $dt
  echo $dt.toTimeStamp()

  echo ""
  echo "can we store fractional seconds?"
  dt = fromTimeStamp(TimeStamp(seconds: 86401, microseconds: 1234567890))
  echo $dt
  echo $dt.toTimeStamp()

  echo ""
  echo "store the current UTC date/time given by the running system"
  var current = fromUnixEpochSeconds(epochTime(), hoffset=0, moffset=0)

  echo "now: ", current, " weekday: ", getWeekDay(current), " yearday: ", getYearDay(current)

  echo ""
  echo "the date/time value of the start of the UnixEpoch"
  var epd = fromTimeStamp(TimeStamp(seconds: float(UnixEpochSeconds)))
  echo "epd: ", epd
  echo ""

  var td = current - epd
  echo "time delta since Unix epoch: ", td
  echo "total seconds since Unix epoch: ", td.totalSeconds()
  echo "epd + ts ", fromTimeStamp(epd.toTimeStamp() + initTimeStamp(seconds = td.totalSeconds()))
  echo "epd + td ", epd + td
  assert epd + td == current
  echo "now - td ", current - td
  assert current - td == epd

  echo ""
  echo epd.toTimeStamp()
  echo initTimeStamp(seconds = td.totalSeconds)
  echo epd.toTimeStamp() + initTimeStamp(seconds = td.totalSeconds())

  echo ""
  var ti = current.toTimeInterval() - epd.toTimeInterval()
  echo "TimeInterval since Unix epoch:"
  echo $ti
  echo "epd + ti: ", epd + ti, " == ", current
  echo "now - ti: ", current - ti, " == ", epd
  echo ""
  echo "TimeInterval back to Unix epoch:"
  ti = epd.toTimeInterval() - current.toTimeInterval()
  echo $ti
  echo "now + ti: ", current + ti, " == ", epd
  assert current + ti == epd
  echo "epd - ti: ", epd - ti, " == ", current
  assert(epd - ti == current)

  echo ""
  echo "can we initialize a TimeDelta value from a known number of seconds"
  td = initTimeDelta(seconds=td.totalSeconds, microseconds=td.microseconds.float64)
  echo td
  echo epd + td, " ", current
  assert epd + td == current

  # experiments with fractional values used to initialize
  # a TimeDelta and playing with relative date/time differences
  # inspired by nim's standard library.
  td = initTimeDelta(microseconds=1.5e6, days=0.5, minutes=0.5)
  echo(7.months + 5.months + 1.days + 35.days + 72.hours + 75.25e6.int.microseconds)
  echo current + 1.years - (12.months + 5.months)
  echo current + 1.years - 12.months + 5.months

  echo ""
  echo  "some notable dates in the Unix epoch ..."

  var a = fromUnixEpochSeconds(1_000_000_000)
  var b = fromUnixEpochSeconds(1_111_111_111)
  var c = fromUnixEpochSeconds(1_234_567_890)
  var d = fromUnixEpochSeconds(1_500_000_000)
  var e = fromUnixEpochSeconds(2_000_000_000)
  var f = fromUnixEpochSeconds(2_500_000_000.0)
  var g = fromUnixEpochSeconds(3_000_000_000.0)
  echo ""
  echo "one billion seconds since epoch:   ", $a, " time delta: ", $(a - epd)
  assert int((a - epd).totalSeconds()) == 1_000_000_000
  echo "1_111_111_111 seconds since epoch: ", $b, " time delta: ", $(b - epd)
  assert int((b - epd).totalSeconds()) == 1_111_111_111
  echo "1.5 billion seconds since epoch:   ", $c, " time delta: ", $(c - epd)
  assert int((c -  epd).totalSeconds()) == 1_234_567_890
  echo "1_234_567_890 seconds since epoch: ", $d, " time delta: ", $(d - epd)
  assert int((d - epd).totalSeconds()) == 1_500_000_000
  echo "2   billion seconds since epoch:   ",   $e, " time delta: ", $(e - epd)
  assert int((e - epd).totalSeconds()) == 2_000_000_000
  echo "2.5 billion seconds since epoch:   ",   $f, " time delta: ", $(f - epd)
  assert((f - epd).totalSeconds() == 2_500_000_000.0)
  echo "3   billion seconds since epoch:   ", $e, " time delta: ", $(e - epd)
  assert((g - epd).totalSeconds() == 3_000_000_000.0)

  echo "check dates from wikipedia page about Unix Time"
  assert $a == "2001-09-09T01:46:40"
  assert $b == "2005-03-18T01:58:31"
  assert $c == "2009-02-13T23:31:30"
  assert $d == "2017-07-14T02:40:00"
  assert $e == "2033-05-18T03:33:20"

  echo ""
  echo "the end of the Unix signed 32bit time:"
  e = fromUnixEpochSeconds(pow(2.0, 31))
  assert $e == "2038-01-19T03:14:08"
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval())), " from now"
  echo "using the new loopless toTimeInterval(dt1, dt2)"
  echo $e, " ", toTimeInterval(e, current)

  echo "the smallest representable time in signed 32bit Unix time:"
  e = fromUnixEpochSeconds(-pow(2.0, 31))
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval())), " from now"
  echo toTimeInterval(e, current)
  assert $e == "1901-12-13T20:45:52"
  assert ((e + toTimeInterval(e, current)) - current).totalSeconds() < 0.000002
  assert current - toTimeInterval(e, current) == e
  assert e - toTimeInterval(current, e) == current
  assert current + toTimeInterval(current, e) == e
  echo ""
  echo "the end of the Unix unsigned 32bit time:"
  e = fromUnixEpochSeconds(pow(2.0, 32) - 1)
  echo $e, " ", ($(e.toTimeInterval() - current.toTimeInterval())), " from now"
  echo toTimeInterval(e, current)
  assert $e == "2106-02-07T06:28:15"
  when not defined(js):
    echo "the end of the Unix signed 64bit time:"
    echo "first calculate the maximal date from a signed 64bit number of seconds since 0001-01-01:"
    var maxordinal = quotient(high(int64), 86400)
    var maxdate = fromOrdinal(maxordinal)
    echo "maxdate: ", maxdate
    echo "now we add the Unix epoch start date as a TimeDelta"
    maxdate = maxdate + toTimeDelta(epd)
    echo maxdate
    var time_in_maxdate = high(int64) - maxordinal * 86400
    echo "the remaining seconds give the time of day on maxdate: ", time_in_maxdate
    maxdate.hour = int(time_in_max_date div 3600)
    maxdate.minute = int((time_in_max_date - 3600 * maxdate.hour) div 60)
    maxdate.second = int(time_in_max_date mod 60)
    echo "now we have the end of the signed 64bit Unix epoch time:"
    echo maxdate, " is it a leap year? ", if isLeapYear(maxdate.year): "yes" else: "no"
    var lycount = countLeapYears(maxdate.year)
    echo "leap years before the end of 64bit time: ", lycount

    assert $maxdate == "292277026596-12-04T15:30:07"

  # playing with the surprisingly powerful idea to
  # convert DateTime values into time differences
  # relative to the start of the gregorian calendar.
  # we get a working base to calculate relative
  # time differences.
  echo "time intervals:"
  ti = b.toTimeInterval() - a.toTimeInterval()
  var ti2 = c.toTimeInterval() - a.toTimeInterval()
  echo "time interval ti between ", a, " and ", b
  echo ti
  echo "a + ti:  ", a + ti, " == ", b
  assert $(a + ti) == $b
  echo "b - ti:  ", b - ti, " == ", a
  assert $(b - ti) == $a
  echo "---"
  echo "time interval ti2 between ", a, " and ", c
  echo ti2
  echo "a + ti2: ", a + ti2, " == ", c
  assert $(a + ti2) == $c
  echo "c - ti2: ", c - ti2, " == ", a
  assert $(c - ti2) == $a

  echo "---"

  # usually there is the problem that you get different
  # results in relative time difference calculations,
  # depending on whether you first add/subtract the values
  # from big to small or from small to big.

  # relative time differences using months is a highly
  # problematic matter which i am only marginally interested
  # in. usually you don't get to the same point if you add
  # a number of months and then subtract the same number
  # again. An example: typically if you add 1 month to january 31
  # the algorithms in use are clever enough to land on february 28 or 29
  # but when you go back one month... let's see:
  echo "experimenting with time intervals:"
  var j = parse("2020-01-31 01:02:03", "yyyy-MM-dd hh:mm:ss")
  echo "start: ", j
  echo "plus one month:"
  echo toTimeStamp(j, 1.months)
  let j1 = j + 1.months
  echo j1
  echo "and back:"
  j = j1 - 1.months
  echo j
  echo "we are no longer on the same date, but it is not clear, what could be done to fix that."
  echo "the logic used here is:"
  echo "given the reference datetime dt"
  echo "first subtract the day in month from dt to get to the first day of the month in dt"
  echo "then add/subtract the number of months from dt (actually the number of seconds the"
  echo "month difference is worth relative to dt)."
  echo "add the day in month from dt back to the result."
  echo "if the day does not exist in the target month, correct the day to the last day in the target month."
  echo ""
  echo "subtracting years: ", ti.years, " from: ", b
  var tmp = b - years(ti.years.int)
  echo tmp
  echo "subtracting months: ", ti.months
  tmp = tmp - months(ti.months.int)
  echo tmp
  echo "subtracting days: ", ti.days
  tmp = tmp - days(ti.days.int)
  echo tmp

  echo ""
  echo "negative time interval ti between earlier and later: ", $a, " and ", $b
  echo "---"
  ti = a.toTimeInterval() - b.toTimeInterval()
  echo $ti
  echo "a - ti:  ", a - ti, " == ", b
  echo "b + ti:  ", b + ti, " == ", a
  echo "---"
  echo "negative time interval ti2 between earlier: ", a, " and later ", c
  ti2 = a.toTimeInterval() - c.toTimeInterval()
  echo $ti2
  echo "a - ti2: ", a - ti2, " == ", c
  echo "c + ti2: ", c + ti2, " == ", a

  #
  # some silliness ...
  echo ""
  echo "back 100_000 years"
  var z = current - 100_000.years
  echo z
  echo "and forward again"
  echo  z + 100_000.years
  echo ""
  echo "one million years and 1001 days forward"
  z = current + 1_000_000.years + initTimeDelta(days = 1001)
  echo z, ", ", z.getWeekDay(), " ", z.getYearDay()
  echo "and back again in two steps"
  z = z - 1_000_000.years
  echo z
  echo z - initTimeDelta(days = 1001)

  #
  echo ""
  echo "easter date next 10 years:"
  for i in 1..10:
    echo easter((current + i.years).year).strftime("$iso, $asctime, $wiso")
