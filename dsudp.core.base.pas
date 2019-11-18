unit dsudp.core.base;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  System.SyncObjs, System.Contnrs, System.Generics.Collections,
  System.Generics.Defaults;
{$ELSE}

uses
  SysUtils, Classes, Windows, IniFiles, DateUtils, SyncObjs, Contnrs,
  Generics.Collections, Generics.Defaults;
{$IFEND}

const
  UDP_MAX_PACKET_SIZE = 1024;
  UDP_TIME_OUT = 30 * 1000;
  UDP_HEARTBEAT_TIME = 3000;
  UDP_HEAD = -1;

type
  TPacketType = (pt_HeartBeat, pt_Auth, pt_Disconnect, pt_ROBytes, pt_ROString, pt_UBytes, pt_UString);

  TDSMisc = class(TObject)
  public
    class function TimeUnix: Int64;
    class function TickCount: Cardinal;
  end;

  TIndexs = TList<Integer>;

  TPacketIndexs = TList<Int64>;

  TDSPacket = class(TObject)
  public
    PacketType: TPacketType; // 数据类型
    Id: Int64; // 数据包ID
    OrderId: Integer; // 数据序列
    Confirm: Boolean; // 是否为确认包
    TotalSize: Integer; // 数据包总大小
    CurSize: Integer; // 当前数据大小
    Data: TBytes; // 数据
    constructor Create;
    destructor Destroy; override;
  end;

  TDSQueue = class(TObject)
  private
    FList: TObjectList<TDSPacket>;
    FLocker: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    function Push(Item: TDSPacket): Integer;
    function Pop(Index: Integer): TDSPacket; overload;
    function Pop: TDSPacket; overload;
    function Count: Integer;
    procedure Delete(Index: Integer); overload;
    procedure Delete; overload;
    procedure DeleteOf(PacketId: Int64);
  end;

  TDSConfirm = class(TObject)
  public
    Id: Int64;
    OrderId: Integer;
    Tick: Cardinal;
    FComplete: Boolean;
    constructor Create(APacketId: Int64; AOrderId: Integer);
    property Complete: Boolean read FComplete write FComplete;
  end;

  TDSConfirms = TObjectList<TDSConfirm>;

  TDSConnection = class(TObject)
  private
    FPacketId: Int64;
    FRemoteAddr: string;
    FRemotePort: Word;
    FTick: Cardinal;
    FId: string;
    FToken: string;
    FConnected: Boolean;
    FDisconnect: Boolean;
    FSendQueue: TDSQueue;
    FRecvQueue: TDSQueue;
    FRecvConfirm: TDSConfirms;
    FLocker: TCriticalSection;
    FConfirmTick: Cardinal;
    procedure SetAddr(Value: string);
    procedure SetPort(Value: Word);
    procedure SetTick(Value: Cardinal);
    procedure SetId(Value: string);
    procedure SetConnected(Value: Boolean);
    procedure SetDisconnected(Value: Boolean);
    procedure SetToken(Value: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure TickMark;
    procedure PostROBytes(Data: TBytes);
    procedure PostROString(Data: string);
    procedure PostUBytes(Data: TBytes);
    procedure PostUString(Data: string);
    procedure PostConfirm(PacketId: Int64; OrderId: Integer; PacketType: TPacketType);
    procedure OnConnected(Token: string);
    procedure OnDisconnect;
    procedure OnHeartBeat;
    procedure OnRecvROBytes(Data: TBytes);
    procedure OnRecvROString(Data: string);
    procedure OnRecvUBytes(Data: TBytes);
    procedure OnRecvUString(Data: string);
    procedure ConfirmRecv(PacketId: Int64; OrderId: Integer);
    procedure SetConfirmComplete(PacketId: Int64);
    procedure DeleteSendQueue(PacketId: Int64);
    function Recved(PacketId: Int64; OrderId: Integer): Boolean;
    property RemoteAddr: string read FRemoteAddr write SetAddr;
    property RemotePort: Word read FRemotePort write SetPort;
    property Tick: Cardinal read FTick write SetTick;
    property Id: string read FId write SetId;
    property Connected: Boolean read FConnected write SetConnected;
    property Disconnect: Boolean read FDisconnect write SetDisconnected;
    property Token: string read FToken write SetToken;
    property SendQueue: TDSQueue read FSendQueue;
    property RecvQueue: TDSQueue read FRecvQueue;
  end;

  TDSConnectionsEx = TList<TDSConnection>;

  TDSConnectionList = class(TObject)
  private
    FLocker: TCriticalSection;
    FHashList: THashedStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure DeleteClient(Id: string); overload;
    procedure DeleteClient(Index: Integer); overload;
    procedure Connections(var Connections: TDSConnectionsEx);
    function AddClient(Client: TDSConnection): Integer;
    function Connection(Id: string): Integer; overload;
    function Connection(Index: Integer): TDSConnection; overload;
    function Count: Integer;
  end;

implementation

// class TMisc

class function TDSMisc.TimeUnix: Int64;
begin
  Result := DateTimeToUnix(Now);
end;

class function TDSMisc.TickCount: Cardinal;
begin
{$IF CompilerVersion >= 31.0}
  Result := TThread.GetTickCount;
{$ELSE}
  Result := Windows.GetTickCount;
{$IFEND}
end;

// class TDSPacket

constructor TDSPacket.Create;
begin
  inherited Create;
  PacketType := pt_HeartBeat;
  Id := 0;
  OrderId := 0;
  Confirm := False;
  CurSize := 0;
  TotalSize := 0;
  SetLength(Data, 0);
end;

destructor TDSPacket.Destroy;
begin
  SetLength(Data, 0);
  inherited Destroy;
end;

// class TDSQueue

constructor TDSQueue.Create;
begin
  inherited Create;
  FList := TObjectList<TDSPacket>.Create;
  FLocker := TCriticalSection.Create;
end;

destructor TDSQueue.Destroy;
begin
  FList.Free;
  FLocker.Free;
  inherited Destroy;
end;

procedure TDSQueue.Delete(Index: Integer);
begin
  FLocker.Enter;
  try
    FList.Delete(Index);
  finally
    FLocker.Leave;
  end;
end;

procedure TDSQueue.Delete;
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

procedure TDSQueue.DeleteOf(PacketId: Int64);
var
  I: Integer;
begin
  FLocker.Enter;
  try
    for I := FList.Count - 1 downto 0 do
    begin
      if FList.Items[I].Id = PacketId then
      begin
        FList.Delete(I);
      end;
    end;
  finally
    FLocker.Leave;
  end;
end;

function TDSQueue.Push(Item: TDSPacket): Integer;
begin
  FLocker.Enter;
  try
    Result := FList.Add(Item);
  finally
    FLocker.Leave;
  end;
end;

function TDSQueue.Count: Integer;
begin
  FLocker.Enter;
  try
    Result := FList.Count;
  finally
    FLocker.Leave;
  end;
end;

function TDSQueue.Pop(Index: Integer): TDSPacket;
begin

  FLocker.Enter;
  try
    Result := nil;

    if FList.Count > Index then
    begin
      Result := FList.Items[Index];
    end;
  finally
    FLocker.Leave;
  end;
end;

function TDSQueue.Pop: TDSPacket;
begin
  FLocker.Enter;
  try
    Result := nil;
    if FList.Count > 0 then
    begin
      Result := FList.Items[0];
    end;
  finally
    FLocker.Leave;
  end;
end;

// class TDSConfirm
constructor TDSConfirm.Create(APacketId: Int64; AOrderId: Integer);
begin
  Id := APacketId;
  OrderId := AOrderId;
  Tick := TDSMisc.TickCount;
  FComplete := False;
end;

// class TDSClient

constructor TDSConnection.Create;
begin
  inherited Create;
  FConfirmTick := TDSMisc.TickCount;
  FPacketId := 0;
  FRemoteAddr := '';
  FRemotePort := 0;
  FTick := TDSMisc.TickCount;
  FId := '';
  FConnected := False;
  FDisconnect := False;
  FSendQueue := TDSQueue.Create;
  FRecvQueue := TDSQueue.Create;
  FRecvConfirm := TDSConfirms.Create;
  FLocker := TCriticalSection.Create;
end;

destructor TDSConnection.Destroy;
begin
  FSendQueue.Free;
  FRecvQueue.Free;
  FRecvConfirm.Free;
  FLocker.Free;
  inherited Destroy;
end;

procedure TDSConnection.TickMark;
begin
  FTick := TDSMisc.TickCount;
end;

procedure TDSConnection.PostROBytes(Data: TBytes);
var
  Packet: TDSPacket;
  DataSize, ProcessSize, CurDataSize: Integer;
  OrderId, SendCount: Integer;
begin

  DataSize := Length(Data);

  if DataSize > UDP_MAX_PACKET_SIZE then
  begin

    SendCount := DataSize div UDP_MAX_PACKET_SIZE;
    ProcessSize := 0;

    for OrderId := 0 to SendCount do
    begin
      Inc(ProcessSize, UDP_MAX_PACKET_SIZE);
      CurDataSize := UDP_MAX_PACKET_SIZE;

      if ProcessSize > DataSize then
      begin
        CurDataSize := UDP_MAX_PACKET_SIZE - (ProcessSize - DataSize);
      end;

      Packet := TDSPacket.Create;
      Packet.PacketType := pt_ROBytes;
      Packet.Id := FPacketId;
      Packet.OrderId := OrderId;
      Packet.Confirm := False;
      Packet.TotalSize := DataSize;
      Packet.CurSize := CurDataSize;

      SetLength(Packet.Data, CurDataSize);
      Move(Data[OrderId * UDP_MAX_PACKET_SIZE], Packet.Data[0], CurDataSize);

      FSendQueue.Push(Packet);
    end;

  end
  else
  begin
    Packet := TDSPacket.Create;
    Packet.PacketType := pt_ROBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Confirm := False;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[0], Packet.Data[0], DataSize);

    FSendQueue.Push(Packet);
  end;

  Inc(FPacketId, 1);
