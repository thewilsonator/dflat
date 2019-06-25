using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

using Mono.Cecil;
using Mono.Cecil.Cil;
using Mono.CompilerServices.SymbolWriter;
using System.Reflection;

using System.IO;
using System.Runtime.InteropServices;

class CLRBuilder
{
    StreamWriter sw; // output .d file
    Type t;          // reflected upon type
    TypeDefinition tb;  // type under construction
    string fname;    // name of file
    private string idir;
    ModuleDefinition md;
    bool useCls;
    CLRBuilder(string name, string aidir)
    {
        fname = name;
        idir = aidir;
        sw = new StreamWriter(idir+ "/"+fname+"/"+fname.ToLower() + ".d", false, Encoding.UTF8);
        useCls = false;
    }
    static void Main(string[] args)
    {
        new CLRBuilder(args[0],args[1]).run();
    }
    
    static void log(string s)
    {
        System.Console.WriteLine(s);
        System.Console.Out.Flush();
    }
    void writeHeader()
    {
        sw.Write("module " + fname.ToLower() + ";\n");
        sw.Write("import dflat.wrap;\nimport dflat.types;\nimport dflat.host;\nimport core.memory : GC;\n");
        if (useCls)
        {
            sw.Write("@DLL(\"" + fname + "\")\n");
            sw.Write("{\n");
        }
    }

    void writeAggHdr()
    {
    	if (useCls)
    		sw.Write("abstract class ");
    	else
    		sw.Write("struct ");
        sw.Write(t.Name); sw.Write("\n{\n");
        if (!useCls)
        {
            sw.Write("    Instance!(\"" + t.Name +"\") _raw;\n    alias _raw this;\n\n");
        }
        sw.Write("    import core.memory : GC;\n");
    }

    void run()
    {
        writeHeader();
        var resolver = new DefaultAssemblyResolver();
        resolver.AddSearchDirectory(Directory.GetCurrentDirectory());
        md = ModuleDefinition.CreateModule(fname + "static",
                                               new ModuleParameters { Kind = ModuleKind.Dll, AssemblyResolver = resolver });

        // To avoid duplicately adding types
        HashSet<String> visitedTypes = new HashSet<String>();


        foreach (Type _ in Assembly.LoadFile(Path.GetFullPath(Path.Combine(idir, fname, fname + ".dll"))).GetExportedTypes())
        {
            t = _;
            // To avoid duplicately adding methods
            HashSet<String> visitedMethods = new HashSet<String>();
            //Assume that duplicates are identical (e.g. interface / class pairs)
            if (visitedTypes.Contains(t.Name)) continue;
            visitedTypes.Add(t.Name);
            //TODO: support namespaces
            writeAggHdr();
            tb = new TypeDefinition(t.Namespace,
                                    t.Name + "static",
                                    Mono.Cecil.TypeAttributes.Public,
                                    md.ImportReference(typeof(object)) /*base class*/);
            foreach (MemberInfo mi in t.GetMembers())
            {
                if (visitedMethods.Contains(mi.Name)) continue;
                visitedMethods.Add(mi.Name);
                // Sanity check:
                // If you think you are missing methods make sure they are public!
                // Console.WriteLine(mi.Name);
                if (mi.Name == "assert")
                    continue;

                if (mi.MemberType == MemberTypes.Method)
                    addMethod((MethodInfo)mi);
                else if (mi.MemberType == MemberTypes.Constructor)
                    addCtor((ConstructorInfo)mi);
                else if (mi.MemberType == MemberTypes.Property)
                {
                    // TODO
                }
            }
            
            md.Types.Add(tb);
            sw.Write("}\n");
        }

        md.Write(idir+ "/"+fname+"/"+fname + "static.dll");
        sw.Close();
    }

