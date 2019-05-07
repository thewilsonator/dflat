import dflat;

import ClassLibrary2;

@DLL("mscorlib") @NameSpace("System")
abstract class Math
{
    abstract double Pow (double x, double y);
}

void main ()
{
    import std.stdio;
    CLRCore.load();
    import std.file, std.path;
    auto cwd = getcwd() ~ dirSeparator;
    string ep = thisExePath();
    writeln("getcwd() = ",getcwd());
    auto tpas = pathcat(TrustedPlatformAssembliesFiles(),
                        buildPath([cwd, "test", "ClassLibrary2static.dll"]),
                        buildPath([cwd, "test", "ClassLibrary2.dll"]));
    writeln(tpas);
    clrhost = CLRHost(getcwd(),"foo",
        [
            TRUSTED_PLATFORM_ASSEMBLIES : tpas,
            APP_PATHS : getcwd(),
            APP_NI_PATHS : getcwd(),
            NATIVE_DLL_SEARCH_DIRECTORIES : getcwd(),
            SYSTEM_GC_SERVER : "false",
            SYSTEM_GLOBALISATION_INVARIANT : "false"
        ]);

    writeln("clrhost = ",clrhost);

    /*{
        auto x = new CLRWrapper!Math;
        writeln(x.Pow(2.0,4.0));
    }*/
    {
        auto a = new CLRWrapper!Class1;
        writeln("here");
        import std.string : fromStringz;
        auto b = a.make(0); // fails
        writeln("here2");
        scope(exit) a.unpin(b);
    }
    clrhost.shutdown();
}