end;

procedure TDSConnection.PostROString(Data: string);
var
  StrData: TBytes;
  Packet: TDSPacket;
  DataSize, ProcessSize, CurDataSize: Integer;
  OrderId, SendCount: Integer;
begin
  DataSize := Length(Data) * SizeOf(Char);

  if DataSize > UDP_MAX_PACKET_SIZE then
  begin

    SetLength(StrData, DataSize);
    Move(Data[1], StrData[0], DataSize);

    SendCount := DataSize div UDP_MAX_PACKET_SIZE;
    ProcessSize := 0;

    for OrderId := 0 to SendCount do
    begin
      Inc(ProcessSize, UDP_MAX_PACKET_SIZE);
      CurDataSize := UDP_MAX_PACKET_SIZE;

      if ProcessSize > DataSize then
      begin
        CurDataSize := UDP_MAX_PACKET_SIZE - (ProcessSize - DataSize);
      end;

      Packet := TDSPacket.Create;
      Packet.PacketType := pt_ROBytes;
      Packet.Id := FPacketId;
      Packet.OrderId := OrderId;
      Packet.Confirm := False;
      Packet.TotalSize := DataSize;
      Packet.CurSize := CurDataSize;

      SetLength(Packet.Data, CurDataSize);
      Move(StrData[OrderId * UDP_MAX_PACKET_SIZE], Packet.Data[0], CurDataSize);

      FSendQueue.Push(Packet);
    end;

  end
  else
  begin
    Packet := TDSPacket.Create;
    Packet.PacketType := pt_ROBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Confirm := False;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[1], Packet.Data[0], DataSize);

    FSendQueue.Push(Packet);
  end;

  Inc(FPacketId, 1);