	void writeMethParams(bool isStatic, string retTy,Type[] tps)
	{
		sw.Write("("+retTy+ ((retTy != "" && tps.Length >= 1)? ", " : ""));
		if (isStatic)
        {
            if (tps.Length > 0)
            {
                foreach (Type pt in tps.Skip(1).Take(tps.Length - 2))
                {
                    sw.Write(toDType(pt));
                    sw.Write(", ");
                }
                sw.Write(toDType(tps[tps.Length - 1]));
            }
        }
        else
        {
            if (tps.Length >= 1) sw.Write(toDType(tps[0]));
            if (tps.Length > 1) foreach (Type pt in tps.Skip(1).Take(tps.Length))
            {
                sw.Write(", ");
                sw.Write(toDType(pt));
            }
        }
        sw.Write(")");
	}
    void writeDMethod(bool isStatic,string retTy,string name, Type[] tps, string altName = null)
    {
        sw.Write("    ");
    	if (useCls)
        	sw.Write("abstract ");
        if (isStatic && !useCls)
            sw.Write("static ");
        
        sw.Write(retTy + " " + name);

        writeMethParams(isStatic,"",tps);
 
        if (useCls)
        {
        	sw.Write(";\n");
        	return;
        }
        sw.Write("\n    {\n");
        
        sw.Write("        alias func = extern(C) " + ((altName != null) ? altName : retTy) + " function");
        writeMethParams(isStatic,isStatic ? "" : "void*",tps); sw.Write(";\n");

        sw.Write("        // Avoid the GC stopping a running C# thread.\n");
        sw.Write("        GC.disable; scope(exit) GC.enable;\n");
        sw.Write("        auto f = cast(func)(clrhost.create_delegate(\"" + fname + "static\",");
        sw.Write("\"" + t.Namespace + (t.Namespace == null ? "" : ".") + t.Name + "static\", \"" + name + "\"));\n");
        if (retTy == "void")
            sw.Write("        return f(");
        else
            sw.Write("        auto ret = f(");
        if (!isStatic)
        {
            sw.Write("_raw" + ((tps.Length >= 1)? ", " : ""));
        }
		if (tps.Length > 0)
        {
            
            for (int i = 1; i < tps.Length; i++)
            {
                sw.Write("_param_"+(i-1).ToString() + ",");
            }
            sw.Write("_param_" + (tps.Length-1).ToString());
        }
        sw.Write(");\n");
        if (retTy != "void")
            sw.Write("        return *cast("+retTy+"*)&ret;\n");
        sw.Write("    }\n\n");
    }

