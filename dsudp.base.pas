unit dsudp.base;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  System.SyncObjs, System.Contnrs, System.Generics.Collections,
  System.Generics.Defaults, IdGlobal;
{$ELSE}

uses
  SysUtils, Classes, Windows, IniFiles, DateUtils, SyncObjs, Contnrs,
  Generics.Collections, Generics.Defaults, IdGlobal;
{$IFEND}

const
  UDP_MAX_PACKET_SIZE = 1024;
  UDP_TIME_OUT = 10 * 1000;
  UDP_HEAD = -1;

type
  TPacketType = (pt_HeartBeat, pt_Auth, pt_Disconnect, pt_ROBytes, pt_ROString, pt_UBytes, pt_UString);

  TMisc = class(TObject)
  public
    class function TimeUnix: Int64;
    class function TickCount: Cardinal;
  end;

  TIndexList = TList<Integer>;

  TUDPClient = class(TObject)
  private
    FAddr: string;
    FPort: Word;
    FTick: Cardinal;
    FId: string;
    FToken: string;
    FConnected: Boolean;
    procedure SetAddr(Value: string);
    procedure SetPort(Value: Word);
    procedure SetTick(Value: Cardinal);
    procedure SetId(Value: string);
    procedure SetConnected(Value: Boolean);
    procedure SetToken(Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure TickMark;
    property Addr: string read FAddr write SetAddr;
    property Port: Word read FPort write SetPort;
    property Tick: Cardinal read FTick write SetTick;
    property Id: string read FId write SetId;
    property Connected: Boolean read FConnected write SetConnected;
    property Token: string read FToken write SetToken;
  end;

  TUDPPacket = class(TObject)
  public
    PacketType: TPacketType; // 数据类型
    Id: Int64; // 数据包ID
    OrderId: Integer; // 数据序列
    TotalSize: Integer; // 数据包总大小
    CurSize: Integer; // 当前数据大小
    Data: TIdBytes; // 数据
    Disposed: Boolean; // 已经处理
    PeerAddr: string; // 客户端IP
    PeerPort: Word; // 客户端端口
    constructor Create;
    destructor Destroy; override;
  end;

  TUDPQueue = class(TObject)
  private
    FList: TObjectList;
    FLocker: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    function Push(Item: TUDPPacket): Integer;
    function Pop(Index: Integer): TUDPPacket; overload;
    function Pop: TUDPPacket; overload;
    function Count: Integer;
    procedure Delete(Index: Integer); overload;
    procedure Delete; overload;
  end;

  TUDPConnections = TList<TUDPClient>;

  TUDPClientList = class(TObject)
  private
    FLocker: TCriticalSection;
    FHashList: THashedStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure DeleteClient(Id: string); overload;
    procedure DeleteClient(Index: Integer); overload;
    procedure Connections(var Connections: TUDPConnections);
    function AddClient(Client: TUDPClient): Integer;
    function Client(Id: string): Integer; overload;
    function Client(Index: Integer): TUDPClient; overload;
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

// class TUDPPacket
constructor TUDPPacket.Create;
begin
  inherited Create;
  PacketType := pt_HeartBeat;
  Id := 0;
  OrderId := 0;
  CurSize := 0;
  TotalSize := 0;
  Disposed := False;
  SetLength(Data, 0);
  PeerAddr := '';
  PeerPort := 0;
end;

destructor TUDPPacket.Destroy;
begin
  SetLength(Data, 0);
  inherited Destroy;
end;

// class TUDPQueue

constructor TUDPQueue.Create;
begin
  inherited Create;
  FList := TObjectList.Create;
  FLocker := TCriticalSection.Create;
end;

destructor TUDPQueue.Destroy;
begin
  FList.Free;
  FLocker.Free;
  inherited Destroy;
end;

procedure TUDPQueue.Delete(Index: Integer);
begin
  FLocker.Enter;
  try
    FList.Delete(Index);
  finally
    FLocker.Leave;
  end;
end;

procedure TUDPQueue.Delete;
begin
  FLocker.Enter;
  try
    if FList.Count > 0 then
    begin
      FList.Delete(0);
    end;
  finally
    FLocker.Leave;
  end;
end;

function TUDPQueue.Push(Item: TUDPPacket): Integer;
begin
  FLocker.Enter;
  try
    Result := FList.Add(Item);
  finally
    FLocker.Leave;
  end;
end;

function TUDPQueue.Count: Integer;
begin
  FLocker.Enter;
  try
    Result := FList.Count;
  finally
    FLocker.Leave;
  end;
end;

function TUDPQueue.Pop(Index: Integer): TUDPPacket;
begin

  FLocker.Enter;
  try
    Result := nil;

    if FList.Count > Index then
    begin
      Result := TUDPPacket(FList.Items[Index]);
    end;
  finally
    FLocker.Leave;
  end;
end;

function TUDPQueue.Pop: TUDPPacket;
begin
  FLocker.Enter;
  try
    Result := nil;
    if FList.Count > 0 then
    begin
      Result := TUDPPacket(FList.Items[0]);
    end;
  finally
    FLocker.Leave;
  end;
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

destructor TUDPClient.Destroy;
begin
  inherited Destroy;
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

procedure TUDPClient.SetToken(Value: string);
begin
  FToken := Value;
end;

// class TUDPClientList

constructor TUDPClientList.Create;
begin
  inherited Create;
  FLocker := TCriticalSection.Create;
  FHashList := THashedStringList.Create(True);
end;

destructor TUDPClientList.Destroy;
begin
  FHashList.Free;
  FLocker.Free;
  inherited Create;
end;

procedure TUDPClientList.Clear;
var
  I: Integer;
begin

  FLocker.Enter;
  try
    for I := FHashList.Count - 1 downto 0 do
    begin
      DeleteClient(I);
    end;

    FHashList.Clear;
  finally
    FLocker.Leave;
  end;
end;

procedure TUDPClientList.DeleteClient(Id: string);
begin
  DeleteClient(Client(Id));
end;

procedure TUDPClientList.DeleteClient(Index: Integer);
begin
  FLocker.Enter;
  try
    if Index <> -1 then
    begin
      FHashList.Delete(Index);
    end;
  finally
    FLocker.Leave;
  end;
end;

procedure TUDPClientList.Connections(var Connections: TUDPConnections);
var
  I: Integer;
begin
  FLocker.Enter;
  try
    if FHashList.Count > 0 then
    begin

      Connections.Clear;

      for I := 0 to FHashList.Count - 1 do
      begin
        Connections.Add(TUDPClient(FHashList.Objects[I]));
      end;

    end;
  finally
    FLocker.Leave;
  end;
end;

function TUDPClientList.AddClient(Client: TUDPClient): Integer;
begin
  FLocker.Enter;
  try
    if FHashList.IndexOfName(Client.Id) = -1 then
    begin
      FHashList.AddObject(Client.Id, Client);
      Result := FHashList.Count - 1;
    end
    else
    begin
      Result := -1;
    end;
  finally
    FLocker.Leave;
  end;
end;

function TUDPClientList.Client(Id: string): Integer;
begin
  FLocker.Enter;
  try
    Result := FHashList.IndexOfName(Id);
  finally
    FLocker.Leave;
  end;
end;

function TUDPClientList.Client(Index: Integer): TUDPClient;
begin
  FLocker.Enter;
  try
    Result := TUDPClient(FHashList.Objects[Index]);
  finally
    FLocker.Leave;
  end;
end;

function TUDPClientList.Count: Integer;
begin
  FLocker.Enter;
  try
    Result := FHashList.Count;
  finally
    FLocker.Leave;
  end;
end;

end.

