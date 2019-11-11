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

  TUDPLogicFrame = class(TThread)
  private
    FUDPSendQueue: TUDPQueue;
    FUDPRecvQueue: TUDPQueue;
    FUDPSocket: TUDPSocket;
    procedure OnFrame;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property UDPSocket: TUDPSocket read FUDPSocket write FUDPSocket;
  end;

  TUDPSocket = class(TObject)
  private
    FSocket: TIdUDPServer;
    FClients: TUDPClientList;
    FConnected: Boolean;
    FAccount: string;
    FPassword: string;
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
  end;

implementation

// TUDPLogicFrame class

constructor TUDPLogicFrame.Create;
begin
  inherited Create(True);
  FUDPSendQueue := TUDPQueue.Create(True);
  FUDPRecvQueue := TUDPQueue.Create(True);
end;

procedure TUDPLogicFrame.OnFrame;
begin

end;

procedure TUDPLogicFrame.Execute;
begin
  while not Terminated do
  begin
    OnFrame;
    Sleep(1);
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
  FClients := TUDPClientList.Create;
  FConnected := False;
  FAccount := '';
  FPassword := '';
end;

destructor TUDPSocket.Destroy;
begin
  inherited Destroy;
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

