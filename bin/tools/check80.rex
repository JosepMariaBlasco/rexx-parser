
Call SysFileTree Arg(1), Files, "SFO"

Loop i = 1 To Files.0
  file = files.i
  Say i": Examining '"file"'..."
  lines = .File~readLines(file)
  Loop Counter c line Over lines
    If line~endsWith("*/") Then Do
      length = line~length
      If length < 10 Then Iterate
      If length \== 80 Then Do
        Say "Possible misaligned comment at line" c":"
        Say "-->" line
      End
    End
    If line~endsWith("--") Then Do
      length = line~length
      If length < 10 Then Iterate
      If length \== 80 Then Do
        Say "Possible misaligned comment at line" c":"
        Say "-->" line
      End
    End
  End
End