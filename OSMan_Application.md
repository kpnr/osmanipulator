# Summary #

Application is root OSMan object. This object supports methods for listing of availaible modules and objects, object creation and accessing OSMan global settings.


# Interface #

  * **[IOSManAll](IOSManAll.md) interface**
  * **createObject(string objClassName)**
> > Create object by short or full [object class name](class_name.md) and returns it. If no object class found exception raised. If you have several implementations of same object type in different modules, you can any access to any implementation with **[full class name](class_name.md)**.
  * **getModules()**
> > Returns list of loaded [modules](module.md) as [safe array](safe_array.md) of string [variants](variant.md).
  * **getModuleClasses(string moduleName)**
> > Get available classes in module **moduleName**. Returns list of [short class names](class_name.md) of available objects as [safe array](safe_array.md) of string [variants](variant.md). If no module found zero-length array returned.
  * **log(string logMessage)**
> > Write **logMessage** into global logger. If no logger set then nothing happen.
  * **logger**
> > Global [logging](ILogger.md) interface set & get property.

# Usage #
See **modlist.js** script in examples.