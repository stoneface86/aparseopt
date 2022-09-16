
version         = "0.0.1"
author          = "stoneface"
description     = "API incompatible alternative for Nim's std/parseopt"
license         = "MIT"
binDir          = "bin"
installFiles    = @["aparseopt.nim"]


requires "nim >= 1.6.0"

task tester, "Builds the unit tester":
    switch("outdir", binDir)
    setCommand("c", "tests/tester.nim")

task docs, "Builds documentation":
    exec "nim doc --hints:off --project --index:on --outdir:htmldocs aparseopt.nim"
    exec "nim buildIndex --hints:off -o:htmldocs/theindex.html htmldocs"