end;

procedure TDSConnection.PostUBytes(Data: TBytes);
var
  Packet: TDSPacket;
  DataSize: Integer;
begin
  DataSize := Length(Data);

  if DataSize <= UDP_MAX_PACKET_SIZE then
  begin
    Packet := TDSPacket.Create;
    Packet.PacketType := pt_UBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Confirm := False;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[0], Packet.Data[0], DataSize);

    FSendQueue.Push(Packet);
    Inc(FPacketId, 1);
  end
  else
  begin
    raise Exception.Create('Unreliable Packet size must <= ' + IntToStr(UDP_MAX_PACKET_SIZE));
  end;
end;

procedure TDSConnection.PostUString(Data: string);
var
  Packet: TDSPacket;
  DataSize: Integer;
begin
  DataSize := Length(Data) * SizeOf(Char);

  if DataSize <= UDP_MAX_PACKET_SIZE then
  begin
    Packet := TDSPacket.Create;
    Packet.PacketType := pt_UString;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Confirm := False;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[1], Packet.Data[0], DataSize);

    FSendQueue.Push(Packet);
    Inc(FPacketId, 1);
  end
  else
  begin
    raise Exception.Create('Unreliable Packet size must <= ' + IntToStr(UDP_MAX_PACKET_SIZE));
  end;
end;

procedure TDSConnection.PostConfirm(PacketId: Int64; OrderId: Integer; PacketType: TPacketType);
var
  Packet: TDSPacket;
begin
  Packet := TDSPacket.Create;
  Packet.PacketType := PacketType;
  Packet.Id := PacketId;
  Packet.OrderId := OrderId;
  Packet.Confirm := True;
  Packet.TotalSize := 0;
  Packet.CurSize := 0;
  SetLength(Packet.Data, 0);
  FSendQueue.Push(Packet);
end;

procedure TDSConnection.OnConnected(Token: string);
begin

end;

procedure TDSConnection.OnHeartBeat;
begin

end;

procedure TDSConnection.OnDisconnect;
begin

end;

procedure TDSConnection.OnRecvROBytes(Data: TBytes);
begin

