# Summary #

**Safe arrays** used in bulk data transfers such as _tags_ or _members_ lists, database parameters and result sets.

# Details #

Safe array is [variant](variant.md) datatype. It can be accessed via:
  * WinAPI _SafeArray_ functions;
  * Array functions and operations in VBS or VBA;
  * _safeArray.toArray()_ function in JScript (variants array only);
  * _VarArray_ functions in Delphi.

OSMan uses _safe array of variants_ at most. One exception is stream I/O functions which uses _safe array of bytes(UI8)_.

Any OSMan function that accept _safe array of variants_ parameters should accept (automatically convert into safe arrays) _JSArray (JScript array object)_ parameters.