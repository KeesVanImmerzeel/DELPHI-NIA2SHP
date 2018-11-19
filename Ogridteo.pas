unit Ogridteo;
{
unit
   voor
   -  basisdata opbouw van de grid.teo bestand;
   -  ado-formaat inlezen --> GetValue, GetFormaat

}

interface

uses
   Sysutils,Classes,CheckNumeric,Dialogs,Messages;

type
  PBestanden =^TBestanden;
  TBestanden = Record
    FileIn,            {flairs.flo}
    FileUit,
    VeldNamenRegel : string;
    FileLog: string;
    GoOn: Boolean;
  END;


  PTriAantal = ^TTriAantal;
  TTriAantal = record
      nodes,
      elements,
      fixedpoints,
      sources,
      rivers,
      rivernodes,
      boundarynodes : integer;
  end;


{
NUMBER NODES          =11955
NUMBER ELEMENTS       =23757
NUMBER FIXED POINTS   =    0
NUMBER SOURCES        =   28
NUMBER RIVERS         =   56
NUMBER RIVER NODES    = 2504
NUMBER BOUNDARY NODES =  151
 }

  PTriNode = ^TTriNode;
  TTriNode = record
    Id     : integer;
    Xc     : Double;
    Yc     : Double;
    Rand   : byte;
    CelNr  : longint;
    CelWaarde: real;
    SubElementen :string;
    Source : byte; {0 niet / 1 wel}
    SourceNr: longint;
    //CONSTRUCTOR Init(N:integer;S:longint;CW:real);
  END;

  PTriRange = ^TTriRange;
  TTriRange = record
   minX,
   maxX,
   minY,
   maxY : double
  end;


  PTriElement = ^TTriElement;
  TTriElement = record
      node1,
      node2 ,
      node3: integer;
  end;

  ary = array of integer;

   FUNCTION TriCompareCelnr(Item1, Item2: Pointer): Longint;
   FUNCTION TriCompareId(Key1, Key2:pointer):integer;
   Function GetValue(tekstregel:string):integer;
   Procedure GetFormaat(Formaat:string; var ValNrs:word; var ValType:string; var ValLen, ValDec:word);
   FUNCTION ReadGridTeoHeader(bestandsnaam:string):PTriAantal;
   //Procedure ReadAdoFile(bestandsnaam:string;var NodeList:TList);
   //PROCEDURE quick_sort2(VAR x: ary; n: Integer);


{--------------------------------------------------------------------
 ten behoeve van de calibratie van het topsysteem

}
   Const GHGokay1 = [10,20,22,25,30,32,35,50,52,55];
   Const GHGokay2 = [40,42,60];
   Const GHGokay3 = [45,70];
   Const GLGokay1 = [20,22,25];
   Const GLGokay2 = [30,32,35,40,42,45];
   Const GLGokay3 = [50,52,55,60,70];

   Const minSC1: single = 0.10;
   Const maxSC1: single = 0.35;
   Const minDeklaagWeerstand = 15;
   Const maxDeklaagWeerstand = 5000;
   Const minDrainageWeerstand = 10;
   Const maxDrainageWeerstand = 1000;
   Const minInfiltratieFactor = 1;
   Const maxInfiltratieFactor = 2;
   Const GeenAanvoer = 10000; {voor gebieden waar geen wateraanvoermogelijk is}

   Const VeelNeerslagOverschot = 0.0033; {neerslagoverschot m/d voor de
                                          bepaling van drainage/delaagweerstand}
   const  maxVelden = 10 ; {aantal velden dat voor de calibratie wordt ingelezen}

  type

  PCalibRec = ^TCalibRec;
  TCalibRec = record
      Select:single;
      GtBodemkrt,
      GtBerekend :integer;
      Mv,
      CL1,
      RP4,
      RP7,
      SC1,
      WP,
      ZP : single;
      OpmStr:string;
   end;

   POpmArray = ^TOpmArray;
   TOpmArray = array[0..14] of integer;

   POpmRec = ^TOpmRec;
   TOpmRec = record
      m0,m1,m2,m3,m4,m5,m6,m7,m8,m9,m10,m11,m12,m13 : integer;
   end;

   var
      CalibList : TList;
      Notes : TOPMarray;
      CurNotes: POPMarray;

   Procedure ReadCalibFiles(var Bestanden:PBestanden; var CalibList:TList);
   //Procedure UpdataCalibFiles(var CalibList);
   Function GHGstatus(CalibRec:PCalibRec):Boolean;
   Function GLGstatus(CalibRec:PCalibRec):Boolean;
   Procedure UpdataCalibRec(var CalibRec:PCalibRec; GHG,GLG:boolean);
   Procedure ExportCalibUpdates(Bestanden:PBestanden; var CalibList:TList);

