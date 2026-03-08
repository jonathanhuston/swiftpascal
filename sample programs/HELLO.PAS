PROGRAM Hello;
USES Crt;
VAR c : CHAR;
BEGIN
    ClrScr;
    TextColor(14);
    GotoXY(30, 12);
    WriteLn('Hello, World!');
    TextColor(7);
    GotoXY(25, 14);
    Write('Press any key...');
    Read(Kbd, c);
END.
