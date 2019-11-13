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

  TUDPSocket = class(TObject)
  private
    FSocket: TIdUDPServer;
    FClientList: TUDPClientList;
    FConnected: Boolean;
    FUDPSenderFrame: TUDPSenderFrame;
    FPacketId: Integer;
    {$IF CompilerVersion >= 31.0}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    {$ELSE}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding: TIdSocketHandle);
    {$IFEND}
    procedure OnUDPReadEx(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure OnUDPException(AThread: TIdUDPListenerThread; ABinding: TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect;
    procedure Auth(Token: string);
    property Socket: TIdUDPServer read FSocket;
    property ClientList: TUDPClientList read FClientList;
    property Connected: Boolean read FConnected;
  end;

implementation

// TUDPLogicFrame class

constructor TUDPSenderFrame.Create;
begin
  inherited Create(True);
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
    SendData.WriteData(Integer(Packet.Id));
    SendData.WriteData(Integer(Packet.OrderId));
    SendData.WriteData(Int64(Packet.Size));
    SendData.Write(Packet.Data[0], Packet.Size);
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
  FConnected := False;
  FPacketId := 0;
  FUDPSenderFrame := TUDPSenderFrame.Create;
  FUDPSenderFrame.Socket := FSocket;
  FUDPSenderFrame.Start;
end;

destructor TUDPSocket.Destroy;
begin
  inherited Destroy;
end;

procedure TUDPSocket.Connect;
var
  Packet: TUDPPacket;
begin
  Packet := TUDPPacket.Create;
  try
    Packet.PacketType := pt_Connect;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Size := 0;
    SetLength(Packet.Data, 0);
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
    Inc(FPacketId, 1);
  finally
    Packet.Free;
  end;
end;

procedure TUDPSocket.Auth(Token: string);
var
  Packet: TUDPPacket;
begin
  Packet := TUDPPacket.Create;
  try
    Packet.PacketType := pt_Auth;
    Packet.Id := FPacketId;
    Packet.OrderId := 0;
    Packet.Size := Length(Token) * SizeOf(Char);
    SetLength(Packet.Data, Length(Token) * SizeOf(Char));
    Move(Token[1], Packet.Data[0], Length(Token) * SizeOf(Char));
    Packet.Disposed := False;
    FUDPSenderFrame.SendQueue.Push(Packet);
    Inc(FPacketId, 1);
  finally
    Packet.Free;
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

