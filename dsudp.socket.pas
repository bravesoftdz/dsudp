unit dsudp.socket;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  IdUDPServer, IdGlobal, IdSocketHandle, IdComponent, dsudp.base;
{$ELSE}

uses
  SysUtils, Classes, Windows, IniFiles, DateUtils, IdUDPServer, IdGlobal,
  IdSocketHandle, IdComponent, dsudp.base;
{$IFEND}

type
  TUDPSocket = class;

  TUDPSenderFrame = class(TThread)
  private
    FSocket: TIdUDPServer;
    FQueue: TUDPQueue;
    procedure DisposeQueue;
    procedure SendBuffer(Packet: TUDPPacket);
  protected
    procedure Execute; override;
  public
    constructor Create;
    procedure AddSendQueue(SendPacket: TUDPPacket);
    property Socket: TIdUDPServer read FSocket write FSocket;
    property SendQueue: TUDPQueue read FQueue write FQueue;
  end;

  TUDPHeartBeatFrame = class(TThread)
  private
    FSocket: TIdUDPServer;
    FClientList: TUDPClientList;
    procedure SendBuffer;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property ClientList: TUDPClientList read FClientList write FClientList;
    property Socket: TIdUDPServer read FSocket write FSocket;
  end;

  TUDPSocket = class(TObject)
  private
    FSocket: TIdUDPServer;
    FClientList: TUDPClientList;
    FADisconnect: Boolean;
    FUDPSenderFrame: TUDPSenderFrame;
    FUDPHeartBeatFrame: TUDPHeartBeatFrame;
    FPacketId: Integer;
    {$IF CompilerVersion >= 31.0}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    {$ELSE}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding: TIdSocketHandle);
    {$IFEND}
    procedure OnUDPReadEx(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure OnUDPException(AThread: TIdUDPListenerThread; ABinding: TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
    procedure OnAuthed(Addr: string; Port: Word; Succeed: Boolean; Reason: string);
    procedure OnDisconnected(Addr: string; Port: Word);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Auth(Addr: string; Port: Word; Token: string);
    procedure Disconnect(Client: TUDPClient);
    procedure SendROBytes(Client: TUDPClient; Data: TBytes);
    procedure SendROString(Client: TUDPClient; Data: string);
    procedure SendUBytes(Client: TUDPClient; Data: TBytes);
    procedure SendUString(Client: TUDPClient; Data: string);
    property Socket: TIdUDPServer read FSocket;
    property ClientList: TUDPClientList read FClientList;
  end;

implementation

// TUDPSenderFrame class

constructor TUDPSenderFrame.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FQueue := TUDPQueue.Create;
end;

procedure TUDPSenderFrame.AddSendQueue(SendPacket: TUDPPacket);
begin
  FQueue.Push(SendPacket);
end;

procedure TUDPSenderFrame.DisposeQueue;
var
  Packet: TUDPPacket;
  I: Integer;
  IndexList: TIndexList;
begin

  if FQueue.Count > 0 then
  begin

    IndexList := TIndexList.Create;

    try

      for I := 0 to FQueue.Count - 1 do
      begin
        Packet := FQueue.Pop;
        if (Packet <> nil) and (Assigned(Packet)) then
        begin
          SendBuffer(Packet);
          if (Packet.PacketType = pt_UBytes) or (Packet.PacketType = pt_UString) or (Packet.PacketType = pt_HeartBeat) then
          begin
            IndexList.Add(I);
          end;
          Sleep(1);
        end;
      end;

      IndexList.Sort;

      for I := IndexList.Count - 1 downto 0 do
      begin
        FQueue.Delete(IndexList.Items[I]);
      end;

    finally
      IndexList.Free;
    end;

  end
  else
  begin
    Sleep(10);
  end;
end;

procedure TUDPSenderFrame.SendBuffer(Packet: TUDPPacket);
var
  SendData: TBytesStream;
begin
  SendData := TBytesStream.Create;
  try
    SendData.Position := 0;
    SendData.WriteData(Integer(UDP_HEAD));
    SendData.WriteData(TPacketType(Packet.PacketType));
    SendData.WriteData(Int64(Packet.Id));
    SendData.WriteData(Integer(Packet.OrderId));
    SendData.WriteData(Integer(Packet.TotalSize));
    SendData.WriteData(Integer(Packet.CurSize));
    SendData.Write(Packet.Data[0], Packet.CurSize);
    SendData.Position := 0;

    FSocket.SendBuffer(Packet.PeerAddr, Packet.PeerPort, TIdBytes(SendData.Bytes));
  finally
    SendData.Free;
  end;

end;

procedure TUDPSenderFrame.Execute;
begin
  while not Terminated do
  begin
    DisposeQueue;
  end;
end;

// class TUDPHeartBeatFrame

constructor TUDPHeartBeatFrame.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FClientList := nil;
end;

procedure TUDPHeartBeatFrame.SendBuffer;
var
  SendData: TBytesStream;
  I, ClientCount: Integer;
  Client: TUDPClient;
begin
  SendData := TBytesStream.Create;
  try
    SendData.Position := 0;
    SendData.WriteData(Integer(UDP_HEAD));
    SendData.WriteData(TPacketType(pt_HeartBeat));
    SendData.WriteData(Int64(0));
    SendData.WriteData(Integer(0));
    SendData.WriteData(Integer(0));
    SendData.WriteData(Byte(0));
    SendData.Position := 0;

    ClientCount := FClientList.Count;

    for I := 0 to ClientCount - 1 do
    begin
      Client := FClientList.Client(I);
      FSocket.SendBuffer(Client.Addr, Client.Port, TIdBytes(SendData.Bytes));
    end;
  finally
    SendData.Free;
  end;

end;

procedure TUDPHeartBeatFrame.Execute;
begin
  while not Terminated do
  begin
    SendBuffer;
    Sleep(1000);
  end;
end;

// TUDPSocket class

constructor TUDPSocket.Create;
begin
  inherited Create;
  FSocket := TIdUDPServer.Create(nil);
  FSocket.OnUDPRead := OnUDPRead;
  FSocket.ThreadedEvent := True;
  FSocket.OnUDPException := OnUDPException;
  FSocket.OnStatus := OnStatus;
  FClientList := TUDPClientList.Create;
  FADisconnect := False;
  FPacketId := 0;
  FUDPSenderFrame := TUDPSenderFrame.Create;
  FUDPSenderFrame.Socket := FSocket;
  FUDPSenderFrame.Start;
  FUDPHeartBeatFrame := TUDPHeartBeatFrame.Create;
  FUDPHeartBeatFrame.Socket := FSocket;
  FUDPHeartBeatFrame.Start;
end;

destructor TUDPSocket.Destroy;
begin
  inherited Destroy;
end;

procedure TUDPSocket.Auth(Addr: string; Port: Word; Token: string);
var
  Packet: TUDPPacket;
begin
  Packet := TUDPPacket.Create;
  Packet.PeerAddr := Addr;
  Packet.PeerPort := Port;
  Packet.PacketType := pt_Auth;
  Packet.Id := FPacketId;
  Packet.OrderId := 0;
  Packet.TotalSize := Length(Token) * SizeOf(Char);
  Packet.CurSize := Packet.TotalSize;
  SetLength(Packet.Data, Packet.CurSize);
  Move(Token[1], Packet.Data[0], Packet.CurSize);
  Packet.Disposed := False;
  FUDPSenderFrame.SendQueue.Push(Packet);
  Inc(FPacketId, 1);
end;

procedure TUDPSocket.Disconnect(Client: TUDPClient);
var
  Packet: TUDPPacket;
begin
  FADisconnect := True;
  Packet := TUDPPacket.Create;
  Packet.PeerAddr := Client.Addr;
  Packet.PeerPort := Client.Port;
  Packet.PacketType := pt_Disconnect;
  Packet.Id := FPacketId;
  Packet.OrderId := 0;
  Packet.TotalSize := 0;
  Packet.CurSize := 0;
  SetLength(Packet.Data, 0);
  Packet.Disposed := False;
  FUDPSenderFrame.SendQueue.Push(Packet);
  Inc(FPacketId, 1);
end;

procedure TUDPSocket.SendROBytes(Client: TUDPClient; Data: TBytes);
var
  Packet: TUDPPacket;
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

      Packet := TUDPPacket.Create;
      Packet.PeerAddr := Client.Addr;
      Packet.PeerPort := Client.Port;
      Packet.PacketType := pt_ROBytes;
      Packet.Id := FPacketId;
      Packet.OrderId := OrderId;
      Packet.TotalSize := DataSize;
      Packet.CurSize := CurDataSize;

      SetLength(Packet.Data, CurDataSize);
      Move(Data[OrderId * UDP_MAX_PACKET_SIZE], Packet.Data[0], CurDataSize);

      Packet.Disposed := False;
      FUDPSenderFrame.SendQueue.Push(Packet);
    end;

  end
  else
  begin
    Packet := TUDPPacket.Create;
    Packet.PeerAddr := Client.Addr;
    Packet.PeerPort := Client.Port;
    Packet.PacketType := pt_ROBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[0], Packet.Data[0], DataSize);
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
  end;

  Inc(FPacketId, 1);
end;

procedure TUDPSocket.SendROString(Client: TUDPClient; Data: string);
var
  StrData: TBytes;
  Packet: TUDPPacket;
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

      Packet := TUDPPacket.Create;
      Packet.PeerAddr := Client.Addr;
      Packet.PeerPort := Client.Port;
      Packet.PacketType := pt_ROBytes;
      Packet.Id := FPacketId;
      Packet.OrderId := OrderId;
      Packet.TotalSize := DataSize;
      Packet.CurSize := CurDataSize;

      SetLength(Packet.Data, CurDataSize);
      Move(StrData[OrderId * UDP_MAX_PACKET_SIZE], Packet.Data[0], CurDataSize);

      Packet.Disposed := False;
      FUDPSenderFrame.SendQueue.Push(Packet);
    end;

  end
  else
  begin
    Packet := TUDPPacket.Create;
    Packet.PeerAddr := Client.Addr;
    Packet.PeerPort := Client.Port;
    Packet.PacketType := pt_ROBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[1], Packet.Data[0], DataSize);
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
  end;

  Inc(FPacketId, 1);
