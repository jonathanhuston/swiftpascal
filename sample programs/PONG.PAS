PROGRAM Pong;
USES Turbo3, Crt, Graph3;

{$R+}

CONST
     Rahmenfarbe = Yellow;
     Ballfarbe   = White;
     Textfarbe   = LightGray;
     Titel       = Magenta;
     Daneben     = 300;
     Mauer       = 500;
     Getroffen   = 800;
     Surprise    = 1000;
     Ball        = 111;
     Space       = 32;
     CR          = 13;
     RahmenZeich = 196;
     Stueck      = 222;
     Normal      = 21;
     Switch      = 80;

VAR
   Laenge      : ARRAY [1..2] OF 1..12;
   Punkte      : ARRAY [1..2] OF 0..100;
   Farbe       : ARRAY [1..2] OF 0..15;
   Name        : ARRAY [1..2] OF STRING [15];
   Position    : ARRAY [1..2] OF 2..24;
   Video       : ARRAY [1..25, 1..40, 1..2] OF CHAR ABSOLUTE $B800:0;
   Punktemax   : 0..100;
   Zeile,
   Spalte      : -1..1;
   X           : 1..40;
   Y           : 2..24;
   Tempo       : -1..25;
   Geraeusch   : BOOLEAN;
   i,j,k       : INTEGER;
   c           : CHAR;

FUNCTION GetKey : CHAR;
BEGIN
     Read(Kbd, c);
     GetKey := c;
END;

PROCEDURE CapsLockAus;
BEGIN
     Mem[0:1047] := Mem[0:1047] AND 191;
END;

PROCEDURE CapsUndNumLockEin;
BEGIN
     Mem[0:1047] := Mem[0:1047] OR 96;
END;

PROCEDURE CapsUndNumLockAus;
BEGIN
     Mem[0:1047] := Mem[0:1047] AND 159;
END;

FUNCTION Gewonnen : BOOLEAN;
BEGIN
     Gewonnen := (Punkte [1] = Punktemax) OR (Punkte [2] = Punktemax)
END;

PROCEDURE PrintAt (X,Y,ASC,Farbe:INTEGER);
BEGIN
     Video [Y,X,1] := Chr(Asc);
     Video [Y,X,2] := Chr(Farbe);
END;

PROCEDURE Cursor;
BEGIN
     PrintAt (1,1,Space,Black);
     GotoXY(1,1);
END;

PROCEDURE Ton (Frequenz,Laenge:INTEGER);
BEGIN
     IF Geraeusch THEN BEGIN
        Sound (Frequenz);
        Delay (Laenge);
        NoSound;
     END;
END;

PROCEDURE Cls;
BEGIN
     TextBackground (Black);
     ClrScr;
     TextColor (Titel);
     GotoXY (16,1);
     WriteLn ('P O N G !');
     TextColor (Textfarbe);
END;

PROCEDURE Start;
VAR s : STRING [3];

     FUNCTION Return : BOOLEAN;
     BEGIN
          Return := c = Chr(CR);
     END;

     FUNCTION Left : BOOLEAN;
     BEGIN
          Left := c = '4';
     END;

     FUNCTION Right : BOOLEAN;
     BEGIN
          Right := c = '6';
     END;

     PROCEDURE ChangeSpeed;
     BEGIN
          c := GetKey;
          IF Right AND (Tempo > -1) THEN Tempo := Pred (Tempo);
          IF Left AND (Tempo < 25) THEN Tempo := Succ (Tempo);
     END;

     PROCEDURE SpielerName;
     VAR p : INTEGER;
     BEGIN
          REPEAT
               Cls;
               FOR i := 1 TO 2 DO BEGIN
                    GotoXY (7, 7 * i);
                    TextColor (Farbe [i]);
                    WriteLn ('Player ', i ,', what is your name?');
                    GotoXY (7, 7* i + 2);
                    ReadLn (Name [i]);
                    p := Pos (' ', Name [i]);
                    IF p <> 0 THEN Name [i] := Copy (Name [i], i, p - 1);
               END
          UNTIL Name [1] <> Name [2];
     END;

     PROCEDURE Ein_Aus;
     BEGIN
          Cls;
          GotoXY (13,12);
          TextColor (Textfarbe);
          Write ('Sound? Y/N');
          Cursor;
          c := ' ';
          WHILE (c <> 'Y') AND (c <> 'N') DO c := GetKey;
          Geraeusch := c = 'Y';
     END;

     PROCEDURE Maximum;
     BEGIN
          i := Normal;
          Cls;
          GotoXY (13, 12);
          Write ('Maximum points');
          REPEAT
               GotoXY (18, 14);
               Write (i, ' ');
               Cursor;
               c := GetKey;
               IF Left AND (i > 1) THEN i := Pred (i);
               IF Right AND (i < 100) THEN i := Succ (i);
          UNTIL Return;
          Punktemax := i;
     END;

