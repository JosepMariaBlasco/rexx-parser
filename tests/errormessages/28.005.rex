Do Label l1
  Select label l1
    When 1 Then Do Label l2
      If 1 then Do Label l3
        Iterate l1
      End
    End
  End  
End