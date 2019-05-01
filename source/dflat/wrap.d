module dflat.wrap;

import std.traits; // hasUDA getUDA
import std.meta : AliasSeq;
import dflat.host;
//UDA
struct DLL
{
    string dll;
}

// ditto
struct Entrypoint
{
    string entrypoint;
}

template how(C,alias fun)
{
    import std.traits;
    import std.string : format;
    enum string dll = getUDAs!(C,DLL)[0].dll;
    enum how = q{
        import %s;
        alias func = %s function%s;
        import core.gc;
        // Avoid the GC stopping a running C# thread.
        GC.disable; scope(exit) GC.enable;

        auto f = cast(func)(clrhost.create_delegate("%s",
        %s,
        %s));
        return f();
    }.format(
        moduleName!C,

        /*possibly need to use partially qualified name if this gets too slow*/
        fullyQualifiedName!(ReturnType!(fun)),

        Parameters!(fun).stringof,
        dll,
        __traits(identifier, C).stringof,
        __traits(identifier, fun).stringof);
}

template CLRWrapper(C) if (getUDAs!(C,DLL).length == 1)
{
    alias CLRWrapper = AutoImplement!(C, how);
}

//Taken from std.typecons because of mixin scope issues

final class AutoImplement(Base, alias how, alias what = isAbstractFunction) : Base
if (!is(how == class))
{
    private alias autoImplement_helper_ =
    AutoImplement_Helper!("autoImplement_helper_", "Base", Base, typeof(this), how, what);
    mixin(autoImplement_helper_.code);
}

/// ditto
final class AutoImplement(
Interface, BaseClass, alias how,
alias what = isAbstractFunction) : BaseClass, Interface
if (is(Interface == interface) && is(BaseClass == class))
{
    private alias autoImplement_helper_ = AutoImplement_Helper!(
    "autoImplement_helper_", "Interface", Interface, typeof(this), how, what);
    mixin(autoImplement_helper_.code);
}
private template AutoImplement_Helper(string myName, string baseName,
Base, Self, alias generateMethodBody, alias cherrypickMethod)
{
    private static:
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Internal stuffs
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    
    // Returns function overload sets in the class C, filtered with pred.
    template enumerateOverloads(C, alias pred)
    {
        template Impl(names...)
        {
            import std.meta : Filter;
            static if (names.length > 0)
            {
                alias methods = Filter!(pred, MemberFunctionsTuple!(C, names[0]));
                alias next = Impl!(names[1 .. $]);
                
                static if (methods.length > 0)
                    alias Impl = AliasSeq!(OverloadSet!(names[0], methods), next);
                else
                    alias Impl = next;
            }
            else
                alias Impl = AliasSeq!();
        }
        
        alias enumerateOverloads = Impl!(__traits(allMembers, C));
    }
    
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Target functions
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    
    // Add a non-final check to the cherrypickMethod.
    enum bool canonicalPicker(fun.../+[BUG 4217]+/) =
                    !__traits(isFinalFunction, fun[0]) && cherrypickMethod!(fun);
    
    /*
     * A tuple of overload sets, each item of which consists of functions to be
     * implemented by the generated code.
     */
    alias targetOverloadSets = enumerateOverloads!(Base, canonicalPicker);
    
    /*
     * Super class of this AutoImplement instance
     */
    alias Super = BaseTypeTuple!(Self)[0];
    static assert(is(Super == class));
    static assert(is(Base == interface) || is(Super == Base));
    
    /*
     * A tuple of the super class' constructors.  Used for forwarding
     * constructor calls.
     */
    static if (__traits(hasMember, Super, "__ctor"))
        alias ctorOverloadSet = OverloadSet!("__ctor", __traits(getOverloads, Super, "__ctor"));
    else
        alias ctorOverloadSet = OverloadSet!("__ctor"); // empty
    
    template INTERNAL_FUNCINFO_ID(string name, size_t i)
    {
        import std.format : format;
        
        enum string INTERNAL_FUNCINFO_ID = format("F_%s_%s", name, i);
    }
    
    /*
     * Insert FuncInfo instances about all the target functions here.  This
     * enables the generated code to access type information via, for example,
     * "autoImplement_helper_.F_foo_1".
     */
    template populate(overloads...)
    {
        static if (overloads.length > 0)
        {
            mixin populate!(overloads[0].name, overloads[0].contents);
            mixin populate!(overloads[1 .. $]);
        }
    }
    template populate(string name, methods...)
    {
        static if (methods.length > 0)
        {
            mixin populate!(name, methods[0 .. $ - 1]);
            //
            alias target = methods[$ - 1];
            enum ith = methods.length - 1;
            mixin("alias " ~ INTERNAL_FUNCINFO_ID!(name, ith) ~ " = FuncInfo!target;");
        }
    }
    
    public mixin populate!(targetOverloadSets);
    public mixin populate!(  ctorOverloadSet );
    template CommonGeneratingPolicy()
    {
        // base class identifier which generated code should use
        enum string BASE_CLASS_ID = baseName;
        
        // FuncInfo instance identifier which generated code should use
        template FUNCINFO_ID(string name, size_t i)
        {
            enum string FUNCINFO_ID =
            myName ~ "." ~ INTERNAL_FUNCINFO_ID!(name, i);
        }
    }
    
    /* Policy configurations for generating constructors. */
    template ConstructorGeneratingPolicy()
    {
        mixin CommonGeneratingPolicy;
        
        /* Generates constructor body.  Just forward to the base class' one. */
        string generateFunctionBody(ctor.../+[BUG 4217]+/)() @property
        {
            enum varstyle = variadicFunctionStyle!(typeof(&ctor[0]));
            
            static if (varstyle & (Variadic.c | Variadic.d))
            {
                // the argptr-forwarding problem
                //pragma(msg, "Warning: AutoImplement!(", Base, ") ",
                //        "ignored variadic arguments to the constructor ",
                //        FunctionTypeOf!(typeof(&ctor[0])) );
            }
            return "super(args);";
        }
    }
    
    /* Policy configurations for genearting target methods. */
    template MethodGeneratingPolicy()
    {
        mixin CommonGeneratingPolicy;
        
        /* Geneartes method body. */
        string generateFunctionBody(func.../+[BUG 4217]+/)() @property
        {
            return generateMethodBody!(Base, func); // given
        }
    }
    alias ConstructorGenerator = MemberFunctionGenerator!(ConstructorGeneratingPolicy!());
    alias MethodGenerator      = MemberFunctionGenerator!(MethodGeneratingPolicy!());
    
    public enum string code =
    ConstructorGenerator.generateCode!(  ctorOverloadSet ) ~ "\n" ~
    MethodGenerator.generateCode!(targetOverloadSets);
}
package template OverloadSet(string nam, T...)
{
    enum string name = nam;
    alias contents = T;
}

