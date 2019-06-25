import dflat;

import class1;

void main()
{
    import std.stdio;
    CLRCore.load();
    import std.file, std.path;
    auto cwd = getcwd() ~ dirSeparator;
    string ep = thisExePath();

    auto tpas = pathcat(TrustedPlatformAssembliesFiles(),
                        buildPath([cwd, "test", "Class1", "Class1static.dll"]),
                        buildPath([cwd, "test", "Class1", "Class1.dll"]));
    //writeln(tpas);
    clrhost = CLRHost(getcwd(),"foo",
        [
            TRUSTED_PLATFORM_ASSEMBLIES : tpas,
            APP_PATHS : getcwd(),
            APP_NI_PATHS : getcwd(),
            NATIVE_DLL_SEARCH_DIRECTORIES : getcwd(),
            SYSTEM_GC_SERVER : "false",
            SYSTEM_GLOBALISATION_INVARIANT : "false"
        ]);

    {
        import std.string : fromStringz;
        writeln("here");
        Class1 a;
        writeln("`a` raw pointer: ", a._raw.o.p);
        a = Class1.make(42);
        writeln("`a` raw pointer: ", a._raw.o.p);

        auto s = a.toString();
        writeln(s.ptr.fromStringz);

        scope(exit) a.unpin();
    }

    clrhost.shutdown();
}

