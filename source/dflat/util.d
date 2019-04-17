module dflat.util;

import std.path;
import std.array;

string pathcat(string[] paths...)
{
    Appender!string app;
    if (paths.length == 0) return null;
    if (paths.length == 1) return paths[0];
    app.put(paths[0]);
    foreach(p; paths[1 .. $])
    {
        app.put(pathSeparator);
        app.put(p);
    }
    return app.data;
}
