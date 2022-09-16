# aparseopt

alternate/another parseopt - API incompatible alternative for Nim's 
[std/parseopt][parseopt-docs]. Supports the same
syntax as parseopt, along with POSIX style options.

Important changes:
 - No value options are called "flags" and are distinquishable from options
 - Both POSIX style and parseopt style:
    - `-oval`, `-o val`, `-o:val` and `-o=val` are all equivalent
    - `--option val`, `--option:val`, and `--option=val` are all equivalent
    - short flag bundles: `-abcd` is the same as `-a -b -c -d`
 - `-` is parsed as an argument
 - `--` is now distinquishable from a long option

## Example

```nim
import aparseopt

var p = OptParser.init(
    "-ab -e 5 --foo --bar=20 file.txt - -- -s -arg --",
    shortFlags = {'a', 'b'},
    longFlags = @["foo"]
)
while p.hasNext():
  p.next()
  case p.current.kind
  of cakArgument:
    echo "Argument: ", p.current.val
  of cakShortFlag, cakLongFlag:
    echo "Flag: ", p.current.key
  of cakShortOption, cakLongOption:
    echo "Option: ", p.current.key, ", ", p.current.val 
  of cakStopParsing:
    echo "Unparsed arguments: ", p.remainingArgs()
    break
```

Results in the following output:
```
Flag: a
Flag: b
Option: e, 5
Flag: foo
Option: bar, 20
Argument: file.txt
Argument: -
Unparsed arguments: @["-s", "-arg", "--"]
```

## Motivation

I was writing my own command line parser utility akin to
[argparse][argparse-link] and [cligen][cligen-link], and I found that parseopt
suited most of my needs except for POSIX style options. So I created this to
add that functionality, as well as making additional changes in an attempt to
modernize the API, as well as making it easier to use.

## Changes to parseopt's API

 - `CmdLineKind` renamed to `CmdArgKind`
   - removed `cmdEnd`
   - renamed `cmdArgument` to `cakArgument`
   - renamed `cmdLongOption` to `cakLongOption`
   - renamed `cmdShortOption` to `cakShortOption`
   - added `cakStopParsing`, `cakShortFlag` and `cakLongFlag`

- added object type `CmdArg` which contains a `kind`, `key`, and `val`

- `OptParser` is now just an `object`
  - `shortNoVal` and `longNoVal` renamed to `shortFlags*` and `longFlags*`, respectively
  - `pos` is no longer exported (uses getter/setter procs instead)
  - `cmds` renamed to `input`
  - `kind*`, `key*` and `val*` replaced by `current` of type `CmdArg` (has a getter proc)
  - `inShortSpace` and `idx` replaced by `shortFlagPos`
  - removed `allowWhitespaceAfterColon`, as the documentation says nothing
    about this field, yet it is a parameter in `initOptParser`

- `initOptParser` procs use `T.init` style initializers
- `getopt` iterator yields a `CmdArg` instead of a tuple
- removed convenience `getopt` that initializes an OptParser.
- removed `cmdLineRest` proc


[parseopt-docs]: https://nim-lang.org/docs/parseopt.html
[cligen-link]: https://github.com/c-blake/cligen
[argparse-link]: https://github.com/iffy/nim-argparse
