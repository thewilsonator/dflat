import dflat;

@DLL("manlib")
abstract class ManLib
{
    abstract char* Bootstrap();
}

void main ()
{
    import std.stdio;
    CLRCore.load();
    import std.file;
    string path = getcwd()~"/test/manlib/bin/Debug/netstandard2.0/";
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

