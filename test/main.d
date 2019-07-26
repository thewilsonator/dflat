import std.process;
import std.format;
import std.stdio;
import std.algorithm : filter;
import std.file;
import std.path;
import std.array;
import std.uni;

auto exec(const(char[])[] args, int line = __LINE__)
{
    auto ret = execute(args);
    if (ret.status != 0)
        writeln(line, ":" ,args);
    return ret;
}
int main(string[] args)
{
    const monoDir  = args[1];
    const cecilDir = args[2];
    const derelictUtilDir = args[3];
    auto csreflect = exec([
              monoDir ~ "bin/csc",
              "/reference:Mono.CompilerServices.SymbolWriter.dll",
              "/reference:" ~ cecilDir ~ "net_4_0_Debug/Mono.Cecil.dll",
              "csreflect/GenerateStaticMethodsCecil.cs",
              "/out:test/csreflect.exe"
    ]);
    
    runtimeConfigJson(cecilDir).writeTo("test/csreflect.runtimeconfig.json");
    depsJson(cecilDir,monoDir).writeTo("test/csreflect.deps.json");

    if (csreflect.status != 0)
    {
        writeln("Building csreflect Failed:\n", csreflect.output);
        return 1;
    }
    
    int ret;
    enum UnitTestDir = "test/unit/";
    foreach(d; dirEntries(UnitTestDir, SpanMode.shallow).filter!(d=>d.isDir))
    {
        //Compile the C# source - generate foo.dll
        const name = d.name[UnitTestDir.length .. $];
        const file = d.name ~ "/" ~ name;
        if (exec([monoDir ~ "bin/csc", "/t:library", file ~ ".cs","/out:" ~ file~".dll"]).status)
            break;

        //Reflect on generated .dll - generate foostatic.dll and foo.d
        if (exec(["dotnet", asAbsolutePath("test/csreflect.exe").array, name, UnitTestDir]).status)
            break;
        
        //Compile foo.d testfoo.d
        const dcompiler = args.length == 5 ? args[4] : "dmd";

        if(exec([dcompiler,
              "-I" ~ asAbsolutePath("source").array,
              "-I" ~ asAbsolutePath(derelictUtilDir).array,
              d.name ~ "/" ~ cast(char)name[0].toLower() ~ name[1 .. $ ]~ ".d",
              UnitTestDir ~ name ~ "/test"~ name ~ ".d",
              "-i",
              //"-o-",
              "-of=" ~ name
             ]).status)
            break;
        writeln("Executing test ", name);
        auto pid = exec(["./"~name]);
        ret |= pid.status;
        if (pid.status != 0)
        {
            writeln("Test ", name, " Failed\n", pid.output);
            //Disassemble the .dll's
            const dasm = monoDir ~ "bin/ikdasm";
            // don't use -out= it doens't appear to work
            exec([dasm, file ~ ".dll",      ]).output.writeTo(d.name~".il");
            exec([dasm, file ~ "static.dll" ]).output.writeTo(d.name~"static.il");
        }
    }
    return ret;
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

