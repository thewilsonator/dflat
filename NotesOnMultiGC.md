
# The Problem: Two mutually Oblivious Interacting Garbabe Collectors

The D GC will only ever potentially run when you allocate with it, or deliberately call `GC.collect`.
Will only suspend threads created in D or attached to the runtime. 
(Using multiple threads for collection does not add complexity as they are separate from the 
rest of the D threads, see `--DRT-gcopt=??`)

The .Net GC however runs whenever it wants when running code.

This can lead to a number of problems in multi-threaded code:

* concurrent multilanguage GC cycles, results in suspension of threads multiple times
* thread being suspended by one language and being resumed by the other.

Key: 
```
-  : normal execution
{} : GC collection of the currently executing language
D  : thread is now executing D code
C# : thread is now executing C# code
|  : Thread is blocked ir suspended
Tn : a numbered thread
:( : BANG - something bad happens: GC race, deadlock or other fun outcome.
:| : not sure or caution required
:) : behaviour is good 
-> : thread creation
``

Case 1: A D thread, T2 executes come C# code, meanwhile another D thread triggers a D 
GC cycle and needs to look at the stackframe of T2. 
This is fine so long as the .Net runtime does not try to do anything with the suspended thread.
Pointers in the C# stackframes will not be recognised as they haven't been `addRanged`'d to the D GC.
```
T1: D ----------- {    } -------
T2: D ---- C# --- |    | -- D --
``

Case 2: A D thread, T1, runs some C# code that spawns another thread (also running C# code) and resumes to D. The spawned thread, T2, then triggers a C# GC cycle.
```
T1: D ---- C# -- D ---------
           |
T2:        -> C# ---- { } --
``

From https://github.com/dotnet/coreclr/blob/master/Documentation/coding-guidelines/clr-code-guide.md

Put precisely: as long as a thread is in cooperative mode, it is guaranteed that a 
GC will only occur when your thread triggers an object allocation, calls out to interruptible 
managed code or explicitly requests a GC. All other threads are blocked from GC. As long as 
your thread is in preemptive mode, then you must assume that a GC can be started any time 
(by some other thread) and is running concurrently with your thread.


# Current Strategy:

* disable the D GC when calling C#
* disable the C# GC (with TryStartNoGCRegion) when calling D
* Keep reference counts of the manual enable/disable unless already refcounts
    - D GC already reference counts the number of [en|dis]ables
    - C# GC is not reentrant on successful calls to TryStartNoGCRegion and not refcounted
    - need to spin on the return value of both TryStartNoGCRegion and EndNoGCRegion


# Dead Ends

Preemptive/Cooperative is useless becuase you can get interupted at any time in preemptive anyway.
See https://github.com/dotnet/coreclr/blob/master/src/vm/threads.h#L61

https://docs.microsoft.com/en-us/dotnet/framework/unmanaged-api/hosting/igcthreadcontrol-interface
SuspensionStarting
Notifies the host that the runtime is beginning a thread suspension for a 
garbage collection or other suspension.

# Not-Dead-Yet End


https://docs.microsoft.com/en-us/dotnet/api/system.gc.trystartnogcregion?view=netframework-4.8
GC.TryStartNoGCRegion
Attempts to disallow garbage collection during the execution of a critical path if a specified 
amount of memory is available for the large object heap and the small object heap, 
and controls whether the garbage collector does a full blocking garbage collection 
if not enough memory is initially available.
