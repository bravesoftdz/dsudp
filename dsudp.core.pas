unit dsudp.core;

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

  TDsUDPClient = class(TObject)
  private
    FRemoteAddr: string;
    FRemotePort: Word;
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
    procedure SendRBytes(Data: TBytes);
    property RemoteAddr: string read FRemoteAddr write SetAddr;
    property RemotePort: Word read FRemotePort write SetPort;
    property Tick: Cardinal read FTick write SetTick;
    property Id: string read FId write SetId;
    property Connected: Boolean read FConnected write SetConnected;
    property Token: string read FToken write SetToken;
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

// class TDsUDPClient

constructor TDsUDPClient.Create;
begin
  inherited Create;
  FRemoteAddr := '';
  FRemotePort := 0;
  FTick := TMisc.TickCount;
  FId := '';
  FConnected := False;
end;

destructor TDsUDPClient.Destroy;
begin
  inherited Destroy;
end;

procedure TDsUDPClient.TickMark;
begin
  FTick := TMisc.TickCount;
end;

procedure TDsUDPClient.SendRBytes(Data: TBytes);
begin

end;

procedure TDsUDPClient.SetAddr(Value: string);
begin
  FRemoteAddr := Value;
  SetId(FRemoteAddr + ':' + IntToStr(FRemotePort));
end;

procedure TDsUDPClient.SetPort(Value: Word);
begin
  FRemotePort := Value;
  SetId(FRemoteAddr + ':' + IntToStr(FRemotePort));
end;

procedure TDsUDPClient.SetTick(Value: Cardinal);
begin
  FTick := Value;
end;

procedure TDsUDPClient.SetId(Value: string);
begin
  FId := Value;
end;

procedure TDsUDPClient.SetConnected(Value: Boolean);
begin
  FConnected := Value;
end;

procedure TDsUDPClient.SetToken(Value: string);
begin
  FToken := Value;
end;

end.

