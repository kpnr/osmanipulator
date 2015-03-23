# Summary #

OSMan **module** is Win32 dll containing OLE-Automation objects.

# Details #

OSMan module file extention must be **omm** (OsManModule). Module must export [OSManModule](OSManModule.md) function.
Module load order is undefined, so implementation should not rely or depend on loading order.

If any error occured during dll loading or OSManModule function call then no module and objects registered in OSMan.