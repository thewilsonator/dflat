import std.process;
import std.format;
import std.stdio;
import std.algorithm : filter, canFind;
import std.string : lineSplitter, stripRight;
import std.file;
import std.path;
import std.array;
import std.uni;

auto monoTool(string monoDir, string toolName)
{
    version (Windows)
        toolName = toolName ~ ".bat";
    return buildPath(monoDir, "bin", toolName);
}

auto tryExec(scope const(char[])[] args)
{
    writefln("[EXEC] %s", escapeShellCommand(args));
    const result = execute(args);
    writeln(result.output.stripRight);
    if (result.status != 0)
        writefln("Error: last command failed with exit code %s", result.status);
    return result;
}
auto exec(scope const(char[])[] args)
{
    const result = tryExec(args);
    if (result.status != 0)
        throw new AlreadyReportedException();
    return result.output;
}

auto repoPath(T...)(T args)
{
    return __FILE_FULL_PATH__.dirName.dirName.buildPath(args);
}

class AlreadyReportedException : Exception { this() { super("error already reported"); } }

void usage()
{
    writefln("Usage: main <mono-dir> <cecil-dir> <derelict-util-dir> [<d-compiler>]");
}

int main(string[] args)
{
    try { return main2(args); }
    catch (AlreadyReportedException) { return 1; }
}
int main2(string[] args)
{
    args = args[1 .. $];
    if (args.length == 0)
    {
        usage();
        return 1;
    }

    if (args.length < 3)
    {
        writefln("Error: not enough command-line arguments");
        return 1;
    }
    const monoDir  = args[0];
    const cecilDir = args[1];
    const derelictUtilDir = args[2];
    const dcompiler = which(args.length >= 4 ? args[3] : "dmd");

    const cscExe = monoTool(monoDir, "csc");
    if (!cscExe.exists())
    {
        writefln("Error: invalid mono dir '%s', '%s' does not exist", monoDir, cscExe);
        return 1;
    }

    // TODO: generate a project file for the GenerateStaticMethodsCecil tool
    //       write another tool for generating projects
    const monoCecilDll = buildPath(cecilDir, "net40", "Mono.Cecil.dll");
    const csreflectExe = repoPath("test", "csreflect.exe");
    exec([
              cscExe,
              "/reference:Mono.CompilerServices.SymbolWriter.dll",
              //"/reference:" ~ buildPath(cecilDir, "net_4_0_Debug", "Mono.Cecil.dll"),
              "/reference:" ~ monoCecilDll,
              repoPath("csreflect", "GenerateStaticMethodsCecil.cs"),
              "/out:" ~ csreflectExe
    ]);
    // Copy the monoCecilDll to the same output directory so csreflect can find it at runtime
    copy(monoCecilDll, csreflectExe.dirName.buildPath(monoCecilDll.baseName));

    runtimeConfigJson(cecilDir).writeTo(repoPath("test", "csreflect.runtimeconfig.json"));
    depsJson(cecilDir,monoDir).writeTo(repoPath("test", "csreflect.deps.json"));


    int testEntries = 0;
    int testsPassed = 0;
    const unitTestDir = repoPath("test", "unit");
    foreach(d; dirEntries(unitTestDir, SpanMode.shallow).filter!(d=>d.isDir))
    {
        testEntries++;
        const name = d.name.baseName;
        writeln("-------------------------------------------------");
        writefln("Executing Test '%s'", name);
        writeln("-------------------------------------------------");
        const filePrefix = buildPath(d.name, name);
        const testDll = filePrefix ~ ".dll";

        //Compile the C# source - generate foo.dll
        if (tryExec([cscExe, "/t:library", filePrefix ~ ".cs","/out:" ~ testDll]).status)
            continue;

        //Reflect on generated .dll - generate foostatic.dll and foo.d
        string[] dotNetArgs;
        version (Windows) { } else {
            dotNetArgs = ["dotnet"];
        }
        if (tryExec(dotNetArgs ~ [
                  csreflectExe.absolutePath,
                  name,
                  unitTestDir, // input  dir
                  d.name ~ "/" // output dir
                  ]).status)
            continue;
        //Compile foo.d testfoo.d

        string[] extraDCompilerArgs;
        version (Windows) {
            extraDCompilerArgs = ["ole32.lib"];
        }
        if(tryExec([dcompiler,
              "-g", "-debug",
              "-I" ~ repoPath("source"),
              "-I" ~ absolutePath(derelictUtilDir),
              buildPath(d.name, cast(char)name[0].toLower() ~ name[1 .. $ ]~ ".d"),
              buildPath(unitTestDir, name, "test" ~ name ~ ".d"),
              "-i",
              //"-o-",
              "-of=" ~ name
             ] ~ extraDCompilerArgs).status)
            continue;
        writeln("Executing test ", name);
        if (tryExec(["./"~name]).status)
        {
            writeln("Test ", name, " Failed");
            //Disassemble the .dll's
            // don't use -out= it doens't appear to work
            const ikdasmExe = monoTool(monoDir, "ikdasm");
            tryExec([ikdasmExe, testDll,      ]).output.writeTo(d.name~".il");
            tryExec([ikdasmExe, filePrefix ~ "static.dll" ]).output.writeTo(d.name~"static.il");
            continue;
        }
        testsPassed++;
    }
    writeln("-------------------------------------------------");
    if (testEntries != testsPassed)
    {
        writefln("%s test(s) PASSED", testsPassed);
        writefln("%s test(s) FAILED", (testEntries - testsPassed));
        return 1; // fail
    }
    writefln("Success, all %s test(s) passed", testsPassed);
    return 0;
}

void writeTo(string content, string fname)
{
    auto f = File(fname, "w");
    f.write(content);
    f.close();
}
string runtimeConfigJson(string cecilDir)
{
    return
q{
{
    "runtimeOptions":
    {
        "tfm": "netcoreapp2.1",
        "framework":
        {
            "name": "Microsoft.NETCore.App",
            "version": "2.1.0"
        },
        "additionalProbingPaths":
        [
         "%s"
        ]
    }
}
}.format(cecilDir);
}

string depsJson(string cecilDir, string monoDir)
{
    return
q{
{
    "runtimeTarget": {
        "name": ".NETCoreApp,Version=v2.0"
    },
    "targets": {
        ".NETCoreApp,Version=v2.0": {
            "Mono.Cecil/10.0.3": {
                "runtime": {
                    "%snet_4_0_Debug/Mono.Cecil.dll": {
                        "assemblyVersion": "10.0.0.0",
                        "fileVersion": "10.0.3.21018"
                    }
                }
            },
            "Mono.CompilerServices.SymbolWriter/10.0.3": {
                "runtime": {
                    "%slib/mono/4.7.2-api/Mono.CompilerServices.SymbolWriter.dll": {
                        "assemblyVersion": "10.0.0.0",
                        "fileVersion": "10.0.3.21018"
                    }
                }
            }
        }
    },
    "libraries": {
        "Mono.Cecil/10.0.3": {
            "type": "package",
            "serviceable": false,
            "sha512": ""
        }
    }
}
}.format(cecilDir,monoDir);
}

auto which(string program)
{
    if (program.canFind("/", "\\"))
        return program;
    version(Windows)
        return ["where", program].execute.output.lineSplitter.front;
    else
        return ["which", program].execute.output;
}
