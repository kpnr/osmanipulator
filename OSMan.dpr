library OSMan;

{%ToDo 'OSMan.todo'}

uses
  FastMM4 in '..\..\..\Delphi\FastMM\FastMM4.pas',
  FastMove,
  ComServ,
  OSMan_TLB in 'OSMan_TLB.pas',
  uOSManApplication in 'uOSManApplication.pas' {Application: CoClass},
  Graphics in 'Graphics.pas',
  StdVCL in 'StdVCL.pas',
  uFileIO in 'uFileIO.pas',
  uModule in 'uModule.pas',
  uXML in 'uXML.pas',
  SAXMS in 'xml\SAXMS.pas',
  SAX in 'xml\SAX.pas',
  SAXHelpers in 'xml\SAXHelpers.pas',
  SAXExt in 'xml\SAXExt.pas',
  MSXML3 in 'xml\MSXML3.pas',
  uOSMCommon in 'uOSMCommon.pas',
  uInterfaces in 'uInterfaces.pas',
  uMap in 'uMap.pas',
  FastMM4Messages in '..\..\..\Delphi\FastMM\FastMM4Messages.pas',
  uDB in 'db\uDB.pas',
  SQLiteObj in 'db\SQLiteObj.pas',
  SQLite3 in 'db\SQLite3.pas',
  DBF in 'db\DBF.PAS',
  uGeoTools in 'uGeoTools.pas',
  uNetMap in 'uNetMap.pas';

{$E omm}

exports
  DllGetClassObject,
  DllCanUnloadNow,
  DllRegisterServer,
  DllUnregisterServer;

{$R *.TLB}

{$R *.RES}

begin
end.
