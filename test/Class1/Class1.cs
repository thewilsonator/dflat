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
    public int bar
    {
        get { return a; }
        set { a = value; }
    }
}

public class Class2
{
    public static IntPtr make(int a)
    {
        Object ret = new Class1(a);
        GCHandle gch = GCHandle.Alloc(ret);
        return GCHandle.ToIntPtr(gch);
    }
    private static Class1 _get(IntPtr pthis)
    {
        //System.Console.WriteLine(pthis.ToString("X"));
        var gch = GCHandle.FromIntPtr(pthis);
        var targ = gch.Target;
        //System.Console.WriteLine(().ToString());
        return (Class1)targ;
    }
    public static string toString(IntPtr pthis)
    {
        Class1 actual = _get(pthis);
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
    
    static void barSet(IntPtr pthis, int a)
    {
        Class1 actual = _get(pthis);
        actual.bar = a;
    }
    
    static int barGet(IntPtr pthis)
    {
        Class1 actual = _get(pthis);
        return actual.bar;
    }
}

//}