end;

procedure TDSConnection.OnRecvROString(Data: string);
begin

end;

procedure TDSConnection.OnRecvUBytes(Data: TBytes);
begin

end;

procedure TDSConnection.OnRecvUString(Data: string);
begin

end;

function TDSConnection.Recved(PacketId: Int64; OrderId: Integer): Boolean;
var
  I: Integer;
begin
  FLocker.Enter;
  Result := False;
  try

    for I := 0 to FRecvConfirm.Count - 1 do
    begin
      if (FRecvConfirm.Items[I].Id = PacketId) and (FRecvConfirm.Items[I].OrderId = OrderId) then
      begin
        Result := True;
        Break;
      end;
    end;

    if (FConfirmTick + UDP_TIME_OUT) <= TDSMisc.TickCount then
    begin
      FConfirmTick := TDSMisc.TickCount;

      for I := FRecvConfirm.Count - 1 downto 0 do
      begin
        if (FRecvConfirm.Items[I].Tick + UDP_TIME_OUT) <= TDSMisc.TickCount then
        begin
          if FRecvConfirm.Items[I].OrderId = 0 then
          begin
            FRecvConfirm.Delete(I);
          end
          else
          begin
            if FRecvConfirm.Items[I].Complete then
            begin
              FRecvConfirm.Delete(I);
            end;
          end;
        end;
      end;
    end;

  finally
    FLocker.Leave;
  end;
end;

procedure TDSConnection.ConfirmRecv(PacketId: Int64; OrderId: Integer);
begin
  FLocker.Enter;
  try
    FRecvConfirm.Add(TDSConfirm.Create(PacketId, OrderId));
  finally
    FLocker.Leave;
  end;
end;

procedure TDSConnection.SetConfirmComplete(PacketId: Int64);
var
  I: Integer;
begin
  FLocker.Enter;
  try
    for I := 0 to FRecvConfirm.Count - 1 do
    begin
      if FRecvConfirm.Items[I].Id = PacketId then
      begin
        FRecvConfirm.Items[I].Complete := True;
      end;
    end;
  finally
    FLocker.Leave;
  end;
end;

procedure TDSConnection.DeleteSendQueue(PacketId: Int64);
begin
  FSendQueue.DeleteOf(PacketId);
end;

procedure TDSConnection.SetAddr(Value: string);
begin
  FRemoteAddr := Value;
  SetId(FRemoteAddr + ':' + IntToStr(FRemotePort));
end;

procedure TDSConnection.SetPort(Value: Word);
begin
  FRemotePort := Value;
  SetId(FRemoteAddr + ':' + IntToStr(FRemotePort));
end;

procedure TDSConnection.SetTick(Value: Cardinal);
begin
  FTick := Value;
end;

procedure TDSConnection.SetId(Value: string);
begin
  FId := Value;
end;

procedure TDSConnection.SetConnected(Value: Boolean);
begin
  FConnected := Value;
end;

procedure TDSConnection.SetDisconnected(Value: Boolean);
begin
  FDisconnect := Value;
end;

procedure TDSConnection.SetToken(Value: string);
begin
  FToken := Value;
end;

// class TDSConnectionList

constructor TDSConnectionList.Create;
begin
  inherited Create;
  FLocker := TCriticalSection.Create;
  FHashList := THashedStringList.Create(True);
end;

destructor TDSConnectionList.Destroy;
begin
  FHashList.Free;
  FLocker.Free;
  inherited Create;
end;

procedure TDSConnectionList.Clear;
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

procedure TDSConnectionList.DeleteClient(Id: string);
begin
  DeleteClient(Connection(Id));
end;

procedure TDSConnectionList.DeleteClient(Index: Integer);
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

procedure TDSConnectionList.Connections(var Connections: TDSConnectionsEx);
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
        Connections.Add(TDSConnection(FHashList.Objects[I]));
      end;

    end;
  finally
    FLocker.Leave;
  end;
end;

function TDSConnectionList.AddClient(Client: TDSConnection): Integer;
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

function TDSConnectionList.Connection(Id: string): Integer;
begin
  FLocker.Enter;
  try
    Result := FHashList.IndexOfName(Id);
  finally
    FLocker.Leave;
  end;
end;

function TDSConnectionList.Connection(Index: Integer): TDSConnection;
begin
  FLocker.Enter;
  try
    Result := TDSConnection(FHashList.Objects[Index]);
  finally
    FLocker.Leave;
  end;
end;

function TDSConnectionList.Count: Integer;
begin
  FLocker.Enter;
  try
    Result := FHashList.Count;
  finally
    FLocker.Leave;
  end;
end;

end.

