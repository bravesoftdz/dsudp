program DSUDP;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  dsudp.core.base in 'dsudp.core.base.pas',
  dsudp.core.socket in 'dsudp.core.socket.pas';

const
  Max_B_Size = 1024;

var
  Data, Data2: TBytes;
  I, SendCount, OrderId, DataSize, CurDataSize, ProcessSize: Integer;

begin
  try

    SetLength(Data, 2041);

    for I := 0 to 2041 do
    begin
      Data[I] := Random(100);
    end;

    for I := 0 to Length(Data) - 1 do
    begin
      Write(Data[I]);
      Write(',');
    end;

    WriteLn;
    Writeln;
    Writeln('DataSize ', Length(Data));

    DataSize := Length(Data);
    SendCount := DataSize div Max_B_Size;

    Writeln('SendCount ', SendCount);

    ProcessSize := 0;

    for OrderId := 0 to SendCount do
    begin

      Inc(ProcessSize, Max_B_Size);
      CurDataSize := Max_B_Size;

      if ProcessSize > DataSize then
      begin
        CurDataSize := Max_B_Size - (ProcessSize - DataSize);
      end;

      SetLength(Data2, CurDataSize);
      Move(Data[OrderId * Max_B_Size], Data2[0], CurDataSize);

      for I := 0 to CurDataSize - 1 do
      begin
        Write(Data2[I]);
        Write(' ');
      end;

      Writeln;
      Writeln('DataSize ', Length(Data2));

      Writeln

    end;

    Readln;
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

