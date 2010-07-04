unit uUnGZ;

interface

uses Classes,SysUtils,Variants,uInterfaces,uModule,uOSMCommon,ZLibExGZ;
implementation

const
  unGZClassGUID: TGUID = '{7871A3E0-9028-47B6-AF31-30890104853F}';

type
  TUnGZ = class(TOSMDecompressStream)
  protected
    function createzStream:TStream;override;
  end;

function TUnGZ.createzStream: TStream;
begin
  result:=TGZDecompressionStream.Create(inStreamAdaptor);
end;

initialization
  OSManRegister(TUnGZ, unGZClassGUID);
end.
