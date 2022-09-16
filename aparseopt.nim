# aparseopt - another/alternate parseopt
# API-incompatible alternative for std/parseopt, named as such to avoid
# conflicts with parseopt2 (deprecated) and parseopt3 (from cligen)

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
        cakArgument
        cakShortFlag
        cakLongFlag
        cakShortOption
        cakLongOption
        cakStopParsing

    CmdArg* = object
        kind*: CmdArgKind
        key*: string
        val*: string

    OptParser* = object
        ## API-incompatible alternative to std/parseopt's OptParser with the
        ## following changes:
        ##  - no value options are known as flags
        ##  - recognizes flags and option arguments
        ##  - option values can either be delimited with ':' or '=', or can
        ##    be the next argument in the command line
        ##    ie "-a out", "-a:out", "-a=out" and "-aout" are all equivalent,
        ##    and "--long:out", "--long=out", "--long out" are all equivalent
        ##  - allows for short name options without a delimiter, 
        ##    ie "-otest" is the equivalent to "-o test" or "-o:test"
        ##  - shortNoVal and longNoVal renamed to shortFlags and longFlags, respectively.
        ##    longFlags is now a CritBitTree[void] instead of seq[string]
        ##  - shortFlags and longFlags can be changed mid-parse, which makes
        ##    implementing "git" like subcommands easier.
        ##  - "-" is parsed as an argument
        ## 
        ## While this object shares the same name as parseopt's, note that it
        ## does not use the exact same API
        ## 
        pos: int
        input: seq[string]
        current: CmdArg
        shortFlagPos: int
        shortFlags*: set[char]
        longFlags*: CritBitTree[void]


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
    _.init(
        block:
            if cmd.len == 0:
                commandLineParams()
            else:
                cmd.parseCmdLine()
        , shortFlags, longFlags
    )

func pos*(p: OptParser): int =
    p.pos

proc `pos=`*(p: var OptParser, pos: int) =
    doAssert pos in 0..p.input.len-1, "cannot set position outside bounds of input"
    p.pos = pos
    p.shortFlagPos = 0

func current*(p: OptParser): lent CmdArg =
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
    p.hasInput()

proc next*(p: var OptParser) =
    if p.hasInput():
        p.nextImpl()

proc nextAndGet*(p: var OptParser): lent CmdArg =
    p.next()
    p.current

func remainingArgs*(p: OptParser): seq[string] =
    p.input[p.pos..^1]

iterator getopt*(p: var OptParser): lent CmdArg =
    while p.hasInput():
        p.nextImpl()
        yield p.current
