using System;
using System.Runtime.InteropServices;
using System.IO;
//namespace testlib
//{
public class Class1
{
    int a;
    public Class1(int aa) { a = aa; }
    public void foo() { a = 42; }
    public override string ToString() { return a.ToString(); }
}

public class Class2
{
    public static IntPtr make(int a)
    {
        Object ret = new Class1(a);
        GCHandle gch = GCHandle.Alloc(ret);
        return GCHandle.ToIntPtr(gch);
    }

    public static string toString(IntPtr pthis)
    {
        //System.Console.WriteLine(pthis.ToString("X"));
        var gch = GCHandle.FromIntPtr(pthis);
        var targ = gch.Target;
        //System.Console.WriteLine(().ToString());
        Class1 actual = (Class1)targ;
        return actual.ToString();
    }
    public static void unpin(IntPtr pthis)
    {
        GCHandle gch = GCHandle.FromIntPtr(pthis);
        gch.Free();
        return;
    }
    static void test()
    {
        var a = Class2.make(42);
        string s = toString(a);
        Class2.unpin(a);
    }
}

//}
