unit dsudp.base;

interface

uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  IdUDPServer, IdGlobal;

const
  UDP_MAX_PACKET_SIZE = 1024;
  UDP_TIME_OUT = 10 * 1000;

type
  TUDPPacket = packed record
    Head: Integer;
    Typ: Byte;
    Id: Integer;
    Size: Int64;
    Data: TIdBytes;
  end;

  TMisc = class(TObject)
  public
    class function TimeUnix: Int64;
  end;

  TUDPClient = class(TObject)
  private
    FAddr: string;
    FPort: Word;
    FDate: Int64;
    FId: string;
    FConnected: Boolean;
    procedure SetAddr(Value: string);
    procedure SetPort(Value: Word);
    procedure SetDate(Value: Int64);
    procedure SetId(Value: string);
    procedure SetConnected(Value: Boolean);
  public
    constructor Create;
    property Addr: string read FAddr write SetAddr;
    property Port: Word read FPort write SetPort;
    property Date: Int64 read FDate write SetDate;
    property Id: string read FId write SetId;
    property Connected: Boolean read FConnected write SetConnected;
  end;

  TUDPClientList = class(TObject)
  private
    FHashList: THashedStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure DeleteClient(Id: string); overload;
    procedure DeleteClient(Index: Integer); overload;
    function AddClient(Client: TUDPClient): Integer;
    function Client(Id: string): Integer;
    function Count: Integer;
  end;

implementation

// class TMisc

class function TMisc.TimeUnix: Int64;
begin
  Result := DateTimeToUnix(Now);
end;

// class TUDPClient

constructor TUDPClient.Create;
begin
  inherited Create;
  FAddr := '';
  FPort := 0;
  FDate := TMisc.TimeUnix;
  FId := '';
  FConnected := False;
end;

procedure TUDPClient.SetAddr(Value: string);
begin
  FAddr := Value;
  SetId(FAddr + ':' + IntToStr(FPort));
end;

procedure TUDPClient.SetPort(Value: Word);
begin
  FPort := Value;
  SetId(FAddr + ':' + IntToStr(FPort));
end;

procedure TUDPClient.SetDate(Value: Int64);
begin
  FDate := Value;
end;

procedure TUDPClient.SetId(Value: string);
begin
  FId := Value;
end;

procedure TUDPClient.SetConnected(Value: Boolean);
begin
  FConnected := Value;
end;

// class TUDPClientList

constructor TUDPClientList.Create;
begin
  inherited Create;
  FHashList := THashedStringList.Create(True);
end;

destructor TUDPClientList.Destroy;
begin
  FHashList.Free;
  inherited Create;
end;

procedure TUDPClientList.Clear;
var
  I: Integer;
begin
  for I := FHashList.Count - 1 downto 0 do
  begin
    DeleteClient(I);
  end;

  FHashList.Clear;
end;

procedure TUDPClientList.DeleteClient(Id: string);
begin
  DeleteClient(Client(Id));
end;

procedure TUDPClientList.DeleteClient(Index: Integer);
begin
  if Index <> -1 then
  begin
    FHashList.Delete(Index);
  end;
end;

function TUDPClientList.AddClient(Client: TUDPClient): Integer;
begin
  if FHashList.IndexOfName(Client.Id) = -1 then
  begin
    FHashList.AddObject(Client.Id, Client);
    Result := FHashList.Count - 1;
  end
  else
  begin
    Result := -1;
  end;
end;

function TUDPClientList.Client(Id: string): Integer;
begin
  Result := FHashList.IndexOfName(Id);
end;

function TUDPClientList.Count: Integer;
begin
  Result := FHashList.Count;
end;

end.

