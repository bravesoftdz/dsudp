unit dsudp.core.socket;

interface

{$IF CompilerVersion >= 31.0}
uses
  System.SysUtils, System.Classes, System.IniFiles, System.DateUtils,
  IdUDPServer, IdGlobal, IdSocketHandle, IdComponent, dsudp.core.base;
{$ELSE}

uses
  SysUtils, Classes, Windows, IniFiles, DateUtils, IdUDPServer, IdGlobal,
  IdSocketHandle, IdComponent, dsudp.core.base;
{$IFEND}

type
  TDSSendFrame = class(TThread)
  private
    FSocket: TIdUDPServer;
    FDSConnectionList: TDSConnectionList;
    procedure SendBuffer(Connection: TDSConnection; Packet: TDSPacket);
    procedure DisposeConnections;
    function DisposeQueue(Connection: TDSConnection): Integer;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property Socket: TIdUDPServer read FSocket write FSocket;
    property Connections: TDSConnectionList read FDSConnectionList write FDSConnectionList;
  end;

  TDSRecvFrame = class(TThread)
  private
    FDSConnectionList: TDSConnectionList;
    procedure DisposeConnections;
    procedure VerifyPacket(Connection: TDSConnection; PacketId: Int64);
    procedure DisposePacket(Connection: TDSConnection; PacketIndexs: TPacketIndexs);
    function SetupPacket(Connection: TDSConnection; PacketId: Int64): Boolean;
    function DisposeQueue(Connection: TDSConnection): Integer;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property Connections: TDSConnectionList read FDSConnectionList write FDSConnectionList;
  end;

implementation

// class TDSSendFrame

constructor TDSSendFrame.Create;
begin
  inherited Create(True);
  FSocket := nil;
  FDSConnectionList := nil;
  FreeOnTerminate := True;
end;

procedure TDSSendFrame.SendBuffer(Connection: TDSConnection; Packet: TDSPacket);
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
    SendData.WriteData(Boolean(Packet.Confirm));
    SendData.WriteData(Integer(Packet.TotalSize));
    SendData.WriteData(Integer(Packet.CurSize));
    SendData.Write(Packet.Data[0], Packet.CurSize);
    SendData.Position := 0;

    FSocket.SendBuffer(Connection.RemoteAddr, Connection.RemotePort, TIdBytes(SendData.Bytes));
  finally
    SendData.Free;
  end;

end;

procedure TDSSendFrame.DisposeConnections;
var
  I, QueueCount: Integer;
  Connections: TDSConnectionsEx;
begin
  QueueCount := 0;

  if (FDSConnectionList <> nil) and (FSocket <> nil) then
  begin
    Connections := TDSConnectionsEx.Create;
    try
      FDSConnectionList.Connections(Connections);

      for I := 0 to Connections.Count - 1 do
      begin
        QueueCount := QueueCount + DisposeQueue(Connections.Items[I]);
      end;
    finally
      Connections.Free;
    end;
  end;

  if QueueCount = 0 then
  begin
    Sleep(10);
  end;
end;

function TDSSendFrame.DisposeQueue(Connection: TDSConnection): Integer;
var
  I: Integer;
  Packet: TDSPacket;
  Indexs: TIndexs;
begin

  Result := 0;

  if Connection.Connected then
  begin
    Result := Connection.SendQueue.Count;

    if Result > 0 then
    begin

      Indexs := TIndexs.Create;
      try

        for I := 0 to Result - 1 do
        begin
          Packet := Connection.SendQueue.Pop(I);
          if (Packet <> nil) and (Assigned(Packet)) then
          begin
            SendBuffer(Connection, Packet);
            if (Packet.PacketType = pt_UBytes) or (Packet.PacketType = pt_UString) or (Packet.PacketType = pt_HeartBeat) then
            begin
              Indexs.Add(I);
            end;
            Sleep(1);
          end;
        end;

        Indexs.Sort;

        for I := Indexs.Count - 1 downto 0 do
        begin
          Connection.SendQueue.Delete(Indexs.Items[I]);
        end;

      finally
        Indexs.Free;
      end;
    end;
  end;
end;

procedure TDSSendFrame.Execute;
begin
  while not Terminated do
  begin
    DisposeConnections;
  end;
end;

// class TDSRecvFrame

procedure TDSRecvFrame.DisposeConnections;
var
  I, QueueCount: Integer;
  Connections: TDSConnectionsEx;
begin
  QueueCount := 0;

  if FDSConnectionList <> nil then
  begin
    Connections := TDSConnectionsEx.Create;
    try
      FDSConnectionList.Connections(Connections);

      for I := 0 to Connections.Count - 1 do
      begin
        QueueCount := QueueCount + DisposeQueue(Connections.Items[I]);
      end;
    finally
      Connections.Free;
    end;
  end;

  if QueueCount = 0 then
  begin
    Sleep(1);
  end;
end;

procedure TDSRecvFrame.VerifyPacket(Connection: TDSConnection; PacketId: Int64);
var
  I: Integer;
  Packet: TDSPacket;
  PacketString: string;
  PacketBytes: TBytes;
  Indexs: TIndexs;
