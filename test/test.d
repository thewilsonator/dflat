import dflat;

import alglibnet2;

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
                        buildPath([cwd, "alglibnet2.dll"]),
                        buildPath([cwd, "alglibnet2static.dll"]));
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

    {
        auto x = new CLRWrapper!Math;
        writeln(x.Pow(2.0,4.0));
    }
    {
        import core.memory : GC;
        // Avoid the GC stopping a running C# thread.
        GC.disable; scope(exit) GC.enable;
        import dflat.types;
        alias func = double function(double,double);
        auto f = cast(func)(clrhost.create_delegate("alglibnet2",
                                                    "alglib",
                                                    "chisquarecdistribution"));
        writeln("here345t8765" ,f(1.0,1.0));
    }
    {
        auto a = new CLRWrapper!xparams;
        writeln("here");
        import std.string : fromStringz;
        auto b = a.make(0); // fails
        writeln("here2");
        scope(exit) a.unpin(b);
        auto c = a.ToString(b);
        writeln(c.ptr.fromStringz);
    }
    clrhost.shutdown();
}