    void addMethod(MethodInfo mi)
    {
        //Generate
        // static mi.ReturnType mi.Name (t this, typeof(mi.GetParameters()) args...)
        //{
        //    return this.(mi.Name)(args);
        //}

        // Need to treat differently
        //	ToString Equals GetHashCode & GetType

        List<Type> tl = new List<Type>();
        //tl.Insert(0, t);
        tl.AddRange(mi.GetParameters().Select(p => p.ParameterType));
        Type[] tps = tl.ToArray();
        log("mi.Name = " + mi.Name);
        string methname;
        if (mi.Name == "ToString")
        {
            //Don't create two methods with the same name
            if (t.GetMethod("toString") != null)
                return;
            methname = "toString";
        }
        else if (mi.Name == "GetType")
        {
            
            methname = "getType";
            return;
        }
        else methname = mi.Name;

        var mb = new MethodDefinition(methname,
                                   Mono.Cecil.MethodAttributes.Public |
                                       Mono.Cecil.MethodAttributes.Static,
                                   md.ImportReference(mi.ReturnType));
        mb.Parameters.Add(new ParameterDefinition(md.ImportReference(typeof(IntPtr))));
        foreach (Type _t in tps)
        {
            mb.Parameters.Add(new ParameterDefinition(md.ImportReference(_t)));
        }
        writeDMethod(mi.IsStatic, toDType(mi.ReturnType), methname, tps);

        {
            var ilg = mb.Body.GetILProcessor();
            ilg.Emit(OpCodes.Nop);
            if (mi.IsStatic)
            {
                emitArgs(ilg,tps);
                ilg.Emit(OpCodes.Call, md.ImportReference(mi));
            }
            else
            {
                newVar(mb, typeof(GCHandle));
                newVar(mb, typeof(Object));
                newVar(mb, t);
                if (mi.ReturnType != typeof(void))
                    newVar(mb, mi.ReturnType);
                md.ImportReference(typeof(GCHandle));
                ilg.Emit(OpCodes.Ldarg_0);
                
                MethodReference mr = md.ImportReference(typeof(GCHandle).GetMethod("FromIntPtr", new[] {typeof(IntPtr)}));
                ilg.Emit(OpCodes.Call, mr);
                ilg.Emit(OpCodes.Stloc_0);
                ilg.Emit(OpCodes.Ldloca_S, mb.Body.Variables[0]);
                ilg.Emit(OpCodes.Call, md.ImportReference(typeof(GCHandle).GetMethod("get_Target")));
                ilg.Emit(OpCodes.Stloc_1);
                ilg.Emit(OpCodes.Ldloc_1);
                ilg.Emit(OpCodes.Castclass, md.ImportReference(t));
                ilg.Emit(OpCodes.Stloc_2);
                ilg.Emit(OpCodes.Ldloc_2);
                for (byte x = 0; x < tps.Length; x++)
                {
                    ilg.Emit(OpCodes.Ldarg_S, x);
                }
                ilg.Emit(t.IsSealed ? OpCodes.Call : OpCodes.Callvirt, md.ImportReference(mi));
                if (mi.ReturnType != typeof(void))
                {
                    ilg.Emit(OpCodes.Stloc_3);
                    ilg.Emit(OpCodes.Ldloc_3);
                }
            }
            ilg.Emit(OpCodes.Ret);
        }
        tb.Methods.Add(mb);
    }

