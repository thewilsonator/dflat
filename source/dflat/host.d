module dflat.host;

import dflat.bind;
enum : string
{
    // pathSeparator separated list of directories
    APP_PATHS = "APP_PATHS",
    //pathSeparator separated list of files. See TrustedPlatformAssembliesFiles
    TRUSTED_PLATFORM_ASSEMBLIES = "TRUSTED_PLATFORM_ASSEMBLIES",
    // pathSeparator separated list of directories
    APP_NI_PATHS = "APP_NI_PATHS",
    // pathSeparator separated list of directories
    NATIVE_DLL_SEARCH_DIRECTORIES = "NATIVE_DLL_SEARCH_DIRECTORIES",
    // boolean
    SYSTEM_GC_SERVER = "System.GC.Server",
    // boolean
    SYSTEM_GLOBALISATION_INVARIANT = "System.Globalization.Invariant",
}
import std.stdio;
private import std.path;
import std.file;
import std.algorithm;
import std.range;
string TrustedPlatformAssembliesFiles(string dir = dirName(dflat.bind.libNames))
{
    immutable exts = [
        "*.ni.dll", // Probe for .ni.dll first so that it's preferred
        "*.dll",    // if ni and il coexist in the same dir
        "*.ni.exe", // ditto
        "*.exe",
    ];
    import std.array;
    Appender!string ret;
    byte[string] asms;


    foreach(ex; exts)
    foreach(f;dirEntries(dir,ex, SpanMode.shallow))
    {
        if (!f.isFile) continue;

        if (f.name !in asms)
        {
            asms[f.name] = 1;
            //ret.put(dir);
            //ret.put(dirSeparator);
            ret.put(f.name);
            ret.put(pathSeparator);
        }
    }

    return ret.data[0 .. $-1]; // remove the last path sep
}

struct CLRHost
{
    private import std.string : toStringz;
    void* handle;
    uint domainId; // an isolation unit within a process
    this(string exePath,string name,string[string] props)
    {
        import std.algorithm : each, map;
        import std.array;
        import std.string;

        int len = cast(int)props.length;
        auto keys = props.keys.map!(toStringz).array;
        auto vals = props.values.map!(toStringz).array;

        auto err = coreclr_initialize(exePath.toStringz,
                           name.toStringz,
                           len,
                           keys.ptr,
                           vals.ptr,
                           &handle,
                           &domainId)
            ;
        if (err)
        {
            import std.stdio;
            writeln("coreclr_initialize error! err =",err);
            foreach(k,v;props)
                writeln(k,": ",v);
        }
    }
    void shutdown()
    {
        coreclr_shutdown(handle, domainId);
    }

    int shutdown_2()
    {
        int ret;
        coreclr_shutdown_2(handle, domainId, &ret);
        return ret;
    }

    /**
     * entryPointAssemblyName (CLR dynamic library or exectuable)
     * entryPointTypeName class name
     */
    void* create_delegate(string entryPointAssemblyName,
                          string entryPointTypeName,
                          string entryPointMethodName)
    {
        void* dg;

        auto err = coreclr_create_delegate(handle, domainId,
                                entryPointAssemblyName.toStringz,
                                entryPointTypeName.toStringz,
                                entryPointMethodName.toStringz,
                                &dg);
        if (err)
        {
            import std.stdio;
            writeln("create_delegate error! err =",err);
            writeln(entryPointAssemblyName);
            writeln(entryPointTypeName);
            writeln(entryPointMethodName);
        }
        return dg;
    }
}

__gshared CLRHost clrhost;
