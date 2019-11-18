program DSUDP;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  dsudp.core.base in 'dsudp.core.base.pas',
  dsudp.core.logic in 'dsudp.core.logic.pas',
  dsudp.core.socket in 'dsudp.core.socket.pas';

const
  Max_B_Size = 1024;

var
  DS: TDSSocket;

begin
  try

    DS := TDSSocket.Create;
    DS.Connect('127.0.0.1', 27015);

    Readln;
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

