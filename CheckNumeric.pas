unit CheckNumeric;



interface
   uses Sysutils,Dialogs,Messages;

   function NumberCheck(NCstring:string):boolean;
   Function IsNumericWIN(strNumber:string): Boolean;
   Function IsNumericDOS(StringNum:string):boolean;
   Function CountSpace(Regel:string):integer;
   Function CountComma(Regel:string):integer;
   Function StringRightPos(Regel:string; SearchStr:string):integer;
   Function AantalDataKolommen(bestandsnaam:string):integer;

implementation

  Function NumberCheck(NCstring:string):boolean;
  var i :integer;
      een :string[1];

      Function PlusMin(Teken:string):boolean;
      Begin
        If (Teken = '-') or (Teken = '+') then PlusMin := True
        else PlusMin := False;
      end;

      Function IsGetal(een:string):boolean;
      Begin
        if (een >= '0') and (een <= '9') then IsGetal := True
        else IsGetal := False;
      end;

  Begin
      if Length(NCstring) > 0 then
      Begin
      i := 0;
      Repeat
       een := Copy(NCstring, i+1,1);
       if i+1 = 1 then
       Begin
         if PlusMin(een) or IsGetal(een) then
         begin
           NumberCheck := true;
           i := i + 1;
         end
         else
         begin
           i := Length(NcString);
           NumberCheck := False
         end; {else PlusMin or isgetal}
       end {if i+1 = 1}
       else    {vanaf de tweede letter/cijfer van de string}
       Begin
             if IsGetal(een) then
             begin
               NumberCheck := True;
               i := i + 1;
             end
             Else
             begin
               NumberCheck := False;
               i := Length(NCstring);
             end;
       end; {else}
      Until (i = Length(NCstring));
    end
    else NumberCheck := False;
  end; {NumberCheck(NCstring:string)}

   Function IsNumericWIN(strNumber:string):boolean;
   {voor de windows versie}
   var   tmpFloat : extended;
   Begin
      try
            {the following stetement is protected because it
            can generate an error if B equals 0}
         tmpFloat := StrTofloat(strNumber);
         IsNumericWIN := true;
      except
         on EConvertError do
         begin
            beep;
            MessageDlg ('Opgegeven waarde is niet numeriek', mtError, [mbOK], 0);
            IsNumericWIN := false;
         end;
      end;{except}
   end;

  Function IsNumericDOS(StringNum:string):boolean; {NummerIngevuld}
  {indien een CONSOLE programma wordt gemaakt}
   var   tmpFloat : extended;
   Begin
      IsNumericDOS := true;
      try
            {the following stetement is protected because it
            can generate an error if B equals 0}
         tmpFloat := StrTofloat(StringNum);
      except
         on EConvertError do
         begin
            IsNumericDOS := false;
         end;
      end;{except}
   end;

   Function CountSpace(Regel:string):integer;
   var
      i,j :integer;
      copyregel : string;
   Begin
      copyregel := regel;
      i := 0;
      While pos(' ',Regel) > 0 do
      begin
         i := i + 1;
         delete(regel,1, pos(' ',regel)+1);
      end;
      Regel := copyregel;
      j := 0;
      While pos('"',Regel) > 0 do
      begin
         j := j + 1;
         delete(regel,1, pos('"',regel)+1);
      end;
      CountSpace := i - trunc(j / 2 );
   end;

   Function CountComma(Regel:string):integer;
   var
      i,j :integer;
      copyregel : string;
   Begin
      copyregel := regel;
      i := 0;
      While pos(',',Regel) > 0 do
      begin
         i := i + 1;
         delete(regel,1, pos(',',regel)+1);
      end;
      Regel := copyregel;
      j := 0;
      While pos('"',Regel) > 0 do
      begin
         j := j + 1;
         delete(regel,1, pos('"',regel)+1);
      end;
      CountComma := i - trunc(j / 2 );
   end;

   Function StringRightPos(Regel:string; SearchStr:string):integer;
   var
      i,max :integer;
      sub : string;
   begin
      StringRightPos := 0;
      regel := trim(regel);
      max := length(regel);
      For i := max downto 1 do
      Begin
         sub := lowercase(copy(regel,i,1));
         if sub = lowercase(SearchStr) then
         begin
            StringRightPos := i;
            exit;
         end;
      end;

   end;

   Function AantalDataKolommen(bestandsnaam:string):integer;
   var
    F       : textfile;
    Tijd    : real;
    waarde  : double;
    Spaties : integer;
    regel   : string;
   begin
      AssignFile(f,bestandsnaam); reset(F);
      readLn(f); {eerste regel overslaan}
      read(f,tijd);
      readLn(f,regel);
      closeFile(F);
      regel := trim(regel);
      While pos('  ',regel)>0 do
         delete(regel,pos('  ',regel),1);

      spaties := countspace(regel);
      AantalDataKolommen := spaties + 1;
   end;
end.

