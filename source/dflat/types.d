module dflat.types;


// We "Marshall" C# object types as the GCHandle void*
struct DotNetObject { void * p; }
// For objects
struct Instance(string fullClsName)
{
    DotNetObject o;
    alias o this;
}

// C# string is marshalled as this by default
struct CLRAllocatedCString
{
    char* ptr;

    ~this()
    {
        if (ptr)
        {
            version(Windows)
            {
                import core.sys.windows.objbase : CoTaskMemFree;
                CoTaskMemFree(ptr);
            }
            else
            {
                import core.stdc.stdlib : free;
                free(ptr);
            }
        }
    }

    char* wipeAndKeep()
    {
        char* tmp = ptr;
        ptr = null;
        return tmp;
    }
}

// https://docs.microsoft.com/en-us/windows/desktop/api/oaidl/ns-oaidl-tagsafearraybound

struct SafeArrayBound
{
    uint cElements;
    int  lLbound;
}

// https://msdn.microsoft.com/en-us/magazine/mt778923.aspx
// Managed array descriptor
struct SafeArrayDescriptor
{
    ushort            cDims;
    ushort            fFeatures;
    uint              cbElements;
    uint              cLocks;
    void*                pvData;
    union Bound
    {
        SafeArrayBound[1] rgsabound1;
        SafeArrayBound[0] rgsabound0;
    }
    Bound bound;
}

struct SafeArray(T, int dim)
{
    SafeArrayDescriptor * p;

    static if (dim == 1)
    this( T[] arr)
    {
        SafeArrayBound saBound;
        saBound.lLbound = 0;
        saBound.cElements = arr.length;
        p = SafeArrayCreate(T2VT!T,1,&saBound);
    }
}

// https://docs.microsoft.com/en-us/windows/desktop/api/wtypes/ne-wtypes-varenum
private enum VARENUM {
    EMPTY,
    NULL,
    I2,
    I4,
    R4,
    R8,
    CY,
    DATE,
    BSTR,
    DISPATCH,
    ERROR,
    BOOL,
    VARIANT,
    UNKNOWN,
    DECIMAL,
    I1,
    UI1,
    UI2,
    UI4,
    I8,
    UI8,
    INT,
    UINT,
    VOID,
    HRESULT,
    PTR,
    SAFEARRAY,
    CARRAY,
    USERDEFINED,
    LPSTR,
    LPWSTR,
    RECORD,
    INT_PTR,
    UINT_PTR,
    FILETIME,
    BLOB,
    STREAM,
    STORAGE,
    STREAMED_OBJECT,
    STORED_OBJECT,
    BLOB_OBJECT,
    CF,
    CLSID,
    VERSIONED_STREAM,
    BSTR_BLOB,
    VECTOR,
    ARRAY,
    BYREF,
    RESERVED,
    ILLEGAL,
    ILLEGALMASKED,
    TYPEMASK
}

private template T2VT(T)
{
    static if (T ==  typeof(null))
        enum T2VT = VARENUM.NULL;
    else static if(is(T == int))
        enum T2VT = VARENUM.I4;
    else static if (is(T == void))
        enum T2VT = VARENUM.VOID;
    else static if (is(T == double))
        enum T2VT = VARENUM.R8;
    else static if (is(T == struct))
        enum T2VT = VARENUM.USERDEFINED;
}
