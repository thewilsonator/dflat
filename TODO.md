# TODO

* Saving generated DLL only works on windows 
    - look into https://github.com/Lokad/ILPack
* Testing
    - SafeArray desctiptor stuff (Urgh)
        - Need VARENUM otherwise use `core.sys.windows.oleauto`
    - Instances
    - GC contention and pinning logic
* Build CSreflect as a dub prebuild command
    - copy the generated files into `test/`

# Things to not care about improving

* Math operator overloads
* GetType
* Genereic Methods (`Instance!("T")`)
* DynamicInvoke
* implicit casts (`op_Implicit`)
