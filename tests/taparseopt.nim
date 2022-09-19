
import aparseopt
import std/unittest

proc optParserTest(
    cmd: string,
    shortFlags: set[char] = {},
    longFlags: sink seq[string] = @[]
): seq[CmdArg] =
    var p = OptParser.init(cmd, shortFlags, longFlags)
    for arg in p.getopt:
        result.add(arg)

func a(kind: CmdArgKind, key, val = ""): CmdArg =
    CmdArg(kind: kind, key: key, val: val)


test "short flag":
    check:
        optParserTest("-a", {'a'}) == [a(cakShortFlag, "a")]

test "short flag bundle":
    check:
        optParserTest("-abcd -e", {'a', 'b', 'c', 'd', 'e'}) == [
            a(cakShortFlag, "a"),
            a(cakShortFlag, "b"),
            a(cakShortFlag, "c"),
            a(cakShortFlag, "d"),
            a(cakShortFlag, "e")
        ]

const shortOptionExpected = [
    a(cakShortOption, "a", "3"),
    a(cakShortOption, "b", "test")
]

test "short option -oval":
    check:
        optParserTest("-a3 -btest") == shortOptionExpected

test "short option -o val":
    check:
        optParserTest("-a 3 -b test") == shortOptionExpected

test "short option -o:val -o=val":
    check:
        optParserTest("-a:3 -b:test") == shortOptionExpected
        optParserTest("-a=3 -b=test") == shortOptionExpected

test "long flag":
    check:
        optParserTest("--long-flag", {}, @["long-flag"]) == [
            a(cakLongFlag, "long-flag")
        ]

const longOptionExpected = [
    a(cakLongOption, "long-option", "3")
]

test "long option --long-option val":
    check:
        optParserTest("--long-option 3") == longOptionExpected

test "long option --long-option:val --long-option=val":
    check:
        optParserTest("--long-option:3") == longOptionExpected
        optParserTest("--long-option=3") == longOptionExpected

test "options missing a val":
    check:
        optParserTest("-o") == [a(cakShortOption, "o", "")]
        optParserTest("-o: barf") == [
            a(cakShortOption, "o", ""),
            a(cakArgument, "", "barf")
        ]
        optParserTest("--output") == [a(cakLongOption, "output", "")]
        optParserTest("--output: barf") == [
            a(cakLongOption, "output", ""),
            a(cakArgument, "", "barf")
        ]

test "- and --":
    var p = OptParser.init("-a - -- -these --are -now --arguments--", {'a'})
    check:
        p.hasNext()
        p.nextAndGet() == a(cakShortFlag, "a")
        p.hasNext()
        p.nextAndGet() == a(cakArgument, "", "-")
        p.hasNext()
        p.nextAndGet() == a(cakStopParsing)
        p.remainingArgs() == ["-these", "--are", "-now", "--arguments--"]

test "subcommand example":

    var p = OptParser.init("--verbose -p /tmp list -lh docs", {}, @["verbose"])

    check:
        p.nextAndGet() == a(cakLongFlag, "verbose")
        p.nextAndGet() == a(cakShortOption, "p", "/tmp")
        p.nextAndGet() == a(cakArgument, "", "list")

    # the subcommand is "list", update the parser for list's shortFlags and longFlags
    p.shortFlags = {'l', 'h'}
    p.longFlags.reset()

    check:
        p.nextAndGet() == a(cakShortFlag, "l")
        p.nextAndGet() == a(cakShortFlag, "h")
        p.nextAndGet() == a(cakArgument, "", "docs")
        p.hasNext() == false

test "spaces after delimiters":
    check:
        optParserTest("-o: val") == [
            a(cakShortOption, "o", ""),
            a(cakArgument, "", "val")   # val is parsed as an argument
        ]
        optParserTest("\"-o: val\"") == [
            a(cakShortOption, "o", " val") # note the space before val
        ]

test "delimiter as value":
    check:
        optParserTest("-d::") == [a(cakShortOption, "d", ":")]
        optParserTest("-d:=") == [a(cakShortOption, "d", "=")]
        optParserTest("-d=:") == [a(cakShortOption, "d", ":")]
        optParserTest("-d==") == [a(cakShortOption, "d", "=")]
        optParserTest("-d :") == [a(cakShortOption, "d", ":")]
        optParserTest("-d =") == [a(cakShortOption, "d", "=")]
        optParserTest("--delim :") == [a(cakLongOption, "delim", ":")]
        optParserTest("--delim =") == [a(cakLongOption, "delim", "=")]
        optParserTest("--delim::") == [a(cakLongOption, "delim", ":")]
        optParserTest("--delim:=") == [a(cakLongOption, "delim", "=")]
        optParserTest("--delim=:") == [a(cakLongOption, "delim", ":")]
        optParserTest("--delim==") == [a(cakLongOption, "delim", "=")]
        
