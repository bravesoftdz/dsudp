program DSUDP;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  dsudp.base in 'dsudp.base.pas',
  dsudp.socket in 'dsudp.socket.pas';

var
  Data: TBytes;
  Token: string;

begin
  try

    Token := 'ABCDEFG';

    SetLength(Data, Length(Token) * SizeOf(Char));
    Move(Token[1], Data[0], Length(Token) * SizeOf(Char));

    Readln;
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

