unit OSMan_TLB;

// ************************************************************************ //
// WARNING                                                                    
// -------                                                                    
// The types declared in this file were generated from data read from a       
// Type Library. If this type library is explicitly or indirectly (via        
// another type library referring to this type library) re-imported, or the   
// 'Refresh' command of the Type Library Editor activated while editing the   
// Type Library, the contents of this file will be regenerated and all        
// manual modifications will be lost.                                         
// ************************************************************************ //

// PASTLWTR : 1.2
// File generated on 11.03.2011 1:05:15 from Type Library described below.

// ************************************************************************  //
// Type Lib: C:\work\osm2russa\OSMan\OSMan.tlb (1)
// LIBID: {99AA9527-601D-420B-BC61-41859542A1A6}
// LCID: 0
// Helpfile: 
// HelpString: OSMan Library
// DepndLst: 
//   (1) v2.0 stdole, (D:\WINDOWS\system32\stdole2.tlb)
// ************************************************************************ //
{$TYPEDADDRESS OFF} // Unit must be compiled without type-checked pointers. 
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
interface

uses Windows, ActiveX, Classes, Graphics, StdVCL, Variants;
  

// *********************************************************************//
// GUIDS declared in the TypeLibrary. Following prefixes are used:        
//   Type Libraries     : LIBID_xxxx                                      
//   CoClasses          : CLASS_xxxx                                      
//   DISPInterfaces     : DIID_xxxx                                       
//   Non-DISP interfaces: IID_xxxx                                        
// *********************************************************************//
const
  // TypeLibrary Major and minor versions
  OSManMajorVersion = 1;
  OSManMinorVersion = 0;

  LIBID_OSMan: TGUID = '{99AA9527-601D-420B-BC61-41859542A1A6}';

  IID_IOSManApplication: TGUID = '{D31A5B75-BA84-4BB9-AA22-76C48D986595}';
  CLASS_Application: TGUID = '{E3FA2A2D-0FC4-4281-B3A2-237CBB53C9CC}';
type

// *********************************************************************//
// Forward declaration of types defined in TypeLibrary                    
// *********************************************************************//
  IOSManApplication = interface;
  IOSManApplicationDisp = dispinterface;

// *********************************************************************//
// Declaration of CoClasses defined in Type Library                       
// (NOTE: Here we map each CoClass to its Default Interface)              
// *********************************************************************//
  Application = IOSManApplication;


// *********************************************************************//
// Interface: IOSManApplication
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {D31A5B75-BA84-4BB9-AA22-76C48D986595}
// *********************************************************************//
  IOSManApplication = interface(IDispatch)
    ['{D31A5B75-BA84-4BB9-AA22-76C48D986595}']
    function createObject(const ObjClassName: WideString): IDispatch; safecall;
    function getModules: OleVariant; safecall;
    function getModuleClasses(const ModuleName: WideString): OleVariant; safecall;
    function toString: WideString; safecall;
    function getClassName: WideString; safecall;
    function Get_logger: OleVariant; safecall;
    procedure Set_logger(Value: OleVariant); safecall;
    procedure log(const msg: WideString); safecall;
    property logger: OleVariant read Get_logger write Set_logger;
  end;

// *********************************************************************//
// DispIntf:  IOSManApplicationDisp
// Flags:     (4416) Dual OleAutomation Dispatchable
// GUID:      {D31A5B75-BA84-4BB9-AA22-76C48D986595}
// *********************************************************************//
  IOSManApplicationDisp = dispinterface
    ['{D31A5B75-BA84-4BB9-AA22-76C48D986595}']
    function createObject(const ObjClassName: WideString): IDispatch; dispid 221;
    function getModules: OleVariant; dispid 222;
    function getModuleClasses(const ModuleName: WideString): OleVariant; dispid 223;
    function toString: WideString; dispid 201;
    function getClassName: WideString; dispid 202;
    property logger: OleVariant dispid 203;
    procedure log(const msg: WideString); dispid 204;
  end;

// *********************************************************************//
// The Class CoApplication provides a Create and CreateRemote method to          
// create instances of the default interface IOSManApplication exposed by              
// the CoClass Application. The functions are intended to be used by             
// clients wishing to automate the CoClass objects exposed by the         
// server of this typelibrary.                                            
// *********************************************************************//
  CoApplication = class
    class function Create: IOSManApplication;
    class function CreateRemote(const MachineName: string): IOSManApplication;
  end;

implementation

uses ComObj;

class function CoApplication.Create: IOSManApplication;
begin
  Result := CreateComObject(CLASS_Application) as IOSManApplication;
end;

class function CoApplication.CreateRemote(const MachineName: string): IOSManApplication;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_Application) as IOSManApplication;
end;

end.