end;

procedure TUDPSocket.SendUBytes(Client: TUDPClient; Data: TBytes);
var
  Packet: TUDPPacket;
  DataSize: Integer;
begin
  DataSize := Length(Data);

  if DataSize <= UDP_MAX_PACKET_SIZE then
  begin
    Packet := TUDPPacket.Create;
    Packet.PeerAddr := Client.Addr;
    Packet.PeerPort := Client.Port;
    Packet.PacketType := pt_UBytes;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[0], Packet.Data[0], DataSize);
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
    Inc(FPacketId, 1);
  end
  else
  begin
    raise Exception.Create('Unreliable Packet size must <= ' + IntToStr(UDP_MAX_PACKET_SIZE));
  end;
end;

procedure TUDPSocket.SendUString(Client: TUDPClient; Data: string);
var
  Packet: TUDPPacket;
  DataSize: Integer;
begin
  DataSize := Length(Data) * SizeOf(Char);

  if DataSize <= UDP_MAX_PACKET_SIZE then
  begin
    Packet := TUDPPacket.Create;
    Packet.PeerAddr := Client.Addr;
    Packet.PeerPort := Client.Port;
    Packet.PacketType := pt_UString;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.TotalSize := DataSize;
    Packet.CurSize := DataSize;
    SetLength(Packet.Data, DataSize);
    Move(Data[1], Packet.Data[0], DataSize);
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
    Inc(FPacketId, 1);
  end
  else
  begin
    raise Exception.Create('Unreliable Packet size must <= ' + IntToStr(UDP_MAX_PACKET_SIZE));
  end;