{--------------------------------------------------------------------
}

implementation

  FUNCTION TriCompareCelnr(Item1, Item2: Pointer): Longint;
   begin
      if PTriNode(Item1)^.CelNr<PTriNode(Item2)^.CelNr then Result:=-1;
      if PTriNode(Item1)^.CelNr=PTriNode(Item2)^.CelNr then Result:=0;
      if PTriNode(Item1)^.CelNr>PTriNode(Item2)^.CelNr then Result:=+1;
   end;

  //TVerzamelNode.
  FUNCTION TriCompareId(Key1, Key2:pointer):integer;
  //Type
  //  Pinteger=^integer;
  Begin
    if PTriNode(Key1)^.Id < PTriNode(Key2)^.Id then Result := -1;
    if PTriNode(Key1)^.Id > PTriNode(Key2)^.Id then Result :=  1;
    if PTriNode(Key1)^.Id = PTriNode(Key2)^.Id then Result :=  0;
  END;



   Function GetValue(tekstregel:string):integer;
   {de waarde als word ophalen}
   var
      maxlen : integer;
      startpos: integer;
      strword: string;
   begin
      if pos('=',tekstregel)>0 then
      begin
         startpos :=pos('=',tekstregel)+1;
         maxlen := length(tekstregel);
         strword := trim(copy(tekstregel,startpos,(maxlen-startpos+1)));
         GetValue := StrToIntDef(strword, 0);
      end
      else
         GetValue := 0;
   end;

   Procedure GetFormaat(Formaat:string; var ValNrs:word;
                                        var ValType:string;
                                        var ValLen: word;
                                        var ValDec:word);
   var
     PosT, PosP : word;
     code : integer;

   Begin
     {ontleed het volgende
       5E15.8
       5  = aantal waarden per regel
       E  = exponentiele waarde
       15 = lengte van de stringwaarde
       .8 = aantal decimalen nauwkeurig

       of
       14I5
       14 = aantal waarden per regel
       I  = integer waardetype
       5  = lengte van de stringwaarde
       }

       If Pos('E',Formaat) > 0 then
       begin
          ValType := 'E';
          PosT := Pos('E',Formaat);
          val((Copy(Formaat, 1, PosT-1)),ValNrs,code);

          PosP := Pos('.',Formaat);
          {lengte van stringwaarde}
          val((Copy(Formaat, PosT+1, PosP - PosT-1)),ValLen,code);

          {aantal decimalen}
          val((Copy(Formaat, PosP+1, length(Formaat)-PosP)),ValDec,code);
       end
       Else {formaat = I}
       begin
          ValType := 'I';
          PosT := Pos('I',Formaat);
          val((Copy(Formaat, 1, PosT-1)),ValNrs,code); {aantal waarden per regel}

          val((Copy(Formaat, PosT+1, length(formaat)-PosT)),ValLen,code); {aantal waarden per regel}
          ValDec := 0;
       end;


   end; {procedure GetFormaat}

   FUNCTION ReadGridTeoHeader(Bestandsnaam:String):PTriAantal;
   var RecAantal : PTriAantal;
       f : TextFile;
       regel : string;
   Begin
      New(RecAantal);
      AssignFile(f,Bestandsnaam); Reset(f);
      ReadLn(f,regel);
      ReadLn(f,regel); RecAantal^.nodes := GetValue(regel);
      ReadLn(f,regel); RecAantal^.elements := GetValue(regel);
      ReadLn(f,regel); RecAantal^.fixedpoints := GetValue(regel);
      ReadLn(f,regel); RecAantal^.sources := GetValue(regel);
      ReadLn(f,regel); RecAantal^.rivers := GetValue(regel);
      ReadLn(f,regel); RecAantal^.rivernodes := GetValue(regel);
      ReadLn(f,regel); RecAantal^.boundarynodes := GetValue(regel);
      ReadGridTeoHeader := RecAantal;
   end;


   Procedure ReadCalibFiles(var Bestanden:PBestanden;var CalibList:TList);
   var
      NNodes : integer;
      Node              :PCalibRec;
      AantalGevonden, Teller : integer;
      LogMade,Gevonden : Boolean;
      f,n,l : textfile;
      regel, copyregel : string;
      Decimalen,CodeWaarde, AantalKolommen,Spaties,PosL, PosR : word;
      Code,xx : integer;
      StrVal,CurrentSetnaam,AdoFloSetnaam,AdoFloLocatie,Formaat : string;
      AdoWaarde : double;
      AdoInt : integer;
      I,r,s : integer;
      info : string;
      Veldwaarde : single;
      ValNrs,
      ValDec,
      ValLen        : word;
      ValType       : string;
      AdoFilenaamArray : Array[0..(maxVelden-1)] of string;
      AdoSetnaamArray : array[0..(maxVelden-1)] of string;

   Begin
    CalibList := TList.create;
    AantalGevonden := 0;
    Teller := 0; {wordt gebruikt voor verwijzing met regelnummer van het
                  ingelezen bestand EN voor de twee ADO... array's!!}
    LogMade := False;

    AssignFile(n,Bestanden^.FileIn); Reset(n);  {invoerfile}
    AssignFile(l,Bestanden^.FileLog); ReWrite(l); CloseFile(l);{logfile}
    SetCurrentDir(ExtractFilePath(Bestanden^.FileIn));
    {eerste regel overslaan}
    readLn(n);

    {Een eventuele TAB vervangen door een spatie}
    While not EOF(n) do begin
      inc(Teller);
      readLn(n,regel);
      regel := trim(regel);
      copyregel := regel;
      While pos(#9,regel)>0 do begin
         PosL := pos(#9,regel);
         delete(regel,PosL,1);
         Insert(' ', regel, PosL);
      end;
      regel := trim(regel);
      While pos('  ',regel)>0 do delete(regel,pos('  ',regel),1);
      spaties := countspace(regel);
      AantalKolommen := spaties + 1;
      if aantalKolommen >= 2 then begin
         {kolom 1 setnaam}
         if pos( '"',regel) = 1 then begin
            PosL := pos( '"',regel);
            delete(regel,Pos('"',regel),1);
            PosR := pos( '"',regel);
            delete(regel,Pos('"',regel),1);
            AdoFloSetnaam := copy(regel,PosL,PosR-PosL);
            delete(regel,1,PosR);
         end
         else begin
            posR := Pos(' ',regel);
            AdoFloSetnaam := copy(regel,1,PosR-1); delete(regel,1,PosR);
         end;
         AdoFLoSetnaam := Uppercase(AdoFLoSetnaam);

         {kolom 2 directorienaam+adoflofile}
         if pos( '"',regel) = 1 then begin
            PosL := pos( '"',regel);
            delete(regel,Pos('"',regel),1);
            PosR := pos( '"',regel);
            delete(regel,Pos('"',regel),1);
            AdoFloLocatie := copy(regel,PosL,PosR-PosL); delete(regel,1,PosR);
         end
         else begin
            if Pos(' ',regel) > 0 then begin
               posR := Pos(' ',regel);
               AdoFloLocatie := copy(regel,1,PosR-1); delete(regel,1,PosR);
            end
            else AdoFloLocatie := trim(regel);
         end;
         AdoFloLocatie := Uppercase(AdoFloLocatie);
         if FileExists(AdoFLoLocatie) then begin
            if LogMade = False then LogMade := True;
            info := 'Bestand ' + AdoFloLocatie +' voor adoset '+uppercase(AdoFloSetNaam) + ' op regel '+IntTosTr(Teller+1) + ' gevonden.';
            Append(l);
            WriteLn(l, Info);
            CloseFile(l);
         end {?ist.count > 0}
         else begin
            if LogMade = False then LogMade := True;
            Beep;
            info := '! Bestand '+uppercase(AdoFLoLocatie) + ' op regel '+IntTosTr(Teller+1) + ' bestaat niet.';
            Append(l);
            WriteLn(l, Info);
            CloseFile(l);
            Bestanden^.GoOn := false; {het programma verder niet uitvoeren}
            //MemoInfo.lines.add(info);
         end;



         AdoSetnaamArray[teller-1] :=  AdoFLoSetnaam;
         AdoFilenaamArray[teller-1] := AdoFloLocatie;
      end {if AantalKolommen >= 2}
      else begin
         if LogMade = False then LogMade := True;
         Beep;
         info := '! Minimaal 2 parameters nodig, gevonden aantal parameters is '+ IntToStr(AantalKolommen)+ ' op regel '+IntTosTr(Teller+1);
         Append(l);
         WriteLn(l, Info);
         CloseFile(l);
         Bestanden^.GoOn := false; {het programma verder niet uitvoeren}
      end;
    end; {while eof(n) = alle gewenste data inlezen}
    info := 'Klaar met het lezen van de ' + IntToStr(Teller) + ' databestanden.';

    {vanaf hier de bestanden inlezen}
    for xx := 0 to (maxVelden-1) do begin
         gevonden := false;
         AdoFLoLocatie :=AdoFilenaamArray[xx];
         AdoFloSetNaam :=AdoSetnaamArray[xx];
         if FileExists(AdoFLoLocatie) then begin
            AssignFile(f,AdoFLoLocatie); Reset(f);
            Repeat
               readLn(f,regel); uppercase(regel);
               if pos('*SET*',uppercase(REGEL)) > 0 THEN Begin
                  {bij tijdafhankelijke data tot de komma vergelijken,
                  anders de gehele setnaam vergelijken}
                  regel := trim(regel);
                  While pos('  ',regel)>0 do delete(regel,pos('  ',regel),1);
                  if Pos(',',regel) > 0 then begin
                     posR := Pos(' ',regel);
                     CurrentSetnaam := copy(regel,1,PosR-1); {inclusief *SET*}
                  end
                  else
                     CurrentSetnaam := regel;
                  if '*SET*'+AdoFloSetNaam = uppercase(CurrentSetnaam) then gevonden := true
                  else gevonden := false;
               end
               else gevonden := false;
            until gevonden or eof(f);

            if (not eof(f)) and (gevonden) then begin


            ReadLn(f,regel);
            Val(regel,CodeWaarde,code);
            If CodeWaarde = 1 then begin
               {constante waarde in de file}
               {eventueel nog regel toevoegen voor toekennen van constante waarde}
               if CalibList.count > 0 then begin
                  AantalGevonden := AantalGevonden + 1;
                  readLn(f,AdoWaarde);
                  str(AdoWaarde:10:0,StrVal);
                  Val(StrVal,AdoInt, Code);
                  For r := 1 to CalibList.Count do
                  if AantalGevonden = 1 then begin
                     New(Node);
                     Node^.OpmStr := '';
                     case xx of
                        0 : Node^.Select := AdoWaarde;
                        1 : Node^.GtBodemkrt := AdoInt;
                        2 : Node^.GtBerekend := AdoInt;
                        3 : Node^.Mv := Adowaarde;
                        4 : Node^.CL1 := Adowaarde;
                        5 : Node^.RP4 := Adowaarde;
                        6 : Node^.RP7 := Adowaarde;
                        7 : Node^.SC1 := adowaarde;
                        8 : Node^.WP := adowaarde;
                        9 : Node^.ZP := adowaarde;

                     end;
                     CalibList.add(Node);
                  end
                  else begin
                     Node := CalibList.items[r-1];
                     case xx of
                        0 : Node^.Select := AdoWaarde;
                        1 : Node^.GtBodemkrt := AdoInt;
                        2 : Node^.GtBerekend := AdoInt;
                        3 : Node^.Mv := Adowaarde;
                        4 : Node^.CL1 := Adowaarde;
                        5 : Node^.RP4 := Adowaarde;
                        6 : Node^.RP7 := Adowaarde;
                        7 : Node^.SC1 := adowaarde;
                        8 : Node^.WP := adowaarde;
                        9 : Node^.ZP := adowaarde;
                     end;
                  end; {for r}
                  if LogMade = False then LogMade := True;
                  info := 'Dataset '+uppercase(AdoFloSetNaam) + ' ingelezen met ' + intToStr(NNodes)+ ' getallen.';
                  Append(l);
                  WriteLn(l, Info);
                  CloseFile(l);

               end; {?ist.count > 0}
            end
            else if CodeWaarde = 2 then {CodeWaarde = 2}
            Begin
               AantalGevonden := AantalGevonden + 1;
               {eerste de kopregel veldnaam toevoegen}
               ReadLn(f,regel); {number of data and format}
               regel := trim(regel);
               val(Copy(regel, 1, (pos(' ',regel)-1)),NNodes,code);
               PosR := Pos(')',regel);
               PosL := Pos('(',regel);
               Formaat := Copy(regel, posL+1, PosR-PosL-1);
               GetFormaat(Formaat,ValNrs,ValType,ValLen,ValDec);
               For r := 1 to NNodes do
               begin
                        s := (r-1) mod ValNrs;
                        if s = 0 then readln(f,regel);
                        PosL := (S) * ValLen + 1;
                        StrVal := copy(regel,PosL,ValLen);
                        StrVal := trim(StrVal);
                        Val(StrVal,AdoWaarde,Code);
                        str(AdoWaarde:10:0,StrVal);
                        Val(StrVal,AdoInt, Code);
                        if AantalGevonden = 1 then begin
                           New(Node);
                           Node^.OpmStr := '';
                           case xx of
                              0 : Node^.Select := AdoWaarde;
                              1 : Node^.GtBodemkrt := AdoInt;
                              2 : Node^.GtBerekend := AdoInt;
                              3 : Node^.Mv := Adowaarde;
                              4 : Node^.CL1 := Adowaarde;
                              5 : Node^.RP4 := Adowaarde;
                              6 : Node^.RP7 := Adowaarde;
                              7 : Node^.SC1 := adowaarde;
                              8 : Node^.WP := adowaarde;
                              9 : Node^.ZP := adowaarde;
                           end;
                           CalibList.add(Node);
                        end
                        else begin
                           Node := CalibList.items[r-1];
                           case xx of
                              0 : Node^.Select := AdoWaarde;
                              1 : Node^.GtBodemkrt := AdoInt;
                              2 : Node^.GtBerekend := AdoInt;
                              3 : Node^.Mv := Adowaarde;
                              4 : Node^.CL1 := Adowaarde;
                              5 : Node^.RP4 := Adowaarde;
                              6 : Node^.RP7 := Adowaarde;
                              7 : Node^.SC1 := adowaarde;
                              8 : Node^.WP := adowaarde;
                              9 : Node^.ZP := adowaarde;
                           end;
                        end;

               end; {for r}
               if LogMade = False then LogMade := True;
               info := 'Dataset '+uppercase(AdoFloSetNaam) + ' ingelezen met ' + intToStr(NNodes)+ ' getallen.';
               Append(l);
               WriteLn(l, Info);
               CloseFile(l);
               //MemoInfo.lines.add(info);
            end {else if codewaarde=2}
            else begin
              MessageDlg('Codewaarde ongelijk aan 1 of 2', mtWarning, [mbOK], 0);
              exit;
            end;
            end {if not (eof(f) and gevonden)}
            else begin
               if LogMade = False then LogMade := True;
               Beep;
               info := '! Dataset '+uppercase(AdoFloSetNaam) + ' bestaat niet in ' + uppercase(AdoFloLocatie);
               Append(l);
               WriteLn(l, Info);
               CloseFile(l);
               Bestanden^.GoOn := false; {het programma verder niet uitvoeren}
               //MemoInfo.lines.add(info);
            end;
            closeFile(f);
         end {als opgegeven file WEL bestaat}
         else {opgegeven invoerfile bestaat niet}
            begin
               if LogMade = False then LogMade := True;
               Beep;
               info := '! Bestand '+ uppercase(AdoFloLocatie) + ' bestaat niet.';
               Append(l);
               WriteLn(l, Info);
               CloseFile(l);
               Bestanden^.GoOn := false; {het programma verder niet uitvoeren}
               //MemoInfo.lines.add(info);
            end;
    end; { for xx}
   end; {Procedure ReadCalibFiles}

   Function GHGstatus(CalibRec:PCalibRec):Boolean;
   Begin
      If (CalibRec^.GtBodemkrt in  GHGokay1) and (CalibRec^.GtBerekend in  GHGokay1)Then
         RESULT := TRUE
      ELSE if (CalibRec^.GtBodemkrt in  GHGokay2) and (CalibRec^.GtBerekend in  GHGokay2)Then
         RESULT := TRUE
      ELSE if (CalibRec^.GtBodemkrt in  GHGokay3) and (CalibRec^.GtBerekend in  GHGokay3)Then
         RESULT := TRUE
      else
         RESULT := FALSE;
   end;

   Function GLGstatus(CalibRec:PCalibRec):Boolean;
   Begin
      If (CalibRec^.GtBodemkrt in  GLGokay1) and (CalibRec^.GtBerekend in  GLGokay1)Then
         RESULT := TRUE
      ELSE if (CalibRec^.GtBodemkrt in  GLGokay2) and (CalibRec^.GtBerekend in  GLGokay2)Then
         RESULT := TRUE
      ELSE if (CalibRec^.GtBodemkrt in  GLGokay3) and (CalibRec^.GtBerekend in  GLGokay3)Then
         RESULT := TRUE
      else
         RESULT := FALSE;
   end;

   Procedure UpdataCalibRec(var CalibRec:PCalibRec; GHG,GLG:boolean);
   var
      Ber,Gem : integer;
      m,w,z : single;
      Fac : single;

      Function GetSC1(val:single):single;
      var bc :single;
          str:string;
         { Val = de waarde waarmee de bergingscoeeficient verandert wordt}
      Begin
         str := CalibRec^.OpmStr;
         bc := CalibRec^.SC1;
         GetSC1 := bc;
         if (bc + val) < minSC1 then begin
            GetSC1 := minSC1;
            if val > 0 then CalibRec^.OpmStr :=  str + ' 11'//OPM^[11] := 1
            else if val < 0 then CalibRec^.OpmStr :=  str + ' 12' //OPM^[12] := 1;
         end
         else if (bc + val) > maxSC1 then begin
            GetSC1 := maxSC1;
            if val > 0 then CalibRec^.OpmStr :=  str + ' 11' //OPM^[11] := 1
            else if val < 0 then CalibRec^.OpmStr :=  str + ' 12';//OPM^[12] := 1;
         end;
      end;

      Function GetRP7(factor:single):single;
      var tmp :single;
         str:string;
      Begin
         str := CalibRec^.OpmStr;
         tmp := CalibRec^.RP7;
         if tmp < GeenAanvoer then begin
            tmp := factor * tmp;
            if tmp < CalibRec^.RP4 then begin
               GetRP7 := CalibRec^.RP4;
               if Factor > 1 then CalibRec^.OpmStr :=  str + ' 9'//OPM^[9] := 1
               else if factor < 1 then CalibRec^.OpmStr :=  str + ' 10';//OPM^[10] := 1
            end
            else begin
               GetRP7 := tmp;
               if Factor > 1 then CalibRec^.OpmStr :=  str + ' 9'//OPM^[9] := 1
               else if factor < 1 then CalibRec^.OpmStr :=  str + ' 10';//OPM^[10] := 1
            end;
         end
         else GetRP7 := CalibRec^.RP7;
         {else geen aanpassing}

      end;

      Function GetDeklaagWeerstand(GWSverandering:single):single;
      {GWSverandering
         positief --> verhoging van de deklaagweerstand
         negatief --> verlaging van de deklaagweerstand}
      var tmp : single;
         str : string;
      Begin
         str := CalibRec^.OpmStr;
         tmp := CalibRec^.CL1;
         if tmp >= minDeklaagWeerstand then begin
            tmp := tmp + GWSverandering / 0.0033; {dagen}
            if (tmp >= minDeklaagWeerstand) and (tmp <= maxDeklaagWeerstand) then
            begin
               GetDeklaagWeerstand := tmp;
               if GWSverandering > 0 then CalibRec^.OpmStr :=  str + ' 5'//OPM^[5] := 1
               else if GWSverandering < 1 then CalibRec^.OpmStr :=  str + ' 6';//OPM^[6] := 1
            end
            else GetDeklaagWeerstand := CalibRec^.CL1
         end
         else GetDeklaagWeerstand := CalibRec^.CL1 {geen verandering}
      end;

      Function GetDrainageWeerstand(GWSverandering:single):single;
      {GWSverandering
         positief --> verhoging van de deklaagweerstand
         negatief --> verlaging van de deklaagweerstand}
      var tmp:single;
         str : string;
      Begin
         str := CalibRec^.OpmStr;
         tmp := CalibRec^.RP4;
         if tmp >= minDrainageWeerstand then begin
            tmp := tmp + GWSverandering / VeelNeerslagOverschot; {dagen}
            if (tmp >= minDrainageWeerstand) and (tmp <= maxDrainageWeerstand) then
            begin
               GetDrainageWeerstand := tmp;
               if GWSverandering > 0 then CalibRec^.OpmStr :=  str + ' 7'//OPM^[7] := 1
               else if GWSverandering < 1 then CalibRec^.OpmStr :=  str + ' 8';//OPM^[8] := 1
            end
            else {geen verandering}
               GetDrainageWeerstand := CalibRec^.RP4
         end;
         GetDrainageWeerstand := CalibRec^.RP4; {geen verandering}
      end;

      {opmerkingen nummers
      0 = BUITEN HET SELECTIEGEBIED
      1 = aantal onderzochte nodes
      2 = GTberekend onbekend
      3 = MV < WP
      4 = MV < ZP
      5 = Deklaagweerstand verhoogd;
      6 = Deklaagweerstand verlaagd
      7 = Drainage weerstand verhoogd
      8 = Drainage weerstand verlaagd
      9 = Infiltratie weerstand verhoogd
      10 = Infiltratie weerstand verlaagd
      11 = Freatische bergingscoefficent verhoogd
      12 = Freatische bergingscoefficent verlaagd
      888 = GTgemeten = GTberekend
      999 = Niks aangedaan
      }

   Begin
    Gem := CalibRec^.GtBodemkrt;  {'gemeten'-GT}
    Ber := CalibRec^.GtBerekend;  {berekende -GT}

    if CalibRec^.Select >= 1 then begin
      CalibRec^.OpmStr := CalibRec^.OpmStr + ' 1';
      //OPM^[1] := 1; {onderzochte node}

      if ( Gem > 0) and ( Gem < 100) then begin
         { hiermee alleen de gebieden aanpassen waarvoor
         ook een gemeten GT aanwezig is }
         if CalibRec^.Mv < CalibRec^.WP then CalibRec^.OpmStr := CalibRec^.OpmStr + ' 3';//OPM^[3] := 1;
         if CalibRec^.Mv < CalibRec^.ZP then CalibRec^.OpmStr := CalibRec^.OpmStr + ' 4';//OPM^[4] := 1;
         if Gem = Ber then CalibRec^.OpmStr := CalibRec^.OpmStr + ' 888'{okay}
         else
         Case Gem of
            10 : Begin
               if ber in [20,22,30,32,50] then Begin
                  CalibRec^.SC1 := GetSC1(0.025);
               end
               else if Ber in [25,35,35] then begin
                  CalibRec^.SC1 := GetSC1(-0.025);
               end
               else if Ber in [40,42,45] then CalibRec^.RP7:=GetRP7(0.9)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
               {niks doen bij GT >= 55}
            end; {gem = 10}

            20,22 : begin
               if ber in [10] then
                  begin
                     if (CalibRec^.Mv - CalibRec^.ZP) > 0.5 then begin
                        CalibRec^.SC1 := GetSC1(0.025);
                     end
                     else begin
                        CalibRec^.RP7 := GetRP7(0.9);
                     end;
                  end
               else if ber in [25,35,55] then begin
                  CalibRec^.CL1 := GetDeklaagWeerstand(0.125);
               end
               else if ber in [30,32,50] then
                  CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [40,42] then CalibRec^.CL1 := GetDeklaagWeerstand(0.20)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
               {else}
                  {klopt het maaiveld wel}

            end;

            25 : begin
               if ber in [10,20,22,30,32,50,60] then CalibRec^.SC1 := GetSC1(0.025)
               else if ber in [35,55] then CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [40,42] then CalibRec^.RP4 := GetDrainageWeerstand(0.125)
               else if ber in [45] then CalibRec^.SC1 := GetSC1(-0.01)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'

            end;

            30,32 : begin
               if ber in [10,20,22] then CalibRec^.SC1 := GetSC1(-0.01)
               else if ber in [50] then CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [25] then CalibRec^.SC1 := GetSC1(-0.01)
               else if ber in [35] then CalibRec^.SC1 := GetSC1(-0.01)
               else if ber in [40,42] then CalibRec^.RP4 := GetDrainageWeerstand(0.125)
               else if ber in [55] then CalibRec^.RP7 := GetRP7(0.9)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'

            end; {30,32}

            35 : begin
               if ber in [10,20,22,25] then CalibRec^.RP7 := GetRP7(0.9)
               else if ber in [30] then CalibRec^.SC1 := GetSC1(0.025)
               else if ber in [40,42,45] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [50] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [55] then CalibRec^.RP7 := GetRP7(0.9)
               else if ber in [60] then CalibRec^.RP7 := GetRP7(0.9)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
               {70,75 niks doen}
            end;

            40,42 : begin
               if ber in [10] then
                  CalibRec^.RP7 := GetRP7(1) {geen verandering}
               else if ber in [20,25] then CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [30,32,35] then CalibRec^.SC1 := GetSC1(0.025)
               else if ber in [45] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [50,55,60] then CalibRec^.SC1 := GetSC1(0.025)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'

            end;

            45 : begin
               {11 december
               komt niet voor in de bestanden}
            end;

            50 : begin
               if ber in [10,20,22] then
                  CalibRec^.RP7 := GetRP7(1) {geen verandering}
               else if ber in [25,35,40,42,45] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [30] then  CalibRec^.RP7 := GetRP7(0.9)
               else if ber in [55,60] then CalibRec^.SC1 := GetSC1(-0.025)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'

                  {70,75 niks doen}
            end;

            55 : begin
               if ber in [10] then
                  CalibRec^.RP7 := GetRP7(1) {geen verandering}
               else if ber in [20,22,25,30,35] then CalibRec^.RP7 := GetRP7(0.9)
               else if ber in [40,42,45] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [50] then CalibRec^.SC1 := GetSC1(0.025)
               else if ber in [60] then CalibRec^.SC1 := GetSC1(-0.01)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
                  {70,75 niks doen}
            end;

            60 :  begin
               if ber in [10,20,22] then
                  CalibRec^.RP7 := GetRP7(1) {geen verandering}
               else if ber in [25,30,32,35,40,42] then CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [45] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [50] then CalibRec^.RP4 := GetDrainageWeerstand(-0.25)
               else if ber in [55] then CalibRec^.SC1 := GetSC1(-0.025)
               else if ber in [70] then
                  begin
                     Fac := CalibRec^.RP7 / CalibRec^.RP4;
                     CalibRec^.RP4 := GetDrainageWeerstand(-0.25);
                     CalibRec^.RP7 := GetRP7(Fac)
                  end
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
               {75 niks doen}
            end;

            70 : begin
               {niks doen bij Ber < 60}
               if ber in [60] then CalibRec^.RP7 := GetRP7(1.1)
               else if ber in [75] then CalibRec^.SC1 := GetSC1(0.025)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
            end;

            75 : begin
               if ber in [70] then CalibRec^.SC1 := GetSC1(0.025)
               else  CalibRec^.OpmStr := CalibRec^.OpmStr + ' 999'
            end;
         end; {case Gem}
      end{(not Gem < 0) or (not Gem > 100)}
      else
         CalibRec^.OpmStr := CalibRec^.OpmStr + ' 2';//OPM^[2] := 1; {GTberekend is onbekend}
    end {Select >= 1}
    else
      CalibRec^.OpmStr := CalibRec^.OpmStr + ' 0'; //OPM^[0] := 1;{node buiten selectiegebied}


   end;{of Procedure UpdataCalibRec(CalibRec:PCalibRec; GHG,GLG:boolean);}

   Procedure ExportCalibUpdates(Bestanden:PBestanden; var CalibList:TList);
      {
      Alleen de velden SC1, RP7 exporteren
      }
   Begin
   end;

end.
