using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Reflection;
using System.Reflection.Emit;
using System.IO;
using System.Runtime.InteropServices;

class CLRBuilder
{
    StreamWriter sw; // output .d file
    Type t;          // reflected upon type
    TypeBuilder tb;  // type under construction
    string fname;    // name of file
    private string idir;
    CLRBuilder(string name, string aidir)
    {
        fname = name;
        idir = aidir;
        sw = new StreamWriter( fname + ".d", false, Encoding.UTF8);
    }
    static void Main(string[] args)
    {
        new CLRBuilder(args[0],args[1]).run();

    }
    void writeHeader()
    {
        sw.Write("module " + fname + ";\n");
        sw.Write("import dflat.wrap; import dflat.types;\n");
        sw.Write("@DLL(\"" + fname + "\")\n");

        sw.Write("{\n");
    }
    void run()
    {
        writeHeader();
        AssemblyBuilder ab = AppDomain.CurrentDomain.DefineDynamicAssembly(
                                       new AssemblyName(fname + "static"),
                                       AssemblyBuilderAccess.Save);

        // To avoid duplicately adding types
        HashSet<String> visitedTypes = new HashSet<String>();

        ModuleBuilder mb = ab.DefineDynamicModule(fname + "static.dll", fname + "static.dll", true);
        foreach (Type _ in Assembly.LoadFile(Path.GetFullPath(Path.Combine(idir,fname + ".dll"))).GetExportedTypes())
        {
            t = _;
            //Assume that duplicates are identical (e.g. interface / class pairs)
            if (visitedTypes.Contains(t.Name)) continue;
            visitedTypes.Add(t.Name);
            //TODO: support namespaces
            sw.Write("abstract class "); sw.Write(t.Name); sw.Write(" {\n");
            tb = mb.DefineType(t.Name + "static", TypeAttributes.Public);
            foreach (MemberInfo mi in t.GetMembers())
            {
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
            tb.CreateType();
            sw.Write("}\n");
        }
        mb.CreateGlobalFunctions();
        // N.B. Cannot save this to anywhere other than cwd
        // due to Save 
        ab.Save(fname + "static.dll"); 
        sw.Write("}\n");
        sw.Close();
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
        tl.Insert(0, t);
        tl.AddRange(mi.GetParameters().Select(p => p.ParameterType));
        Type[] tps = tl.ToArray();
        MethodBuilder mb = tb.DefineMethod(mi.Name,
                                           MethodAttributes.Public |
                                                   MethodAttributes.Static,
                                           mi.ReturnType,
                                           tps
                                           );
        {
            ILGenerator ilg = mb.GetILGenerator();
            ilg.Emit(OpCodes.Nop);
            if (mi.IsStatic)
            {
                emitArgs(ilg,tps);
                ilg.Emit(OpCodes.Call, mi);
            }
            else
            {
                ilg.Emit(OpCodes.Ldarg_0);
                ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("FromIntPtr"));
                ilg.Emit(OpCodes.Stloc_0);
                ilg.Emit(OpCodes.Ldloc_0);
                ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("get_Target"));
                ilg.Emit(OpCodes.Stloc_1);
                ilg.Emit(OpCodes.Ldloc_1);
                ilg.Emit(OpCodes.Castclass, t);
                ilg.Emit(OpCodes.Stloc_2);
                ilg.Emit(OpCodes.Ldloc_2);
                for (byte x = 1; x < tps.Length; x++)
                {
                    ilg.Emit(OpCodes.Ldarg_S, x);
                }
                ilg.Emit(t.IsSealed ? OpCodes.Call : OpCodes.Callvirt, mi);
            }
            ilg.Emit(OpCodes.Nop);
            ilg.Emit(OpCodes.Ret);

        }
        {
            sw.Write("\tabstract " + toDType(mi.ReturnType) + " " + mi.Name);
            sw.Write("(");
            if (mi.IsStatic)
            {
                if (tps.Length > 1) foreach (Type pt in tps.Skip(1).Take(tps.Length - 2))
                {
                    sw.Write(toDType(pt));
                    sw.Write(", ");
                }
                if ((tps.Length > 1))
                    sw.Write(toDType(tps[tps.Length - 1]));
            }
            else
            {
                sw.Write(toDType(tps[0])); sw.Write(" ");
                if (tps.Length > 1) foreach (Type pt in tps.Skip(1).Take(tps.Length))
                {
                    sw.Write(", ");
                    sw.Write(toDType(pt));
                }
            }
        }

        sw.Write(");\n");
    }

    void addCtor(ConstructorInfo ci)
    {
        //Generate C#
        // static IntPtr make (typeof(ci.GetParameters()) args...)
        // {
        //    var ret = new t(args); // DONE
        //    GCHandle gch = GCHandle.Alloc(ret);
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
        {
            MethodBuilder mb = tb.DefineMethod("make",
                                           MethodAttributes.Public |
                                                   MethodAttributes.Static,
                                           typeof(IntPtr),
                                           tps
                                           );
            ILGenerator ilg = mb.GetILGenerator();
            ilg.DeclareLocal(/* ret */t, /* pinned =*/false);
            ilg.DeclareLocal(/* gch */typeof(GCHandle), /* pinned=*/false);
            ilg.DeclareLocal(/* gch */typeof(IntPtr), /* pinned =*/false);
            // Copy what ildasm says csc does modulo redundant direct branches
            ilg.Emit(OpCodes.Nop);

            emitArgs(ilg, tps);
            ilg.Emit(OpCodes.Newobj, ci);
            ilg.Emit(OpCodes.Stloc_0);
            ilg.Emit(OpCodes.Ldloc_0);
            ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("Alloc", new[] { typeof(Object) }));
            ilg.Emit(OpCodes.Stloc_1);
            ilg.Emit(OpCodes.Ldloc_1);
            ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("ToIntPtr"));
            ilg.Emit(OpCodes.Stloc_2);
            ilg.Emit(OpCodes.Ldloc_2);
            ilg.Emit(OpCodes.Ret);
        }
        {
            MethodBuilder mb = tb.DefineMethod("unpin",
                                           MethodAttributes.Public |
                                                   MethodAttributes.Static,
                                           typeof(void),
                                           new[] { typeof(IntPtr) }
                                           );
            ILGenerator ilg = mb.GetILGenerator();
            ilg.DeclareLocal(/* gch */typeof(GCHandle), /* pinned=*/false);
            ilg.Emit(OpCodes.Nop);
            ilg.Emit(OpCodes.Ldarg_0);
            ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("FromIntPtr"));
            ilg.Emit(OpCodes.Stloc_0);
            ilg.Emit(OpCodes.Ldloca_S,0);
            ilg.Emit(OpCodes.Call, typeof(GCHandle).GetMethod("Free"));
            ilg.Emit(OpCodes.Nop);
            ilg.Emit(OpCodes.Ret);
        }
        {
            sw.Write("\tabstract " + toDType(t) + " make(");
            foreach (Type pt in tps.Take(tps.Length - 1))
            {
                sw.Write(toDType(pt));
                sw.Write(", ");
            }
            if ((tps.Length > 0))
                sw.Write(toDType(tps[tps.Length - 1]));
            sw.Write(");\n");

            sw.Write("\tabstract void unpin(" + toDType(t) + ");\n");
        }
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
            return "CLRAllocatedCString";
        else if (type == typeof(bool))
            return "bool";
        return "Instance!(\"" + type.Name + "\")";
    }

    static void emitArgs(ILGenerator ilg, Type[] tps)
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
}
