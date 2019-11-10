program DSUDP;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  dsudp.base in 'dsudp.base.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
