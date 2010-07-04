unit uUnBZ2;

interface

uses Classes,uOSMCommon,uModule, Variants, SynBz, Windows, SysUtils;

implementation

const
  unBZ2ClassGUID: TGUID = '{B79B1A06-E62D-4F58-B8E6-BD6C48B8C835}';

type
  TUnBZ2 = class(TOSMDecompressStream)
  protected
    function createzStream():TStream;override;
  end;

  { TUnBZ2 }

function TUnBZ2.createzStream: TStream;
begin
  result:=TBZDecompressor.Create(inStreamAdaptor);
end;

initialization
  OSManRegister(TUnBZ2, unBZ2ClassGUID);
end.

