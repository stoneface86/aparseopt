##
## aparseopt - another/alternate parseopt
## 
## An API-incompatible alternative for std/parseopt, supporting both parseopt
## and POSIX style syntax.
## 
## Supported Syntax
## ================
## 
## Optional arguments are specified with a `-` for short named options and
## `--` for long named options. Option arguments have a value associated with
## the key name. Arguments without a value given are known as flags and are
## typically used to enable a specific behavior for the program.
## 
## Short optionals
## ---------------
## 
## - flags: `-a`, `-b`
## - flag "bundles": `-abcd` where a, b, c and d are in the parser's `shortFlags`
## - options:
##   - POSIX style no delimiter: `-oval`
##   - parseopt style delimiter: `-o:val` or `-o=val`
##   - POSIX style next argument: `-o val`
## 
## Long optionals
## --------------
## 
## - flags: `--help`, `--verbose`, `--really-long-flag`
## - options:
##   - parseopt style delimiter: `--option:val` or `--option=val`
##   - POSIX style next argument: `--option val`
## 
## Specials
## --------
## 
## The argument `--` has its own unique kind, `cakStopParsing`, and is used to
## signal that all arguments ahead of it should not be parsed.
## 
## The argument `-` is always parsed as a plain argument, typically used to
## specify that the program should read from `stdin` or write to `stdout`.
## 
## Plain arguments
## ---------------
## 
## For everything else that was not parsed as the above, the argument is
## considered a plain positional argument.
## 
## Parsing
## =======
## 
## Parsing is done by using an `OptParser<#OptParser>`_ object. Initialize one
## by using one of the `init <#init%2Ctypedesc[OptParser]%2Csinkseq[string]%2Cset[char]%2Csinkseq[string]>`_
## procs. Then use `next <#next,OptParser>`_ to parse a single argument.
## 
## Example:
## 
## .. code-block::
##   import aparseopt
##   
##   var p = OptParser.init(
##       "-ab -e 5 --foo --bar=20 file.txt - -- -s -arg --",
##       shortFlags = {'a', 'b'},
##       longFlags = @["foo"]
##   )
##   while p.hasNext():
##     p.next()
##     case p.current.kind
##     of cakArgument:
##       echo "Argument: ", p.current.val
##     of cakShortFlag, cakLongFlag:
##       echo "Flag: ", p.current.key
##     of cakShortOption, cakLongOption:
##       echo "Option: ", p.current.key, ", ", p.current.val 
##     of cakStopParsing:
##       echo "Unparsed arguments: ", p.remainingArgs()
##       break
##  
## Results in the following output:
##
## .. code-block::
##   Flag: a
##   Flag: b
##   Option: e, 5
##   Flag: foo
##   Option: bar, 20
##   Argument: file.txt
##   Argument: -
##   Unparsed arguments: @["-s", "-arg", "--"]
## 
## There is also a convenience iterator, `getopt <#getopt.i,OptParser>`_, that
## can be used to iterate through all command line arguments.
## 
## `shortFlags` and `longFlags`
## ============================
## 
## In order for the parser to be able to recognize short or long flags, the
## parser's `shortFlags` and `longFlags` sets need to be set up. The parser
## determines whether an optional argument is an option or a flag by checking
## if the argument's name is in the respective set. Otherwise, if the name is
## not in the set, the parser will parse it as an option.
## 
## See also
## ========
## 
## - `parseopt <https://nim-lang.org/docs/parseopt.html>`_ - the standard
##   library module
## - `parseopt3 <https://c-blake.github.io/cligen/cligen/parseopt3.html>`_ -
##   API compatible with parseopt with improvements and new features.
##

import std/[critbits, os, strutils]