    void addCtor(ConstructorInfo ci)
    {
        //Generate C#
        // static IntPtr make (typeof(ci.GetParameters()) args...)
        // {
        //    var ret = new t(args);
        //    Object o = (Object)ret;
        //    GCHandle gch = GCHandle.Alloc(o);
        //    return GCHandle.ToIntPtr(gch);
        // }
        // static void unpin(IntPtr pthis)
        //    GCHandle gch = GCHandle.FromIntPtr(pthis);
        //    gch.Free();
        //	  return;
        // }
        // Generate D
        //
        // @MethodType.static_ t ___ctor( typeof(ci.GetParameters()) args...)
        Type[] tps = ci.GetParameters().Select(p => p.ParameterType).ToArray();
        
        writeDMethod(true,  t.Name, "make",  tps, "void*");
        writeDMethod(false, "void", "unpin", new Type[]{});

        {
            log("here");
            var mb = new MethodDefinition("make",
                                       Mono.Cecil.MethodAttributes.Public |
                                       Mono.Cecil.MethodAttributes.Static,
                                       md.ImportReference(typeof(IntPtr)));
            tb.Methods.Add(mb);
            foreach (Type _t in tps)
                mb.Parameters.Add(new ParameterDefinition(md.ImportReference(_t)));

            var ilg = mb.Body.GetILProcessor();
            newVar(mb, typeof(Object));
            newVar(mb, typeof(GCHandle));
            newVar(mb, typeof(IntPtr));
            // Copy what ildasm says csc does modulo redundant direct branches
            ilg.Create(OpCodes.Nop);

            emitArgs(ilg, tps);

            MethodReference mr = md.ImportReference(ci);
            ilg.Emit(OpCodes.Newobj, mr);

            ilg.Emit(OpCodes.Stloc_0);
            ilg.Emit(OpCodes.Ldloc_0);
            ilg.Emit(OpCodes.Call, md.ImportReference(typeof(GCHandle).GetMethod("Alloc", new[] { typeof(Object) })));

            ilg.Emit(OpCodes.Stloc_1);
            ilg.Emit(OpCodes.Ldloc_1);
            ilg.Emit(OpCodes.Call, md.ImportReference(typeof(GCHandle).GetMethod("ToIntPtr")));
            ilg.Emit(OpCodes.Stloc_2);
            ilg.Emit(OpCodes.Ldloc_2);
            ilg.Emit(OpCodes.Ret);
        }
        {
            var mb2 = new MethodDefinition("unpin",
                                      Mono.Cecil.MethodAttributes.Public |
                                      Mono.Cecil.MethodAttributes.Static,
                                      md.ImportReference(typeof(void)));
            tb.Methods.Add(mb2);
            mb2.Parameters.Add(new ParameterDefinition(md.ImportReference(typeof(IntPtr))));

            var ilg2 = mb2.Body.GetILProcessor();
            newVar(mb2, typeof(GCHandle));

            ilg2.Emit(OpCodes.Nop);
            ilg2.Emit(OpCodes.Ldarg_0);
            ilg2.Emit(OpCodes.Call, md.ImportReference(typeof(GCHandle).GetMethod("FromIntPtr")));
            ilg2.Emit(OpCodes.Stloc_0);
            ilg2.Emit(OpCodes.Ldloca_S,mb2.Body.Variables[0]);
            ilg2.Emit(OpCodes.Call, md.ImportReference(typeof(GCHandle).GetMethod("Free")));
            ilg2.Emit(OpCodes.Nop);

            ilg2.Emit(OpCodes.Ret);

        }
    }
    void newVar(MethodDefinition mb,Type tt)
    {
        mb.Body.Variables.Add(new VariableDefinition(md.ImportReference(tt)));
    }
    static string toDType(Type type)
    {
        if (type == typeof(IntPtr))
            return "void*";
        else if (type.IsArray)
        {
            //N.B. the marshaller can't handle nested (i.e. jagged) arrays. 
            return "SafeArray!(" + toDType(type.GetElementType()) + "," + type.GetArrayRank().ToString() + ")";
        }
        else if (type.IsByRef)
        {
            return "ref " + toDType(type.GetElementType());
        }
        else if (type == typeof(void))
            return "void";
        else if (type == typeof(double))
            return "double";
        else if (type == typeof(int))
            return "int";
        else if (type == typeof(ulong))
            return "ulong";
        else if (type == typeof(string))
            return "const(char)*";
        else if (type == typeof(bool))
            return "bool";
        return "Instance!(\"" + type.Name + "\")";
    }

    static void emitArgs(ILProcessor ilg, Type[] tps)
    {
        if (tps.Length > 0)
            ilg.Emit(OpCodes.Ldarg_0);
        if (tps.Length > 1)
            ilg.Emit(OpCodes.Ldarg_1);
        if (tps.Length > 2)
            ilg.Emit(OpCodes.Ldarg_2);
        if (tps.Length > 3)
            ilg.Emit(OpCodes.Ldarg_3);
        for (byte x = 4; x < tps.Length; x++)
        {
            ilg.Emit(OpCodes.Ldarg_S, x);
        }
    }
    
    // https://docs.microsoft.com/en-au/dotnet/standard/native-interop/type-marshaling
    static bool hasMarshalling(Type t)
    {
        if (Array.Exists(marshalledTypes,
                         e => e == t))
        	return true;
        return false;
    }
    
    static Type[] marshalledTypes = new Type[] {
        typeof(byte),
        typeof(sbyte),
        typeof(short),
        typeof(ushort),
        typeof(int),
        typeof(uint),
        typeof(long),
        typeof(ulong),
        typeof(char),
        typeof(IntPtr),
        typeof(UIntPtr),
        typeof(bool),
        typeof(decimal),
        typeof(DateTime),
        typeof(Guid),
        typeof(string)
    };
}
