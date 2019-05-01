# TODO

* Saving generated DLL only works on windows 
    - look into https://github.com/Lokad/ILPack
* Add support for namespaces
* Update to using `$ClassName ~ "Static"`
* Crosscheck th generated IL (https://reubenbond.github.io/posts/codegen-2-il-boogaloo) is a nice intro
* Testing
    - SafeArray desctiptor stuff (Urgh)
        - Need VARENUM otherwise use `core.sys.windows.oleauto`
    - Instances
    - GC contention and pinning logic
* `Instance!("IntPtr")` should be `void*`

# Things to not care about

* Math operator overloads
* GetType
* Genereic Methods (`Instance!("T")`)
* DynamicInvoke
* implicit casts (`op_Implicit`)