PROCEDURE Length;
     BEGIN
     Cls;
     FOR i := 1 TO 2 DO BEGIN
          j := 6;
               GotoXY (6,i * 5);
          TextColor (Textfarbe);
          Write ('Paddle length for ', Name [i]);
          TextColor (Farbe [i]);
     REPEAT
          GotoXY (6,i * 5 + 2);
          FOR k := 1 TO j DO Write (Chr(220))     ;
          Write (' ');
          Cursor;
          c := ' ';
          WHILE NOT (Left OR Right OR Return) DO c := GetKey;
          IF Left AND (j > 1) THEN j := Pred (j);
          IF Right AND (j  <  12)	THEN j := Succ (j);
     UNTIL Return;
     Laenge [i] := j;
     END;
END;

PROCEDURE Speed;
BEGIN
     Cls;
     GotoXY (11, 6);
     Write ('Ball speed');
     Cursor;
     c := ' ';
     Tempo := 10;
     REPEAT
          FOR i := 1 TO 40 DO BEGIN
               PrintAt (i,10,Ball,Ballfarbe);
               Delay ((Tempo+ 3) * 3);
               PrintAt (i,10,Space,Black);
               IF KeyPressed THEN ChangeSpeed;
          END;
          Ton (Mauer,10);
          FOR i:= 40 DOWNTO 1 DO BEGIN
               PrintAt (i, 10, Ball, Ballfarbe);
               Delay ((Tempo+ 3) * 3);
               PrintAt (i,10,Space,Black);
               IF KeyPressed THEN ChangeSpeed;
          END;
          Ton (Mauer,10);
     UNTIL Return;
END;

BEGIN
     TextMode (C40);
     GraphBackground (Black);
     Punkte [1] := 0;
     Punkte [2] := 0;
     CapsLockAus;
     SpielerName;
     CapsUndNumLockEin;
     Ein_Aus;
     Maximum;
     Length;
     Speed;
END;

PROCEDURE StatusZeile;
BEGIN
     GotoXY (14,25);
     TextColor (Farbe [1]);
     Write (Punkte [1]);
     GotoXY (26,25);
     TextColor (Farbe [2]);
     Write (Punkte [2]);
     Cursor;
END;

PROCEDURE Rahmen;
BEGIN
     Cls;
     TextColor (Rahmenfarbe);
     FOR i := 1 to 40 DO WRITE (Chr(RahmenZeich));
     GotoXY (1, 24);
     FOR i :=1 TO 40 DO WRITE (Chr(Rahmenzeich));
     StatusZeile;
END;

PROCEDURE Zeichnen (n: INTEGER);
BEGIN
     j := Pred (n) * 39 + 1;
     FOR i := 0 TO Laenge [n] - 1 DO PrintAt (j ,Position [n] + i, Stueck, Farbe [n]);
     i := Position [n]  + Laenge [n];
     IF i < 24 THEN PrintAt (j, i, Space, Black);
     IF Position [n] > 3 THEN PrintAt (j, Position [n] - 1, Space, Black);
END;

PROCEDURE ChangePos;
BEGIN
     c := GetKey;
     IF (c = 'P') AND (Position [2] >  3) THEN BEGIN
          Position [2] := Position [2] - 1;
          Zeichnen (2);
     END;
     IF (c = 'Q') AND (Position [1] > 3) THEN BEGIN
          Position [1] := Position [1] - 1;
          Zeichnen (1);
     END;
     IF (c = 'L') AND (Position [2] + Laenge [2] < 24) THEN BEGIN
          Position [2] := Position [2] + 1;
          Zeichnen (2);
     END;
     IF (c = 'A') AND (Position [1] + Laenge [1] < 24) THEN BEGIN
          Position [1] := Position [1]  +  1;
          Zeichnen (1);
     END;