type
    TokenKind = enum
        tkShortFlagOrOption
            # "-a" or "-a 3"
        tkShortFlagsOrOption
            # "-abcd" where a, b, c, and d are all flags
            # "-a3" where a is an option and 3 is the parameter
        tkShortOption
            # "-f:3" or "-f=3"
        tkLongFlagOrOption
            # "--long-flag" or "--long-option 3"
        tkLongOption
            # "--long-option:3" or "--long-option=3"
        tkStopOptionParsingDirective
            # "--", used to signal to the parser to stop parsing options
        tkArgument
            # everything else

    Token = object
        case kind: TokenKind
        of tkShortFlagOrOption:
            shortname: char
        of tkShortFlagsOrOption:
            firstShortname: char
        of tkShortOption:
            shortOptionKey: char
            shortOptionVal: string
        of tkLongFlagOrOption:
            longFlagOrOptionKey: string
        of tkLongOption:
            longOptionKey: string
            longOptionVal: string
        of tkStopOptionParsingDirective: discard
        of tkArgument: discard

    CmdArgKind* = enum
        ## The kind of argument that was parsed
        cakArgument     ## An argument such as a filename
        cakShortFlag    ## short optional argument without a value ie -c
        cakLongFlag     ## long optional argument without a value ie --verbose
        cakShortOption  ## short optional argument such as -o file
        cakLongOption   ## long optional argument such as --output file
        cakStopParsing  
            ## an argument of "--" indicates the parser should not parse all
            ## arguments following it

    CmdArg* = object
        ## The parsed representation of a command line argument
        kind*: CmdArgKind
            ## the arg's kind
        key*: string
            ## The name of the flag or option. Left empty for cakArgument and
            ## cakStopParsing
        val*: string
            ## The value assigned to the option, or the value of the argument
            ## for cakArgument args. Left empty for cakShortFlag, cakLongFlag
            ## and cakStopParsing args.

    OptParser* = object
        ## Implementation of the command line parser. Must be initialized via
        ## the `init` proc.
        ## 
        ## The `shortFlags` and `longFlags` fields are sets that are used to
        ## determine if a key is a flag or an option. If the key is in the set,
        ## it will be parsed as a flag. Otherwise it will be parsed as an
        ## option. These are initialized by the `init` proc but they can be
        ## modified whenever.
        ## 
        ## .. note:: While this object shares the same name as parseopt's, it
        ##           does not use the exact same API
        ## 
        pos: int
        input: seq[string]
        current: CmdArg
        shortFlagPos: int
        shortFlags*: set[char]
            ## A set containing the keys of all short named flags that is
            ## recognized by the parser.
        longFlags*: CritBitTree[void]
            ## A set containing the keys of all long named flags that is
            ## recognized by the parser.


const
    optionDelimiters = {':', '='}

func getToken(arg: string): Token =
    if arg[0] == '-' and arg.len > 1:
        if arg[1] == '-':
            if arg.len == 2:
                Token(kind: tkStopOptionParsingDirective)
            else:
                let delimIdx = arg.find(optionDelimiters, 2)
                if delimIdx == -1:
                    Token(
                        kind: tkLongFlagOrOption,
                        longFlagOrOptionKey: arg[2..^1]
                    )
                else:
                    Token(
                        kind: tkLongOption,
                        longOptionKey: arg[2..delimIdx-1],
                        longOptionVal: arg[delimIdx+1..^1]
                    )
        else:
            if arg.len == 2:
                Token(kind: tkShortFlagOrOption, shortname: arg[1])
            else:
                if arg[2] in optionDelimiters:
                    Token(
                        kind: tkShortOption,
                        shortOptionKey: arg[1],
                        shortOptionVal: arg[3..^1]
                    )
                else:
                    Token(kind: tkShortFlagsOrOption, firstShortname: arg[1])
    else:
        Token(kind: tkArgument)

func init*(_: typedesc[OptParser],
    cmd: sink seq[string],
    shortFlags: set[char] = {},
    longFlags: sink seq[string] = @[]
): OptParser =
    ## Convenience overload taking a seq of arguments instead of a command line
    ## string.
    _(
        input: cmd,
        shortFlags: shortFlags,
        longFlags: longFlags.toCritBitTree
    )

proc init*(_: typedesc[OptParser],
    cmd: sink string,
    shortFlags: set[char] = {},
    longFlags: sink seq[string] = @[]
): OptParser =
    ## Initializes an OptParser.
    ## 
    ## The parser's input is initialized to the result of `parseCmdLine(cmd)`
    ## if cmd was not empty. Otherwise if `cmd` was empty, then the real
    ## command line as provided by the `os` module is retrieved instead.
    ## 
    ## `shortFlags` and `longFlags` can be specified if you want the parser to
    ## recognize flag arguments.
    ## 
    _.init(
        block:
            if cmd.len == 0:
                commandLineParams()
            else:
                cmd.parseCmdLine()
        , shortFlags, longFlags
    )

func pos*(p: OptParser): int =
    ## Gets the index of the argument that will be parsed next
    ## 
    p.pos