end;

procedure TUDPSocket.OnAuthed(Addr: string; Port: Word; Succeed: Boolean; Reason: string);
var
  ClientId: string;
  Client: TUDPClient;
begin
  if Succeed then
  begin
    ClientId := Addr + ':' + IntToStr(Port);
    if FClientList.Client(ClientId) = -1 then
    begin
      Client := TUDPClient.Create;
      Client.TickMark;
      Client.Connected := True;
      Client.Addr := Addr;
      Client.Port := Port;
      FClientList.AddClient(Client);
    end;
  end;
end;

procedure TUDPSocket.OnDisconnected(Addr: string; Port: Word);
var
  ClientId: string;
  ClientIndex: Integer;
begin
  ClientId := Addr + ':' + IntToStr(Port);
  ClientIndex := FClientList.Client(ClientId);
  if ClientIndex <> -1 then
  begin
    FClientList.DeleteClient(ClientIndex);
  end;
end;

{$IF CompilerVersion >= 31.0}
procedure TUDPSocket.OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  OnUDPReadEx(AThread, AData, ABinding);
end;
{$ELSE}

procedure TUDPSocket.OnUDPRead(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  OnUDPReadEx(AThread, AData, ABinding);
end;
{$IFEND}

procedure TUDPSocket.OnUDPReadEx(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
begin

end;

procedure TUDPSocket.OnUDPException(AThread: TIdUDPListenerThread; ABinding: TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
begin

end;

procedure TUDPSocket.OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
begin

end;

end.

