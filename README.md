# dlfat - a c# wrapper generator for D

Dflat is an application and library to generate boilerplate and dlls to bind to C# code.

```c#
public class Class1
{
int a;
public Class1(int aa) { a = aa; }
public void foo() { a = 42; }
public override string ToString() { return a.ToString(); }
}
```

```d
auto a = Class1.make(314);
a.toString().fromStringz.writeln; // 314
a.foo();
a.toString().fromStringz.writeln; // 42
a.unpin(); // Objects created with make need their c# GC references unpinned manually to avoid leaking
```

see the tests for more details.

## Building

You will need the Mono runtime, including Mono.Cecil and derelict-util