proc `pos=`*(p: var OptParser, pos: int) =
    ## Modify/seek to the index of the argument that will be parsed next.
    ## 
    doAssert pos in 0..p.input.len-1, "cannot set position outside bounds of input"
    p.pos = pos
    p.shortFlagPos = 0

func current*(p: OptParser): lent CmdArg =
    ## Gets the current `CmdArg<#CmdArg>`_ that was processed by the last call
    ## to `next<#next,OptParser>`_.
    ## 
    p.current

template hasInput(p: OptParser): bool =
    p.pos < p.input.len

template advance(p: var OptParser): untyped =
    inc p.pos

template inputAtPos(p: var OptParser): string =
    p.input[p.pos]

proc takeArgument(p: var OptParser) =
    p.current.kind = cakArgument
    p.current.key.setLen(0)
    p.current.val = p.input[p.pos]
    p.advance()

proc takeOptionArgument(p: var OptParser) =
    if p.hasInput():
        let next = p.inputAtPos()
        let nexttoken = next.getToken()
        if nexttoken.kind == tkArgument:
            p.current.val = next
            p.advance()

proc setKeyToChar(p: var OptParser, ch: char) =
    p.current.key.setLen(1)
    p.current.key[0] = ch

proc beginShortFlags(p: var OptParser) =
    p.shortFlagPos = 1
    p.current.kind = cakShortFlag
    p.current.key.setLen(1)
    p.current.val.setLen(0)

proc handleShortFlags(p: var OptParser, arg: string) =
    p.current.key[0] = arg[p.shortFlagPos]
    inc p.shortFlagPos
    if p.shortFlagPos >= arg.len:
        p.advance()
        p.shortFlagPos = 0

proc nextImpl(p: var OptParser) =
    let curr = p.inputAtPos()
    if p.shortFlagPos == 0:
        let token = curr.getToken
        case token.kind
        of tkShortFlagOrOption:
            p.setKeyToChar(token.shortname)
            p.current.val.setLen(0)
            p.advance()
            if token.shortname in p.shortFlags:
                p.current.kind = cakShortFlag
            else:
                p.current.kind = cakShortOption
                p.takeOptionArgument()
        of tkShortFlagsOrOption:
            if token.firstShortname in p.shortFlags:
                p.beginShortFlags()
                p.handleShortFlags(curr)
            else:
                p.setKeyToChar(token.firstShortname)
                p.current.kind = cakShortOption
                p.current.val = curr[2..^1]
                p.advance()
        of tkShortOption:
            p.current.kind = cakShortOption
            p.setKeyToChar(token.shortOptionKey)
            p.current.val = token.shortOptionVal
            p.advance()
        of tkLongFlagOrOption:
            p.current.key = token.longFlagOrOptionKey
            p.current.val.setLen(0)
            p.advance()
            if p.current.key in p.longFlags:
                p.current.kind = cakLongFlag
            else:
                p.current.kind = cakLongOption
                p.takeOptionArgument()
        of tkLongOption:
            p.current.kind = cakLongOption
            p.current.key = token.longOptionKey
            p.current.val = token.longOptionVal
            p.advance()
        of tkStopOptionParsingDirective:
            p.current.kind = cakStopParsing
            p.current.key.setLen(0)
            p.current.val.setLen(0)
            p.advance()
        of tkArgument:
            p.takeArgument()
    else:
        p.handleShortFlags(curr)

func hasNext*(p: OptParser): bool =
    ## Returns `true` if `next<#next,OptParser>`_ will produce a new `CmdArg<#CmdArg>`_
    ## 
    p.hasInput()

proc next*(p: var OptParser) =
    ## Parse the next token and stores it in `p.current`. If there is no next
    ## token, `p.current` is left unchanged.
    ## 
    if p.hasInput():
        p.nextImpl()

proc nextAndGet*(p: var OptParser): lent CmdArg =
    ## Calls `p.next` and returns the current processed `CmdArg`
    ## 
    p.next()
    p.current

func remainingArgs*(p: OptParser): seq[string] =
    ## Gets a sequence of the arguments that have not been parsed yet. Useful
    ## if a `cakStopParsing` argument was encountered.
    ## 
    p.input[p.pos..^1]

iterator getopt*(p: var OptParser): lent CmdArg =
    ## Convenience iterator that iterates over all arguments in the given
    ## `OptParser<#OptParser>`_.
    while p.hasInput():
        p.nextImpl()
        yield p.current