begin

  Indexs := TIndexs.Create;
  try

    for I := 0 to Connection.RecvQueue.Count - 1 do
    begin
      Packet := Connection.RecvQueue.Pop(I);
      if (Packet <> nil) and (Assigned(Packet)) then
      begin
        if Packet.Id = PacketId then
        begin
          if Packet.Confirm then
          begin
            if not Connection.Recved(Packet.Id, Packet.OrderId) then
            begin
              Connection.ConfirmRecv(Packet.Id, Packet.OrderId);
              Connection.DeleteSendQueue(Packet.Id);
            end;
            Indexs.Add(I);
          end
          else
          begin
            if Packet.TotalSize = Packet.CurSize then
            begin
              if (Packet.PacketType <> pt_HeartBeat) and (Packet.PacketType <> pt_UBytes) and (Packet.PacketType <> pt_UString) then
              begin
                Connection.PostConfirm(Packet.Id, Packet.OrderId, Packet.PacketType);
              end;

              if not Connection.Recved(Packet.Id, Packet.OrderId) then
              begin
                Connection.ConfirmRecv(Packet.Id, Packet.OrderId);

                case Packet.PacketType of
                  pt_Auth:
                    begin
                      SetLength(PacketString, Packet.TotalSize);
                      try
                        Move(Packet.Data[0], PacketString[1], Packet.TotalSize);
                        if PacketString = Connection.Token then
                        begin
                          Connection.Connected := True;
                          Connection.OnConnected(PacketString);
                        end;
                      finally
                        SetLength(PacketString, 0);
                      end;
                    end;
                  pt_HeartBeat:
                    begin
                      Connection.TickMark;
                      Connection.OnHeartBeat;
                    end;
                  pt_Disconnect:
                    begin
                      Connection.Connected := False;
                      Connection.OnDisconnect;
                    end;
                  pt_ROBytes:
                    begin
                      SetLength(PacketBytes, Packet.TotalSize);
                      try
                        Move(Packet.Data[0], PacketBytes[0], Packet.TotalSize);
                        Connection.OnRecvROBytes(PacketBytes);
                      finally
                        SetLength(PacketBytes, 0);
                      end;
                    end;
                  pt_ROString:
                    begin
                      SetLength(PacketString, Packet.TotalSize);
                      try
                        Move(Packet.Data[0], PacketString[1], Packet.TotalSize);
                        Connection.OnRecvROString(PacketString);
                      finally
                        SetLength(PacketString, 0);
                      end;
                    end;
                  pt_UBytes:
                    begin
                      SetLength(PacketBytes, Packet.TotalSize);
                      try
                        Move(Packet.Data[0], PacketBytes[0], Packet.TotalSize);
                        Connection.OnRecvUBytes(PacketBytes);
                      finally
                        SetLength(PacketBytes, 0);
                      end;
                    end;
                  pt_UString:
                    begin
                      SetLength(PacketString, Packet.TotalSize);
                      try
                        Move(Packet.Data[0], PacketString[1], Packet.TotalSize);
                        Connection.OnRecvUString(PacketString);
                      finally
                        SetLength(PacketString, 0);
                      end;
                    end;
                end;
              end;

              Indexs.Add(I);

            end
            else if Packet.TotalSize > Packet.CurSize then
            begin
              Connection.PostConfirm(Packet.Id, Packet.OrderId, Packet.PacketType);

              if not Connection.Recved(Packet.Id, Packet.OrderId) then
              begin
                Connection.ConfirmRecv(Packet.Id, Packet.OrderId);

                if SetupPacket(Connection, Packet.Id) then
                begin
                  Connection.SetConfirmComplete(Packet.Id);
                  Connection.RecvQueue.DeleteOf(Packet.Id);
                end;
              end;
            end;
          end;
        end;
      end;
    end;

    Indexs.Sort;

    for I := Indexs.Count - 1 downto 0 do
    begin
      Connection.RecvQueue.Delete(Indexs.Items[I]);
    end;

  finally
    Indexs.Free;
  end;
end;

function TDSRecvFrame.SetupPacket(Connection: TDSConnection; PacketId: Int64): Boolean;
begin
  // �ֿ��
  Result := False;
end;

procedure TDSRecvFrame.DisposePacket(Connection: TDSConnection; PacketIndexs: TPacketIndexs);
var
  I: Integer;
begin
  PacketIndexs.Sort;
  for I := 0 to PacketIndexs.Count - 1 do
  begin
    VerifyPacket(Connection, PacketIndexs.Items[I]);
  end;
end;

function TDSRecvFrame.DisposeQueue(Connection: TDSConnection): Integer;
var
  I: Integer;
  Packet: TDSPacket;
  PacketIndexs: TPacketIndexs;
begin
  Result := Connection.RecvQueue.Count;

  if Result > 0 then
  begin

    PacketIndexs := TPacketIndexs.Create;
    try

      for I := 0 to Result - 1 do
      begin
        Packet := Connection.RecvQueue.Pop(I);
        if (Packet <> nil) and (Assigned(Packet)) then
        begin
          if PacketIndexs.IndexOf(Packet.Id) = -1 then
          begin
            PacketIndexs.Add(Packet.Id);
          end;
        end;
      end;

      DisposePacket(Connection, PacketIndexs);

    finally
      PacketIndexs.Free;
    end;
  end;
end;

procedure TDSRecvFrame.Execute;
begin
  while not Terminated do
  begin
    DisposeConnections;
  end;
end;

constructor TDSRecvFrame.Create;
begin
  inherited Create(True);
  FDSConnectionList := nil;
  FreeOnTerminate := True;
end;

end.
