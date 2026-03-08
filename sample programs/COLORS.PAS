PROGRAM Colors;
USES Crt;
VAR i : INTEGER;
BEGIN
    ClrScr;
    FOR i := 0 TO 15 DO BEGIN
        TextColor(i);
        GotoXY(10, i + 3);
        Write('Color ', i, ': This is a test');
    END;
    TextColor(Yellow);
    GotoXY(20, 22);
    Write('Press any key to exit...');
END.