END;

PROCEDURE Anstoss;
BEGIN
     Zeichnen (1);
     Zeichnen (2);
     X := Random (8)+17;
     Y := Random (16)+5;
     PrintAt (X,Y,Ball ,Ballfarbe);
     i := Random (2);
     IF i  =  0  THEN Zeile := -1  ELSE Zeile := 1;
     i := Random (2);
     IF i = 0 THEN Spalte := -1 ELSE Spalte := 1;
     c := 'L';
     REPEAT ChangePos UNTIL c = ' ';
END;

PROCEDURE Ballbewegung;
BEGIN
     REPEAT
          IF Random (Switch) = 0 THEN BEGIN
               Zeile := -Zeile;
               Ton (Surprise,10);
          END;
          IF KeyPressed THEN ChangePos;
          IF (Y + Zeile = 24) OR (Y + Zeile = 2) THEN BEGIN
               Ton (Mauer,10);
               Zeile := -Zeile;
          END;
          PrintAt (X,Y,Space,Black);
          X := X + Spalte;
          Y := Y + Zeile;
          PrintAt (X,Y,Ball,Ballfarbe);
          IF KeyPressed THEN ChangePos;
          Delay ((Tempo+ 3) * 4);
          IF (X + Spalte = 40) THEN BEGIN
               IF (Y <= Position [2] + Laenge [2]) AND (Y >= Position [2] - 1) THEN BEGIN
                    Ton (Getroffen,15);
                    Spalte := -1;
               END
               ELSE BEGIN
                    Ton (Daneben,25);
                    PrintAt (X,Y,Space,Black);
                    Punkte [1] := Punkte [1] + 1;
                    Statuszeile;
                    IF NOT Gewonnen THEN Anstoss;
               END
          END;
          IF KeyPressed THEN ChangePos;
          IF (X + Spalte = 1) THEN BEGIN
               IF (Y <= Position [1] + Laenge [1]) AND (Y >= Position [1] - 1) THEN begin
                    Ton (Getroffen, 15);
                    Spalte := 1;
               END
               ELSE BEGIN
                    Ton (Daneben,25);
                    PrintAt (X,Y, Space, Black);
                    Punkte [2] := Punkte [2] + 1;
                    StatusZeile;
                    IF NOT Gewonnen THEN Anstoss;
               END;
          END;
     UNTIL Gewonnen;
END;

PROCEDURE Ende;
VAR Sieger : STRING [15];
BEGIN
     Cls;
     FOR i := 1 to 2 DO BEGIN
          GotoXY (3, 5 + 5 * i);
          TextColor (Farbe [i]);
          Write (Name [i], ' score:');
          GotoXY (35, 5 + 5 * i);
          WriteLn (Punkte [i]:3);
          WriteLn;
     END;
     IF Punkte [1] > Punkte [2] THEN i := 1
     ELSE i := 2;
     Sieger := Name [i];
     TextColor (Farbe [i] + Blink);
     GotoXY (5, 20);
     Write ('Bravo, ', Sieger, '!');
     Cursor;
     c := 'L';
     WHILE c <> ' ' DO c := GetKey;
     Cls;
     GotoXY (12, 12);
     TextColor (Textfarbe);
     Write ('Play again? Y/N');
     Cursor;
     c := ' ';
     WHILE (c <> 'Y') AND (c <> 'N') DO c := GetKey;
END;

BEGIN
     Farbe [1] := LightRed;
     Farbe [2] := LightBlue;
     REPEAT
          Start;
          Rahmen;
          Position [1] := (25 - Laenge [1]) DIV 2;
          Position [2] := (25 - Laenge [2]) DIV 2;
          Anstoss;
          Ballbewegung;
          Ende;
          CapsUndNumLockAus;
     UNTIL c <> 'Y';
     TextMode (C80);
END.
