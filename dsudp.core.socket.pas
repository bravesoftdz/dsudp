unit dsudp.core.socket;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  System.SyncObjs, IdUDPServer, IdGlobal, IdSocketHandle, IdComponent,
  dsudp.core.base, dsudp.core.logic;
{$ELSE}

uses
  SysUtils, Classes, Windows, IniFiles, DateUtils, SyncObjs, IdUDPServer,
  IdGlobal, IdSocketHandle, IdComponent, dsudp.core.base, dsudp.core.logic;
{$IFEND}

type
  TDSSocket = class(TObject)
  private
    FSocket: TIdUDPServer;
    FSendFrame: TDSSendFrame;
    FRecvFrame: TDSRecvFrame;
    FHeartBeatFrame: TDSHeartBeatFrame;
    FConnections: TDSConnectionList;
    FConnectQueue: TDSConnectQueue;
    FConnectTimer: TDSTimer;
    FConnectLocker: TCriticalSection;
    {$IF CompilerVersion >= 31.0}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    {$ELSE}
    procedure OnUDPRead(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding: TIdSocketHandle);
    {$IFEND}
    procedure OnUDPReadEx(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure OnUDPException(AThread: TIdUDPListenerThread; ABinding: TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
    procedure OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
    procedure DisposeConnecting;
    procedure DoConnect(Addr: string; Port: Word; Confirm: Boolean);
    procedure DoConnectConfirm(Addr: string; Port: Word);
    procedure OnConnected(Id: string);
    procedure OnConnectFail(Id: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(Addr: string; Port: Word);
  end;

implementation

// TUDPSocket class

constructor TDSSocket.Create;
begin
  inherited Create;
  FSocket := TIdUDPServer.Create(nil);
  FSocket.OnUDPRead := OnUDPRead;
  FSocket.ThreadedEvent := True;
  FSocket.OnUDPException := OnUDPException;
  FSocket.OnStatus := OnStatus;

  FConnections := TDSConnectionList.Create;

  FSendFrame := TDSSendFrame.Create;
  FRecvFrame := TDSRecvFrame.Create;
  FHeartBeatFrame := TDSHeartBeatFrame.Create;

  FSendFrame.Socket := FSocket;
  FHeartBeatFrame.Socket := FSocket;
  FSendFrame.Connections := FConnections;
  FRecvFrame.Connections := FConnections;
  FHeartBeatFrame.Connections := FConnections;

  FSendFrame.Start;
  FRecvFrame.Start;
  FHeartBeatFrame.Start;

  FConnectLocker := TCriticalSection.Create;

  FConnectQueue := TDSConnectQueue.Create;
  FConnectTimer := TDSTimer.Create;
  FConnectTimer.Method := DisposeConnecting;
  FConnectTimer.Elapse := 1000;
  FConnectTimer.Start;

  FSocket.Active := True;
end;

destructor TDSSocket.Destroy;
begin
  FSendFrame.Terminate;
  FRecvFrame.Terminate;
  FHeartBeatFrame.Terminate;
  inherited Destroy;
end;

{$IF CompilerVersion >= 31.0}
procedure TDSSocket.OnUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  OnUDPReadEx(AThread, AData, ABinding);
end;
{$ELSE}

procedure TDSSocket.OnUDPRead(AThread: TIdUDPListenerThread; AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  OnUDPReadEx(AThread, AData, ABinding);
end;
{$IFEND}

procedure TDSSocket.OnUDPReadEx(AThread: TIdUDPListenerThread; const AData: TIdBytes; ABinding: TIdSocketHandle);
begin

end;

procedure TDSSocket.Connect(Addr: string; Port: Word);
var
  ConnectInfo: TDSConnectInfo;
begin
  FConnectLocker.Enter;
  try
    ConnectInfo := TDSConnectInfo.Create;
    ConnectInfo.Ip := Addr;
    ConnectInfo.Port := Port;
    ConnectInfo.Tick := TDSMisc.TickCount;
    FConnectQueue.Add(ConnectInfo);
  finally
    FConnectLocker.Leave;
  end;
end;

procedure TDSSocket.OnConnected(Id: string);
begin
  Writeln(Id, ' connected.');
end;

procedure TDSSocket.OnConnectFail(Id: string);
begin
  Writeln('Connect to ', Id, ' Failed');
end;

procedure TDSSocket.DoConnect(Addr: string; Port: Word; Confirm: Boolean);
var
  SendData: TBytesStreamEx;
  DataBytes: TBytes;
begin
  SendData := TBytesStreamEx.Create;
  try
    SendData.Position := 0;
{$IF CompilerVersion >= 31.0}
    SendData.WriteData(Integer(UDP_HEAD));
    SendData.WriteData(TPacketType(pt_Connect));
    SendData.WriteData(Int64(0));
    SendData.WriteData(Integer(0));
    SendData.WriteData(Boolean(Confirm));
    SendData.WriteData(Integer(0));
    SendData.WriteData(Integer(0));
    SendData.WriteData(Byte(0));
{$ELSE}
    SendData.WriteEx(Integer(UDP_HEAD), SizeOf(Integer));
    SendData.WriteEx(TPacketType(pt_Connect), SizeOf(TPacketType));
    SendData.WriteEx(Int64(0), SizeOf(Int64));
    SendData.WriteEx(Integer(0), SizeOf(Integer));
    SendData.WriteEx(Boolean(Confirm), SizeOf(Boolean));
    SendData.WriteEx(Integer(0), SizeOf(Integer));
    SendData.WriteEx(Integer(0), SizeOf(Integer));
    SendData.WriteEx(Byte(0), SizeOf(Byte));
{$IFEND}
    SendData.Position := 0;

    SetLength(DataBytes, SendData.Size);
    try
      Move(SendData.Bytes[0], DataBytes[0], SendData.Size);
      FSocket.SendBuffer(Addr, Port, TIdBytes(DataBytes));
    finally
      SetLength(DataBytes, 0);
    end;

  finally
    SendData.Free;
  end;
end;

procedure TDSSocket.DoConnectConfirm(Addr: string; Port: Word);
var
  I: Integer;
  ConnectInfo: TDSConnectInfo;
begin
  FConnectLocker.Enter;
  try
    for I := FConnectQueue.Count - 1 to 0 do
    begin
      ConnectInfo := FConnectQueue.Items[I];

      if (ConnectInfo.Ip = Addr) and (ConnectInfo.Port = Port) then
      begin
        OnConnected(Addr + ':' + IntToStr(Port));
        FConnectQueue.Delete(I);
        Break;
      end;
    end;
  finally
    FConnectLocker.Leave;
  end;
end;

procedure TDSSocket.DisposeConnecting;
var
  I: Integer;
  ConnectInfo: TDSConnectInfo;
begin
  FConnectLocker.Enter;
  try

    for I := FConnectQueue.Count - 1 downto 0 do
    begin
      ConnectInfo := FConnectQueue.Items[I];
      if (ConnectInfo.Tick + UDP_TIME_OUT) <= TDSMisc.TickCount then
      begin
        OnConnectFail(ConnectInfo.Ip + ':' + IntToStr(ConnectInfo.Port));
        FConnectQueue.Delete(I);
      end
      else
      begin
        DoConnect(ConnectInfo.Ip, ConnectInfo.Port, False);
      end;
    end;
  finally
    FConnectLocker.Leave;
  end;

end;

procedure TDSSocket.OnUDPException(AThread: TIdUDPListenerThread; ABinding: TIdSocketHandle; const AMessage: string; const AExceptionClass: TClass);
begin
//  Writeln(AMessage);
end;

procedure TDSSocket.OnStatus(ASender: TObject; const AStatus: TIdStatus; const AStatusText: string);
begin
//  Writeln(AStatusText);
end;

end.