package template FuncInfo(alias func, /+[BUG 4217 ?]+/ T = typeof(&func))
{
    alias RT = ReturnType!T;
    alias PT = Parameters!T;
}
package template FuncInfo(Func)
{
    alias RT = ReturnType!Func;
    alias PT = Parameters!Func;
}


package template MemberFunctionGenerator(alias Policy)
{
    private static:
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Internal stuffs
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    import std.format;
    
    enum CONSTRUCTOR_NAME = "__ctor";
    
    // true if functions are derived from a base class
    enum WITH_BASE_CLASS = __traits(hasMember, Policy, "BASE_CLASS_ID");
    
    // true if functions are specified as types, not symbols
    enum WITHOUT_SYMBOL = __traits(hasMember, Policy, "WITHOUT_SYMBOL");
    
    // preferred identifier for i-th parameter variable
    static if (__traits(hasMember, Policy, "PARAMETER_VARIABLE_ID"))
    {
        alias PARAMETER_VARIABLE_ID = Policy.PARAMETER_VARIABLE_ID;
    }
    else
    {
        enum string PARAMETER_VARIABLE_ID(size_t i) = format("a%s", i);
        // default: a0, a1, ...
    }
    
    // Returns a tuple consisting of 0,1,2,...,n-1.  For static foreach.
    template CountUp(size_t n)
    {
        static if (n > 0)
            alias CountUp = AliasSeq!(CountUp!(n - 1), n - 1);
        else
            alias CountUp = AliasSeq!();
    }
    
    
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    // Code generator
    //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::://
    
    /*
     * Runs through all the target overload sets and generates D code which
     * implements all the functions in the overload sets.
     */
    public string generateCode(overloads...)() @property
    {
        string code = "";
        
        // run through all the overload sets
        foreach (i_; CountUp!(0 + overloads.length)) // workaround
        {
            enum i = 0 + i_; // workaround
            alias oset = overloads[i];
            
            code ~= generateCodeForOverloadSet!(oset);
            
            static if (WITH_BASE_CLASS && oset.name != CONSTRUCTOR_NAME)
            {
                // The generated function declarations may hide existing ones
                // in the base class (cf. HiddenFuncError), so we put an alias
                // declaration here to reveal possible hidden functions.
                code ~= format("alias %s = %s.%s;\n",
                                oset.name,
                                Policy.BASE_CLASS_ID, // [BUG 2540] super.
                                oset.name);
            }
        }
        return code;
    }
    
    // handle each overload set
    private string generateCodeForOverloadSet(alias oset)() @property
    {
        string code = "";
        
        foreach (i_; CountUp!(0 + oset.contents.length)) // workaround
        {
            enum i = 0 + i_; // workaround
            code ~= generateFunction!(
            Policy.FUNCINFO_ID!(oset.name, i), oset.name,
            oset.contents[i]) ~ "\n";
        }
        return code;
    }
    
    /*
     * Returns D code which implements the function func.  This function
     * actually generates only the declarator part; the function body part is
     * generated by the functionGenerator() policy.
     */
    public string generateFunction(
    string myFuncInfo, string name, func... )() @property
    {
        import std.format : format;
        
        enum isCtor = (name == CONSTRUCTOR_NAME);
        
        string code; // the result
        
        auto paramsRes = generateParameters!(myFuncInfo, func)();
        code ~= paramsRes.imports;
        
        /*** Function Declarator ***/
        {
            alias Func = FunctionTypeOf!(func);
            alias FA = FunctionAttribute;
            enum atts     = functionAttributes!(func);
            enum realName = isCtor ? "this" : name;
            
            // FIXME?? Make it so that these aren't CTFE funcs any more, since
            // Format is deprecated, and format works at compile time?
            /* Made them CTFE funcs just for the sake of Format!(...) */
            
            // return type with optional "ref"
            static string make_returnType()
            {
                string rtype = "";
                
                if (!isCtor)
                {
                    if (atts & FA.ref_) rtype ~= "ref ";
                    rtype ~= myFuncInfo ~ ".RT";
                }
                return rtype;
            }
            enum returnType = make_returnType();
            
            // function attributes attached after declaration
            static string make_postAtts()
            {
                string poatts = "";
                if (atts & FA.pure_   ) poatts ~= " pure";
                if (atts & FA.nothrow_) poatts ~= " nothrow";
                if (atts & FA.property) poatts ~= " @property";
                if (atts & FA.safe    ) poatts ~= " @safe";
                if (atts & FA.trusted ) poatts ~= " @trusted";
                return poatts;
            }
            enum postAtts = make_postAtts();
            
            // function storage class
            static string make_storageClass()
            {
                string postc = "";
                if (is(Func ==    shared)) postc ~= " shared";
                if (is(Func ==     const)) postc ~= " const";
                if (is(Func ==     inout)) postc ~= " inout";
                if (is(Func == immutable)) postc ~= " immutable";
                return postc;
            }
            enum storageClass = make_storageClass();
            
            //
            if (__traits(isVirtualMethod, func))
            code ~= "override ";
            code ~= format("extern(%s) %s %s(%s) %s %s\n",
            functionLinkage!(func),
            returnType,
            realName,
            paramsRes.params,
            postAtts, storageClass );
        }
        
        /*** Function Body ***/
        code ~= "{\n";
        {
            enum nparams = Parameters!(func).length;
            
            /* Declare keywords: args, self and parent. */
            string preamble;
            
            preamble ~= "alias args = AliasSeq!(" ~ enumerateParameters!(nparams) ~ ");\n";
            if (!isCtor)
            {
                preamble ~= "alias self = " ~ name ~ ";\n";
                if (WITH_BASE_CLASS && !__traits(isAbstractFunction, func))
                preamble ~= `alias parent = __traits(getMember, super, "` ~ name ~ `");`;
            }
            
            // Function body
            static if (WITHOUT_SYMBOL)
            enum fbody = Policy.generateFunctionBody!(name, func);
            else
            enum fbody = Policy.generateFunctionBody!(func);
            
            code ~= preamble;
            code ~= fbody;
        }
        code ~= "}";
        
        return code;
    }
    
    /*
     * Returns D code which declares function parameters,
     * and optionally any imports (e.g. core.vararg)
     * "ref int a0, real a1, ..."
     */
    static struct GenParams { string imports, params; }
    private GenParams generateParameters(string myFuncInfo, func...)()
    {
        alias STC = ParameterStorageClass;
        alias stcs = ParameterStorageClassTuple!(func);
        enum nparams = stcs.length;
        
        string imports = ""; // any imports required
        string params = ""; // parameters
        
        foreach (i, stc; stcs)
        {
            if (i > 0) params ~= ", ";
            
            // Parameter storage classes.
            if (stc & STC.scope_) params ~= "scope ";
            if (stc & STC.out_  ) params ~= "out ";
            if (stc & STC.ref_  ) params ~= "ref ";
            if (stc & STC.lazy_ ) params ~= "lazy ";
            
            // Take parameter type from the FuncInfo.
            params ~= format("%s.PT[%s]", myFuncInfo, i);
            
            // Declare a parameter variable.
            params ~= " " ~ PARAMETER_VARIABLE_ID!(i);
        }
        
        // Add some ellipsis part if needed.
        auto style = variadicFunctionStyle!(func);
        final switch (style)
        {
            case Variadic.no:
            break;
            
            case Variadic.c, Variadic.d:
            imports ~= "import core.vararg;\n";
            // (...) or (a, b, ...)
            params ~= (nparams == 0) ? "..." : ", ...";
            break;
            
            case Variadic.typesafe:
            params ~= " ...";
            break;
        }
        
        return typeof(return)(imports, params);
    }
    
    // Returns D code which enumerates n parameter variables using comma as the
    // separator.  "a0, a1, a2, a3"
    private string enumerateParameters(size_t n)() @property
    {
        string params = "";
        
        foreach (i_; CountUp!(n))
        {
            enum i = 0 + i_; // workaround
            if (i > 0) params ~= ", ";
            params ~= PARAMETER_VARIABLE_ID!(i);
        }
        return params;
    }
}


