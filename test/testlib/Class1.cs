using System;
using System.Runtime.InteropServices;
namespace testlib
{
    public class Class1
    {
        int a;
        public Class1(int aa) { a = aa; }
    }

    class Class2
    {
        static IntPtr make(int a)
        {
            var ret = new Class1(a);
            GCHandle gch = GCHandle.Alloc(ret);
            return GCHandle.ToIntPtr(gch);
        }

        static void unpin(IntPtr pthis)
        {
            GCHandle gch = GCHandle.FromIntPtr(pthis);
            gch.Free();
            return;
        }
    }
}
