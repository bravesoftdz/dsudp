unit dsudp.base;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  IdUDPServer, IdGlobal;
{$ELSE}

uses
  SysUtils, Classes, IniFiles, DateUtils, IdUDPServer, IdGlobal, Windows;
{$IFEND}

const
  UDP_MAX_PACKET_SIZE = 1024;
  UDP_TIME_OUT = 10 * 1000;

type
  TPacketType = (pt_Connect, pt_Auth, pt_ROBytes, pt_ROString, pt_RBytes, pt_RString, pt_Bytes, pt_String);

  TUDPPacket = class(TObject)
  public
    PacketType: TPacketType; // 数据类型
    Id: Integer; // 数据包ID
    OrderId: Int64; // 数据序列
    Size: Int64; // 数据大小
    Data: TIdBytes; // 数据
  end;

  TMisc = class(TObject)
  public
    class function TimeUnix: Int64;
    class function TickCount: Cardinal;
  end;

  TUDPClient = class(TObject)
  private
    FAddr: string;
    FPort: Word;
    FTick: Cardinal;
    FId: string;
    FConnected: Boolean;
    procedure SetAddr(Value: string);
    procedure SetPort(Value: Word);
    procedure SetTick(Value: Cardinal);
    procedure SetId(Value: string);
    procedure SetConnected(Value: Boolean);
  public
    constructor Create;
    procedure TickMark;
    property Addr: string read FAddr write SetAddr;
    property Port: Word read FPort write SetPort;
    property Tick: Cardinal read FTick write SetTick;
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

class function TMisc.TickCount: Cardinal;
begin
{$IF CompilerVersion >= 31.0}
  Result := TThread.GetTickCount;
{$ELSE}
  Result := Windows.GetTickCount;
{$IFEND}
end;

// class TUDPClient

constructor TUDPClient.Create;
begin
  inherited Create;
  FAddr := '';
  FPort := 0;
  FTick := TMisc.TickCount;
  FId := '';
  FConnected := False;
end;

procedure TUDPClient.TickMark;
begin
  FTick := TMisc.TickCount;
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

procedure TUDPClient.SetTick(Value: Cardinal);
begin
  FTick := Value;
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

