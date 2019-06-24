using System;
using System.Runtime.InteropServices;
//namespace testlib
//{
    public class Class1
    {
        int a;
        public Class1(int aa) { a = aa; }
        public void foo() { a = 42; }
        public string ToString() { return a.ToString(); }
    }

    class Class2
    {
        public static IntPtr make(int a)
        {
            var ret = new Class1(a);
            GCHandle gch = GCHandle.Alloc(ret);
            return GCHandle.ToIntPtr(gch);
        }

        public static string toString(IntPtr pthis)
        {
            var gch = GCHandle.FromIntPtr(pthis);
            var targ = gch.Target;
            Class2 actual = (Class2)targ;
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
