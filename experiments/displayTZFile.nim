import strutils
import streams
import struct
import os

import ZonedDateTime

type TZFileHeader = object
  magic:      string ## The identification magic number of TZ Data files.
  version:    int8 ## The version of the TZ Data File
  ttisgmtcnt: int ## The number of UTC/local indicators stored in the file.
  ttisstdcnt: int ## The number of standard/wall indicators stored in the file.
  leapcnt*:    int ## The number of leap seconds for which data is stored in the file.
  timecnt:    int ## The number of "transition times" for which data is stored in the file.
  typecnt:    int ## The number of "local time types" for which data is stored in the file (must not be zero).
  charcnt:    int ## The number of characters of "timezone abbreviation strings" stored in the file.

type TimeTypeInfo = object
  gmtoff*: int
  isdst*: int8
  isstd: bool
  isgmt: bool
  abbrev*: string


type LeapSecondInfo = tuple
  transitionTime: BiggestInt
  correction: int

type TZFileData* = object
  version: int8
  header*: TZFileHeader
  transitionTimes: seq[BiggestInt]
  timeInfoIdx: seq[int]
  timeInfos: seq[TimeTypeInfo]
  leapSecondInfos*: seq[LeapSecondInfo]

type tzFileContent* = object
  version*: int
  transitionData*: seq[TZFileData]
  posixTZ*: string

type TransitionInfo = object
  time*: BiggestInt
  data*: TimeTypeInfo


proc readTZFile*(filename: string): tzFileContent =
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
  var seconds = toUnixEpochSeconds(dt)
  let utc_seconds = seconds + float64(dt.utcOffset - int(dt.isDST) * 3600)
  result = find_transition(tdata, int(utc_seconds))


when isMainModule:
  var filename: string
  if paramCount() < 1:
    filename = "/etc/localtime"
  else:
    filename = paramStr(1)

  let tzinfo = initTZInfo(filename, tzOlson)

  let data = readTZFile(filename)
  filename = filename.replace("/usr/share/zoneinfo/", "")
  #when defined(showFile):
  when true:
    for tdata in data.transitionData:
      #echo filename & " Version: ", repr(tdata.version)
      echo filename & " " & $tdata.header
      when true:
        for i in 0 .. high(tdata.transitionTimes):
          var line = filename & " "
          line.add(tdata.transitionTimes[i])
          line.add(" ")
          line.add($fromUnixEpochSeconds(float64(tdata.transitionTimes[i])))
          line.add(" ")
          let ti = tdata.timeInfos[tdata.timeInfoIdx[i]]
          line.add(align($ti.gmtoff, 5, ' '))
          line.add(" ")
          line.add($ti.isdst)
          line.add(" ")
          line.add($int(ti.isstd))
          line.add(" ")
          line.add($int(ti.isgmt))
          line.add(" ")
          line.add(ti.abbrev)
          echo line
        if tdata.header.leapcnt > 0:
          let lsi = tdata.leapSecondInfos
          for x in lsi:
            var line = filename & " LeapSecond: "
            line.add(x.transitionTime)
            line.add(" ")
            line.add($localFromTime(float64(x.transitionTime), tzinfo))
            line.add(" ")
            line.add($x.correction)
            echo line

  echo "posixTZ: ", data.posixTZ

  when defined(showTime):
    var n = now()
    # n.setUtcOffset(seconds = -3600)
    # n.isDST = true

    # echo "Now: ", n
    var tri = find_transition(data.transitionData[1], n)
    # echo fromUnixEpochSeconds(float(tri.time)), " ", tri.data
    echo ""
    # n = parse(paramStr(2), "yyyy-MM-dd hh:mm:ss")
    # n.isDST = true
    # n.utcOffset = -3600
    tri = find_transition(data.transitionData[1], n)
    echo "Date: ", n
    echo repr(n)
    echo "Transition: ", fromTime(float(tri.time)), " ", tri.data
    if n.utcOffset != -1 * tri.data.gmtoff or int(n.isDST) != tri.data.isdst:
      n.setUtcOffset(seconds = (tri.data.gmtoff - int(tri.data.isdst) * 3600) * -1)
      #n = n - seconds(tri.data.gmtoff - int(tri.data.isdst) * 3600)
    n.isDST = tri.data.isdst != 0
    echo "Date: ", n
    echo repr(n)


  when defined(doTest):
    n.year = 1852
    # n.day = 29
    # n.hour = 2
    # n.minute = 59
    # n.second = 59
    # n.microsecond = 999999
    echo n
    var eps = int(toUnixEpochSeconds(n)) - 7200
    echo eps, " ", fromUnixEpochSeconds(eps.float64)

    var idx = 0
    if data.version == 2:
      idx = 1

    var trinfo = find_transition(data.transitionData[1], eps)
    echo "Transition Time: ", trinfo.time, " ", fromUnixEpochSeconds(trinfo.time.float64)
    echo "Transition Data: ", trinfo.data
    trinfo = find_transition(data.transitionData[1], eps + 1)
    echo "Transition Time: ", trinfo.time, " ", fromUnixEpochSeconds(trinfo.time.float64)
    echo "Transition Data: ", trinfo.data

    for i in 1..200:
      eps = int(toUnixEpochSeconds(n + i.years)) - 7200
      trinfo = find_transition(data.transitionData[1], eps)
      var curr = fromUnixEpochSeconds(eps.float)
      echo fromUnixEpochSeconds(eps.float), " ", fromUnixEpochSeconds(trinfo.time.float), " ", trinfo.data
      curr = curr + seconds(trinfo.data.gmtoff)
      curr.setUtcOffset(seconds = trinfo.data.gmtoff * -1)
      if trinfo.data.isdst == 0:
        curr.isDST = false
      else:
        curr.isDST = true
      echo curr
