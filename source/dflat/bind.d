module dflat.bind;

import derelict.util.loader;

public
{
    import derelict.util.system;
    
    static if(Derelict_OS_Windows)
        enum libNames = `C:\Program Files (x86)\dotnet\shared\Microsoft.NETCore.App\3.1.0\coreclr.dll`;
    else static if (Derelict_OS_Mac)
        enum libNames = "/usr/local/share/dotnet/shared/Microsoft.NETCore.App/2.2.3/libcoreclr.dylib";
    else static if (Derelict_OS_Linux)
        enum libNames = "libcoreclr.so";
    else
        static assert(0, "Need to implement CoreCLR libNames for this operating system.");
}

alias da_coreclr_initialize = extern(C) int function(const char* exePath, const char* appDomainFriendlyName, int propertyCount, const char** propertyKeys, const char** propertyValues, void** hostHandle, uint* domainId);
alias da_coreclr_shutdown = extern(C) int function(void* hostHandle, uint domainId);
alias da_coreclr_shutdown_2 = extern(C) int function(void* hostHandle, uint domainId, int* latchedExitCode);
alias da_coreclr_create_delegate = extern(C) int function(void* hostHandle, uint domainId, const char* entryPointAssemblyName, const char* entryPointTypeName, const char* entryPointMethodName, void** dg);
alias da_coreclr_execute_assembly = extern(C) int function(void* hostHandle, uint domainId, int argc, const char** argv, const char* managedAssemblyPath, uint* exitCode);

__gshared
{
    da_coreclr_initialize coreclr_initialize;
    da_coreclr_shutdown coreclr_shutdown;
    da_coreclr_shutdown_2 coreclr_shutdown_2;
    da_coreclr_create_delegate coreclr_create_delegate;
    da_coreclr_execute_assembly coreclr_execute_assembly;
}
class CLRCoreLoader : SharedLibLoader
{
    protected
    {
        override void loadSymbols()
        {
            bindFunc(cast(void**)&coreclr_initialize, "coreclr_initialize");
            bindFunc(cast(void**)&coreclr_shutdown, "coreclr_shutdown");
            bindFunc(cast(void**)&coreclr_shutdown_2, "coreclr_shutdown_2");
            bindFunc(cast(void**)&coreclr_create_delegate, "coreclr_create_delegate");
            bindFunc(cast(void**)&coreclr_execute_assembly, "coreclr_execute_assembly");
        }
    }

    public
    {
        this()
        {
            super(libNames);
        }
    }
}

__gshared CLRCoreLoader CLRCore;

shared static this()
{
    CLRCore = new CLRCoreLoader();
}
