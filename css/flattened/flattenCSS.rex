Call SysFileTree "../*.css", CSS., "FO"

sep = .File~separator

Do i = 1 To CSS.0
  name     = FileSpec("Name",CSS.i)
  location = FileSpec("Location",CSS.i)
  Say "Copy" CSS.i "unflattened.css"
  Say "Call npx postcss unflattened.css -o flattened.css --config postcss.config.js"
  Say "Copy flattened.css" Location"flattened"sep||name
End