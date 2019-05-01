module dflat;

public import dflat.bind;
public import dflat.host;
public import dflat.wrap;
public import dflat.util;
public import dflat.types;

/*
// C# in dll manlib
public class ManLib
{
// "Note that String became char *, according to the default C# marshaling rules.
// You can also customize the marshaling as needed using [MarshalAsAttribute]".
// TODO handle other marshalling

public static string Bootstrap()
{
return "Bootstrap!";
}
}

->
// D
@DLL("manlib")
abstract class ManLib
{
CLRAllocatedCString Bootstrap();
}
*/
