import dflat;

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
    clrhost = CLRHost(getcwd(),"foo",
                     [
                        TRUSTED_PLATFORM_ASSEMBLIES :
                            pathcat(TrustedPlatformAssembliesFiles(), path~"cs.dll"),
                        APP_PATHS : path,
                        APP_NI_PATHS : path,
                        NATIVE_DLL_SEARCH_DIRECTORIES : path,
                        SYSTEM_GC_SERVER : "false",
                        SYSTEM_GLOBALISATION_INVARIANT : "false"
                     ]);

    writeln("clrhost = ",clrhost);

    auto a = new CLRWrapper!ManLib;
    {
        import std.string : fromStringz;
        auto b = a.Bootstrap();
        writeln(b.fromStringz);
    }
    clrhost.shutdown();
}

