program DSUDP;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  dsudp.base in 'dsudp.base.pas',
  dsudp.socket in 'dsudp.socket.pas';

begin
  try
    Writeln(SizeOf(TUDPPacket));
    Readln;
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
