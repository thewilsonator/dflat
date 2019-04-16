import dflat.wrap;
import dflat.bind;
import dflat.host;

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
    string path = getcwd()~"/cs/bin/Debug/netstandard2.0/";
    string ep = thisExePath();
    clrhost = CLRHost(getcwd(),"foo",
                     [
                        TRUSTED_PLATFORM_ASSEMBLIES : TrustedPlatformAssembliesFiles() ~":"~path~"cs.dll",
                        APP_PATHS : path,
                        APP_NI_PATHS : path,
                        NATIVE_DLL_SEARCH_DIRECTORIES : path,
                        SYSTEM_GC_SERVER : "false",
                        SYSTEM_GLOBALISATION_INVARIANT : "false"
                     ]);
    writeln("clrhost= ",clrhost);
    auto a = new CLRWrapper!ManLib;
    {
        auto b = a.Bootstrap();
        writeln(b);
    }
    clrhost.shutdown();
}

