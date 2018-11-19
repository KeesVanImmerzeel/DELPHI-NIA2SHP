unit grd2area;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, CheckNumeric,Ogridteo, ComCtrls, ShpAPI129, uError;

CONST
   WaardeNil  = -100;
   Extreem    :real = 1.70141e+038{1.7e+38};

type
  TDoubleArray = array of Double;
  TLongIntArray = array of LongInt;
{  PNode = ^TNode;
  TNode = record
    Id     : integer;
    Xc     : Double;
    Yc     : Double;
    //CONSTRUCTOR Init(N:integer;S:longint;CW:real);
  END;
}
  TForm1 = class(TForm)
    GoButton: TButton;
    MemoInfo: TMemo;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    ProgressBar1: TProgressBar;
    LabeledEditTriwacoGridFileName: TLabeledEdit;
    Label1: TLabel;
    procedure GoButtonClick(Sender: TObject);
    procedure LabeledEditTriwacoGridFileNameClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
     NodeList : TList;
     ElementList : TList;
     RecAantal: PTriAantal;
     TriRange : PTriRange;
     Procedure LeesGridTriwaco( const GridFileName: String ); {MaakVerzameling }
     //Procedure BepaalGridCel(Bestanden:PBestanden);
     //Procedure BepaalWaardeCelnr(Bestanden:PBestanden);
     Procedure BepaalOmringendeElementen;
     Procedure BepaalOmringendeNodes;
     Procedure SchrijfNodes( const aFileName: String );
     Procedure SchrijfElementen( const aFileName: String );
     Procedure SchrijfNIA( const aFileName: String );
     Procedure SchrijfFEMfile( const aFileName: String );
     Procedure ClearList;
  public
    { Public declarations }
  end;

{
   oktober 2002
   
   Programma om een Triwaco-gridbestand (grid.teo( in te lezen.
   Voor de knooppunten wordt de beinvloedingsgebied bepaald en
   naar een ungenerate bestand  geschreven. Deze ungenerate-bestand
   kan met behulp van een arcview-extentie worden geimporteerd
   naar een shapefile

   25 januari 2003
   Voor procedure BepaalOmringendeNodes het vinden van de randknooppunten
   aangepast. Was alleen voor n = n3 and nTo =1 and b = 1. Dit is aangevuld
   voor als n = n2 of n1!!!!

   augustus 2003
   Het programma is aangepast. Het schrijft niet meer een UNG-FILE weg, maar
   maakt een shapefile. Hiervoor is het component SHP en jbDBF nodig.

}

Const
   VersieNr : string = 'Versie 1.2 (4 februari 2004)';
var
  Form1: TForm1;
  AantalPar : word;

implementation

{$R *.DFM}


{************************************************************************}


procedure TForm1.LabeledEditTriwacoGridFileNameClick(Sender: TObject);
begin
  with OpenDialog1 do begin
    if Execute then begin
      LabeledEditTriwacoGridFileName.Text := ExpandFileName( FileName );
    end;
  end;
end;

procedure TForm1.GoButtonClick(Sender: TObject);
var
   strMsg : string;
   Bestanden : PBestanden;
begin
  Try
    if not FileExists(  LabeledEditTriwacoGridFileName.Text ) then
      Raise Exception.Create( 'Input grid not found.' )
    else
      LabeledEditTriwacoGridFileName.Text := ExpandFileName( LabeledEditTriwacoGridFileName.Text );
    Try

      ProgressBar1.Visible := false;
      if MemoInfo.lines.count > 0  then MemoInfo.lines.clear;

      { voor inlezen triwaco file moet de file grid.teo worden ingelezen.}
      strMsg := 'Inlezen van het Triwaco grid bestand [' + LabeledEditTriwacoGridFileName.Text + ']';
      MemoInfo.lines.add( strMsg ); WriteToLogFile( strMsg );
      LeesGridTriwaco( LabeledEditTriwacoGridFileName.Text );

      strMsg := 'knooppunten                  --> Shapefile (# ' + IntToStr(RecAantal^.nodes) + ')';
      MemoInfo.lines.add(strMsg); WriteToLogFile(  strMsg );
      strMsg := 'Schrijven punten shape [' + ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'nodes.shp' + ']';
      MemoInfo.lines.add( strMsg ); WriteToLogFile(  strMsg );
      SchrijfNodes( ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'nodes.shp' );  {maakt een punten shapefile}

      strMsg := 'elementen                    --> Shapefile (# ' + IntToStr(RecAantal^.elements) + ')';
      MemoInfo.lines.add(strMsg ); WriteToLogFile(  strMsg );
      strMsg := 'Schrijven elementen [' + ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'elems.shp' + ']';
      MemoInfo.lines.add( strMsg ); WriteToLogFile(  strMsg );
      SchrijfElementen( ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'elems.shp'  );  {maakt een polygonen shapefile}

      {Bepaal de omringende elementen per node}
      strMsg := 'Per node de omringende elementen bepalen.';
      MemoInfo.lines.add( strMsg ); Update; WriteToLogFile(  strMsg );
      BepaalOmringendeElementen;

      {Bepaald de omringende volgorde van de nodes}
      strMsg :='Per node de volgorde van omringende nodes bepalen.';
      MemoInfo.lines.add( strMsg ); Update;  WriteToLogFile(  strMsg );
      BepaalOmringendeNodes;

      {BepaalWaardeCelnr(Bestanden);}
      strMsg := 'Beïnvloedingsgebied --> Shapefile [' + ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'influencearea.shp' + ']';
      MemoInfo.lines.add( strMsg ); Update; WriteToLogFile(  strMsg );
      SchrijfNIA( ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'influencearea.shp'  );

      {BepaalWaardeCelnr(Bestanden);}
      strMsg := 'Triwaco --> MicroFem';
      MemoInfo.lines.add('Triwaco --> MicroFem'); Update; WriteToLogFile(  strMsg );
      schrijfFEMfile( ExtractFilePath( LabeledEditTriwacoGridFileName.Text ) + 'influencearea.fem');

      ClearList;

    Except
      On E: Exception do begin
        ShowMessage( E.Message );
      end;
    End;
  Finally
    End;
end;


Procedure TForm1.LeesGridTriwaco( const GridFileName: String );

  Var
    Node          :PTriNode;
    Element       :PTriElement;
    fem,grid      :string;
    f,g           :textfile;
    CodeFormat    :byte;
    NodeStr       : string; {nodenr nog als string}
    I,q,r,s , IG,NodeNr,ElementNr, StartR,
    code          :integer;
    NNodes,
    NElements,
    NAquifers,
    NDischarge,
    CodeWaarde    :Integer;

    PosL,PosR     : word;
    Formaat       :string;
    ValNrs,
    ValDec,
    ValLen        : word;
    ValType       : string;
    StrVal        : string;
    Coordinaat    : extended;  {getal voor x,y}


    AantalRegels  : word;
    OverigeWaarden: word;

    Rand          :Byte;           {Fem randwaarde (1,0)              }

    Xfem, Yfem    :real;           {x en y coordinaat node            }

    info, regel : string;
    GeenWaarde : real;
    gevonden : boolean;
  Begin
    GeenWaarde := WaardeNil;  {fixtieve waarde}

    new(TriRange);
    with TriRange^ do begin
      minX :=  1e20; maxX := -1e20;
      minY :=  1e20; maxY := -1e20;
    end;


    {*********************************************************************}
    {* Verzameling maken van Nodenummer, gridcelnummer en fixtive        *}
    {* celwaarde                                                         *}
    {*********************************************************************}
    NodeList := TList.create;
    ElementList := TList.Create;
      New(RecAantal);
      AssignFile(f, GridFileName ); Reset(f);
      ReadLn(f,regel);
      ReadLn(f,regel); RecAantal^.nodes := GetValue(regel);
      ReadLn(f,regel); RecAantal^.elements := GetValue(regel);
      ReadLn(f,regel); RecAantal^.fixedpoints := GetValue(regel);
      ReadLn(f,regel); RecAantal^.sources := GetValue(regel);
      ReadLn(f,regel); RecAantal^.rivers := GetValue(regel);
      ReadLn(f,regel); RecAantal^.rivernodes := GetValue(regel);
      ReadLn(f,regel); RecAantal^.boundarynodes := GetValue(regel);
      {nu de 7- data(ado)type inlezen}


      For I := 1 to 6 do {alleen de X en Y coordinaten lezen}
      Begin
        gevonden := false;
        While not gevonden do
        begin
            ReadLn(f,regel);
            if pos('*SET*X-COORDINATES', regel) > 0 then gevonden := true
            else if pos('*SET*Y-COORDINATES', regel) > 0 then gevonden := true
            else if pos('*SET*ELEMENT NODES 1', regel) > 0 then gevonden := true
            else if pos('*SET*ELEMENT NODES 2', regel) > 0 then gevonden := true
            else if pos('*SET*ELEMENT NODES 3', regel) > 0 then gevonden := true
            else if pos('*SET*LIST BOUNDARY NODES', regel) > 0 then gevonden := true
            else
                 gevonden := false;
        end;
        ReadLn(f,regel);
        Val(regel,CodeWaarde,code);
        If CodeWaarde = 1 then
            {constante waarde in de file}
            {eventueel nog regel toevoegen voor toekennen van constante waarde}

        else if CodeWaarde = 2 then {CodeWaarde = 2}
        Begin
        {
11955     (5E15.8)
  151     (14I5)

        }
            ReadLn(f,regel); {number of data and format}
            regel := trim(regel);
            val(Copy(regel, 1, (pos(' ',regel)-1)),NNodes,code);
            PosR := Pos(')',regel);
            PosL := Pos('(',regel);
            Formaat := Copy(regel, posL+1, PosR-PosL-1);
            GetFormaat(Formaat,ValNrs,ValType,ValLen,ValDec);
            AantalRegels := trunc(NNodes / ValNrs);
            OverigeWaarden := NNodes - (AantalRegels * ValNrs);
            StartR := 1;
            If (I <= 2) then {de x&y coordinaten}
            Begin
               For r := 1 to NNodes do
               begin
                     s := (r-1) mod ValNrs;
                     if s = 0 then readln(f,regel);
                     StrVal := copy(regel,((s+1)*ValLen)-ValLen+1,ValLen);
                     Val(StrVal,Coordinaat,Code);
                     //NodeNr := (r-1)*ValNrs+s;
                     if I =1 then
                     begin
                        New(Node);
                        with Node^ do
                        begin
                           Id     := r; //(r-1)*ValNrs+s;
                           Xc     := Coordinaat;
                           Rand   := 0;
                           CelNr  := 0;
                           CelWaarde:= Geenwaarde;
                           SubElementen:='';
                        end;
                        if coordinaat < TriRange^.minX then TriRange^.minX := coordinaat;
                        if coordinaat > TriRange^.maxX then TriRange^.maxX := coordinaat;
                        NodeList.add(Node);
                     end {if I =1}
                     else {I =2}
                     begin
                        Node := NodeList.Items[r-1]; //[NodeNr-1]; {List begint met 0}
                        Node^.Yc := Coordinaat;
                        if coordinaat < TriRange^.minY then TriRange^.minY := coordinaat;
                        if coordinaat > TriRange^.maxY then TriRange^.maxY := coordinaat;
                     end; {else (I =2)}
                  //end; {for s}
               end; {for r}
               if I = 2 then
               begin
                  info := #9 + IntToStr(NNodes) + ' X/Y coordinaten ingelezen .';
                  MemoInfo.lines.add(info)
               end;

            end {de overige waarden nog inlezen!!!}

            else if (I >= 3) and (I <= 5) then
            {element nodesnummers ophalen}
               For r := 1 to NNodes do
               begin
                     s := (r-1) mod ValNrs;
                     if s = 0 then readln(f,regel);
                     StrVal := copy(regel,((s+1)*ValLen)-ValLen+1,ValLen);
                     Val(StrVal,NodeNr,Code);
                     //NodeNr := (r-1)*ValNrs+s;
                     if I = 3 then
                     begin

                        New(Element);
                        with Element^ do
                        begin
                           node1 := NodeNr;
                           node2 := -99;
                           node3 := -99;
                        end;
                        ElementList.add(Element);
                     end
                     else
                     begin
                        ElementNr := r-1; //((r-1)*ValNrs)+s-1;
                        {Denk erom: List begint met 0}
                        Element := ElementList.Items[ElementNr];
                        if I = 4 then Element^.node2 := NodeNr
                        else {I =5} Element^.node3 := NodeNr
                     end;
               end {for r}
            {einde if (I >= 3) and (I <= 5)}

            else if (I = 6) then
            begin
            {de boundary nodes}
               For r := 1 to NNodes do
               begin
                     s := (r-1) mod ValNrs;
                     if s = 0 then readln(f,regel);
                     StrVal := copy(regel,((s+1)*ValLen)-ValLen+1,ValLen);
                     Val(StrVal,NodeNr,Code);
                     //NodeNr := (r-1)*ValNrs+s;
                     Node := NodeList.items[NodeNr-1];  {de list begint met 0}
                     Node^.Rand := 1;
               end; {for r}
               info := IntToStr(NNodes) + ' randknooppunten.';
               MemoInfo.lines.add(info);
            end
            else
            {else indien I > 6| 1..5 is hiervoor afgehandeld}
            begin
              MessageDlg('Hier kan de loop niet komen', mtWarning, [mbOK], 0);
              exit;
            end;
        end {else if i=2}
        else
        begin
              MessageDlg('Codewaarde ongelijk aan 1 of 2', mtWarning, [mbOK], 0);
              exit;
        end;
      end; {for i}
      closefile(f);

  End; {LeesGridTeo}

Procedure TForm1.SchrijfNodes( const aFileName: String );
   var uit,pad,tmp :Ansistring;
         Node, Nrec : PTriNode;
         i : longint;
         //point : rPoint;
         {from ShpAPI129.pas}
         nSHPType : LongInt;
         hSHPHandle:  SHPHandle;
         hDBFHandle:  DBFHandle;
         psShape   :  PSHPObject;

Begin
      nSHPType :=  SHPT_POINT;
      ProgressBar1.Min := 1;
      ProgressBar1.Max := NodeList.Count;
      uit := AnsiString( aFileName );
      // showmessage( 'uit= [' + uit + ']' );
      // Create the Shapefile
      hSHPHandle := SHPCreate( PAnsiChar(uit) , nSHPType );
      hDBFHandle := DBFCreate( PAnsiChar(uit));
      DBFAddField(hDBFHandle,PAnsiChar('ID'),FTInteger,8,0);
      DBFAddField(hDBFHandle,PAnsiChar('BND'),FTInteger,3,0);

      ProgressBar1.Visible := true;
      For i := 0 to (NodeList.Count-1) do begin
         ProgressBar1.Position := i +1;
         node := NodeList.Items[i];
         psShape := SHPCreateObject( nSHPType, -1, 0, NIL, NIL, 1, @node^.Xc, @node^.Yc, NIL, NIL);
         SHPWriteObject( hSHPHandle, -1, psShape );
         //                           hDBF,iShape, iField, nFieldValue
         DBFWriteIntegerAttribute( hDBFHandle, i, 0,node^.id);
         DBFWriteIntegerAttribute( hDBFHandle, i, 1, node^.Rand );
         // and dismiss this object
         SHPDestroyObject( psShape );
      end;
      ProgressBar1.Visible := false;
      // close the shapefile
      SHPClose( hSHPHandle );
      DBFClose( hDBFHandle );
end;

Procedure TForm1.SchrijfElementen( const aFileName: String );
   var
      uit:Ansistring;
      Node1, Node2, Node3: PTriNode;
      Elem : PTriElement;
      j : longint;
      {--------------------------------}
      {t.b.v. ShapeFile}
      thePoints :TList;
      theParts  :TList;
      {--------------------------------}
    // Shp?API129.pas
    hSHPHandle:  SHPHandle;
    hDBFHandle:  DBFHandle;
    psShape:	 PSHPObject;
    x,y,z,m:     TDoubleArray;
    anPartStart: TLongIntArray;
    anPartType:  TLongIntArray;
    panPartType: PLongInt;
    n, i, iShape:LongInt;
    nSHPType : LongInt;

Begin
      nSHPType := SHPT_POLYGON;
      uit := AnsiString( aFileName );
      // showmessage( 'uit= [' + uit + ']' );
      {shapefile aanmaken}
      hSHPHandle := SHPCreate( PAnsiChar(uit), nSHPType );
      hDBFHandle := DBFCreate( PAnsiChar(uit));
      DBFAddField(hDBFHandle,'ID',FTInteger,8,0);
      SetLength(x,4); SetLength(y,4);

      ProgressBar1.Min := 1;
      ProgressBar1.Max := ElementList.Count;
      ProgressBar1.Visible := true;
      For i := 0 to (ElementList.Count-1) do begin
         ProgressBar1.Position := i +1;
         elem := ElementList.Items[i];
         node1 := NodeList.Items[elem^.node1-1];
         node2 := NodeList.Items[elem^.node2-1];
         node3 := NodeList.Items[elem^.node3-1];
         x[0] := node1^.xc; y[0] := node1^.yc;
         x[1] := node2^.xc; y[1] := node2^.yc;
         x[2] := node3^.xc; y[2] := node3^.yc;
         x[3] := node1^.xc; y[3] := node1^.yc;
         psShape := SHPCreateObject( nSHPType, -1, 0, NIL, NIL,
                                   4, PDouble(x),PDouble(y),NIl,NIL );
         SHPWriteObject( hSHPHandle, -1, psShape );
         DBFWriteIntegerAttribute( hDBFHandle, i, 0, i+1 );
         SHPDestroyObject( psShape );
      end;{For i := 0 to (ElementList.Count-1) do}
      SHPClose( hSHPHandle );
      DBFClose( hDBFHandle );

      ProgressBar1.Visible := false;
end;


{************************************************************************}
Procedure TForm1.BepaalOmringendeElementen;
   { Hiermee wordt uitgezocht welke elementen waarin de gezochte node
     voorkomt

   }
   var
      Element : PTriElement;
      Node : PTriNode;
      n,n1,n2,n3 : integer;
      StrElem : string;
      i,j,x :integer;

   Begin
      x := ElementList.count;
      n1 := x;
      ProgressBar1.min := 0;
      ProgressBar1.max:= ElementList.count-1;
      ProgressBar1.Visible := true;

      for i := 0 to (ElementList.count-1) do
      Begin
         ProgressBar1.position := i;
         Element := ElementList.items[i];
         With Element^do
         begin
            n1 := node1;
            n2 := node2;
            n3 := node3;
         end;
         for j := 1 to 3 do
         begin
            case j of
               1 : n := n1 ;
               2 : n := n2;
               3 : n := n3;
            else
               n := 0;
            end;

            Node := NodeList.items[n-1];
            StrElem := Node^.SubElementen;
            {de itemnummer uit de ElementList toevoegen!!!}
            StrElem := StrElem + ' ' + intToStr(i);
            Node^.SubElementen := StrElem
         end;
      end;
      ProgressBar1.Visible := false;

   end; {procedure BepaalOmringendeElementen}

Procedure TForm1.BepaalOmringendeNodes;
   { Hiermee wordt uitgezocht welke nodes om de centrale node liggen
   }
  FUNCTION CompareNode(Item1, Item2: Pointer): Longint;
   begin
      if PTriElement(Item1)^.node1<PTriElement(Item2)^.node1 then Result:=-1;
      if PTriElement(Item1)^.node1=PTriElement(Item2)^.node1 then Result:=0;
      if PTriElement(Item1)^.node1>PTriElement(Item2)^.node1 then Result:=+1;
   end;

   const

      CRLF = #13 + #10;

   var
      Element : PTriElement;
      Node, Nrec : PTriNode;
      ElemArr: array of integer;
      NodesInElementsList: TStringList;
      n,n1,n2,n3,nStart,nEind,nFrom,nTo,nZoek, nodeAantal,maxList : integer;
      Ab1, Ab2,Ab3:integer;
      AbList:TStringList;
      tmp : string;
      b, b1,b2,b3: byte; {randnode}
      regel,strVal, StrElem,StrNodes : string;
      i,j,jmax,x,xx,getal :integer;
      AantalElem,tempval : integer;
      NodesList : TList;
      gevonden: Boolean;
   begin
      ProgressBar1.Min := 1;
      ProgressBar1.Max := NodeList.Count;
      ProgressBar1.Visible := true;
      for i := 0 to (NodeList.count-1) do
      begin
          ProgressBar1.Position := i+1;
         {de elementnrs zijn als een string in de regel en gescheiden met
          een spatie. De echte elementnrs is 1 hoger, bijv het echte elementnr
          1 is als elementnr 0 in het geheugen. Dit i.v.m. met TList}
         if i = 175 then
            regel := '';

         Node := NodeList.items[i];
         regel := Node^.SubElementen;
         regel := trim(regel);          //eerste spatie verwijderen
         NodesList := TList.Create;
         j := 1;
         {de elementnrs als string worden als een getal in de ElemArr
          opgeslagen}
         Repeat
            setlength(ElemArr,j);
            if pos(' ',regel) = 0 then
            begin
               strVal := regel;
               regel := '';
            end
            else
            begin
               strVal := copy(regel,1,pos(' ',regel)-1);
               delete(regel,1, pos(' ',regel));
            end;
               try
                  Tempval := strtoInt(strVal);//StrToDateTime('99/99/1998');
               except
                on E: EConvertError do
                     ShowMessage(E.ClassName + CRLF + E.Message);
               end;
            ElemArr[j-1] := strtoInt(strVal);
            j := j + 1;
         until  length(regel) = 0;

         {de elementnrs zijn in ElemArr opgeslagen
         { Element is een record bestaande uit:
              node1;
              node2;
              node3.
         }
         NodesInElementsList:= TStringList.Create;
         ABList:= TStringList.Create;
         For j := 0 to  High(ElemArr) do
         begin
            getal := ElemArr[j];
            Element := ElementList.items[getal];
            NodesList.add(Element);
            With Element^ do
            begin
               n1 := node1;
               n2 := node2;
               n3 := node3;
            end;
            NodesInElementsList.Sorted := True;
            NodesInElementsList.Add(IntTostr(n1));
            NodesInElementsList.Add(IntTostr(n2));
            NodesInElementsList.Add(IntTostr(n3));
         end;
         for j := 0 to (NodesInElementsList.count-1)do
            ABList.Add('0');
         for j := 0 to  High(ElemArr) do
         begin
            getal := ElemArr[j];
            Element := ElementList.items[getal];
            With Element^ do
            begin
               n1 := node1;
               n2 := node2;
               n3 := node3;
            end;
            NodesInElementsList.Find(IntTostr(n1), x);
               tmp := ABList[x];
               tmp := IntToStr(StrToInt(tmp)+1);
               ABList[x] := tmp;
            NodesInElementsList.Find(IntTostr(n2), x);
               tmp := ABList[x];
               tmp := IntToStr(StrToInt(tmp)+1);
               ABList[x] := tmp;
            NodesInElementsList.Find(IntTostr(n3), x);
               tmp := ABList[x];
               tmp := IntToStr(StrToInt(tmp)+1);
               ABList[x] := tmp;
         end;

         {De nodelist bestaat dus nu uit de nodenrs van alle omringede
          elementen. Nu moet de volgorde worden bepaald}

         b := Node^.Rand; {wel (1) of geen (0) randnode}
         n := Node^.Id; {de nodenr}
         regel := ''; {lege regel voor SubElement wat de omringde nodenrs wordt}
         jmax := Nodeslist.count;
         if b = 1 then begin
               jmax := jmax + 1; {aantal te zoeken nodes}
               //regel := IntToStr(n);
               {aantal keren dat de unieke nodes voorkomen uitzoeken,
               indien >=2 then }
         end;

         j := 0;
         gevonden := false;
         {de start combinatie zoeken}
         Repeat
               j := j + 1;
               Element := NodesList.items[j-1];
               n1 := Element^.node1;
               n2 := Element^.node2;
               n3 := Element^.node3;
               Nrec :=NodeList.items[n1-1]; b1 := Nrec^.Rand;
               Nrec :=NodeList.items[n2-1]; b2 := Nrec^.Rand;
               Nrec :=NodeList.items[n3-1]; b3 := Nrec^.Rand;
               NodesInElementsList.Find(IntTostr(n1), x);
               Ab1 := StrToInt(ABList[x]);
               NodesInElementsList.Find(IntTostr(n2), x);
               Ab2 := StrToInt(ABList[x]);
               NodesInElementsList.Find(IntTostr(n3), x);
               Ab3 := StrToInt(ABList[x]);
               {de nodenummers beginnen bijj de randnodes
                De maximale randnodenr = RecAantal^.boundarynodes}
               if (n = RecAantal^.boundarynodes) then
               Begin
                  if (n = n3) and (b = 1) and (b1 = 1) and (n1 = 1) then begin
                     GEVONDEN := true;
                     nTo := n1;
                     nZoek := n2;
                  end
                  else if (n = n1) and (b = 1) and (b2 = 1) and (n2 = 1) then begin
                     GEVONDEN := true;
                     nTo := n2;
                     nZoek := n3;
                  end
                  else if (n = n2) and (b = 1) and (b3 = 1) and (n3 = 1) then begin
                     GEVONDEN := true;
                     nTo := n3;
                     nZoek := n1;
                  end
                  else
                     GEVONDEN := false;
               end
               else if (n = n1) and (b = 1) and (b2 = 1) and (n < n2) then begin
                     GEVONDEN := true;
                     nTo := n2;
                     nZoek := n3;
                  end
               else if (n = n1) and (b = 0) then begin
                  GEVONDEN := true;
                  nTo := n2;
                  nZoek := n3;
               end
               else if (n = n2) and (b = 0) then begin
                  GEVONDEN := true;
                  nTo := n3;
                  nZoek := n1;
               end
               else if (n = n3) and (b = 0) then begin
                  GEVONDEN := true;
                  nTo := n1;
                  nZoek := n2;
               end
               else if (n = n1) and (Nodeslist.count = 1) then begin
                  GEVONDEN := true;
                  nTo := n2;
                  nZoek := n3;
               end
               else if (n = n2) and (Nodeslist.count = 1) then begin
                  GEVONDEN := true;
                  nTo := n3;
                  nZoek := n1;
               end
               else if (n = n3) and (Nodeslist.count = 1) then begin
                  GEVONDEN := true;
                  nTo := n1;
                  nZoek := n2;
               end
               else
                  GEVONDEN := false;
         until gevonden;   {zoeken van de startnode}
         nStart := n;
         nFrom := n;
         regel := regel + ' ' + IntToStr(nTo);
         nEind := 0;
         j := 0;
         if b = 1 then NodeAantal := 1
         else NodeAantal := 1;
         maxList := Nodeslist.count;
         repeat
               j := j + 1;
               if maxList > 1 then begin
                  if ((j mod MaxList)= 0) then x := MaxList
                  else x := j mod maxList;
               end
               else
                  x := j;
               Element := NodesList.items[x -1];
               n1 := Element^.node1;
               n2 := Element^.node2;
               n3 := Element^.node3;
               Nrec :=NodeList.items[n1-1]; b1 := Nrec^.Rand;
               Nrec :=NodeList.items[n2-1]; b2 := Nrec^.Rand;
               Nrec :=NodeList.items[n3-1]; b3 := Nrec^.Rand;
               if (n1 = n) and (n2 = nTo) then begin
                  nTo := n3;
                  regel := regel + ' ' + IntTostr(nTo);
                  nodeAantal := NodeAantal + 1;
               end
               else if (n2 = n) and (n3 = nTo) then begin
                  nTo := n1;
                  regel := regel + ' ' + IntTostr(nTo);
                  nodeAantal := NodeAantal + 1;
               end
               else if (n3 = n) and (n1 = nTo) then begin
                  nTo := n2;
                  regel := regel + ' ' + IntTostr(nTo);
                  nodeAantal := NodeAantal + 1;
               end
         until (nodeAantal = jmax);
         Node^.SubElementen := regel; {alle omringende nodes}

         {de tijdelijke  TStringList leeg maken}
         NodesInElementsList.Clear;
         ABList.Clear;
      end; {for i }
      ProgressBar1.Visible := false;

   end;

PROCEDURE TForm1.SchrijfNIA( const aFileName: String );
  var
    uit       : AnsiString;
    o         : textfile;
    fo : textfile;
    j,getal,StrLen,StrAantal,StrDec,k,r,xx : integer;
    AantalRegels,AantalOverige: integer;
    Knoop,recNode1 : PTriNode;
    NodesList : TList;
    ShapePoints:Tlist;
    ElemArr: array of integer;
    Regel,strVal : string;
    StrCelWaarde :string;
    Xfrom, Xto,XLast : double;
    Yfrom, Yto,YLast : double;

    info, infokop, strMax,SetNaam : string;
    //Aantal : PTriAantal;
      tmpfloat :double;

    BoolShapeFile : boolean;
    {--------------------------------}
    hSHPHandle:  SHPHandle;
    hDBFHandle:  DBFHandle;
    psShape:	 PSHPObject;
    x,y,z,m:     TDoubleArray;
    anPartStart: TLongIntArray;
    anPartType:  TLongIntArray;
    panPartType: PLongInt;
    n, i, iShape:LongInt;
    nPoints,nSHPType : LongInt;
    {----------------------------------}
  Begin
    nSHPType := SHPT_POLYGON;
    BoolShapeFile := true;
    // het te schrijven bestand declaren
    uit := AnsiString( aFileName );
    // showmessage( 'uit= [' + uit + ']' );
    if BoolShapeFile then BEGIN
      hSHPHandle := SHPCreate( PAnsiChar(uit), nSHPType );
      hDBFHandle := DBFCreate( PAnsiChar(uit));
      DBFAddField(hDBFHandle,'ID',FTInteger,8,0);
    END
    ELSE BEGIN {generatefile}
	   AssignFile(O,UIT);
	   {$I-} Rewrite(O); {I$+}
    END;

    infokop := 'De begrenzing per knooppunt wegschrijven';
    MemoInfo.lines.add(infokop);

    ProgressBar1.Min := 1;
    ProgressBar1.Max := NodeList.Count;
    ProgressBar1.Visible := true;


    For r := 0 to (NodeList.count-1) do //(NodeList.count-1) do
    Begin
      nPoints := 0;
      ProgressBar1.Position := r+1;
      Knoop := NodeList.items[r];
      if BoolShapeFile then begin
        DBFWriteIntegerAttribute( hDBFHandle, r, 0, r+1 );
      end {boolshapefile}
      ELSE {GenerateFile}
         WriteLn(o,inttostr(Knoop^.Id));

      regel := trim(Knoop^.SubElementen);
      j := 1;
      {de elementnrs als string worden als een getal in de ElemArr
      opgeslagen}
      Repeat
            setlength(ElemArr,j);
            if pos(' ',regel) = 0 then
            begin
               strVal := regel;
               regel := '';
            end
            else
            begin
               strVal := copy(regel,1,pos(' ',regel)-1);
               delete(regel,1, pos(' ',regel));
            end;
            ElemArr[j-1] := strtoInt(strVal);
            j := j + 1;
      until  length(regel) = 0;

      if Knoop^.rand = 1 then
      Begin
         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1]:= Knoop^.xc; y[nPoints-1]:= Knoop^.yc;

         //Writeln(o,Knoop^.xc:14:4, ' ',Knoop^.yc:14:4);
         getal := ElemArr[0];
         recNode1 := NodeList.items[getal-1];

         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1] := (recNode1^.Xc + Knoop^.xc)/2;
         y[nPoints-1] := (recNode1^.Yc + Knoop^.yc)/2;

         //Write  (o, (recNode1^.Xc + Knoop^.XC)/2:14:4,' ');
         //WriteLn(o, (recNode1^.Yc + Knoop^.YC)/2:14:4);
         Xfrom :=recNode1^.Xc;
         YFrom :=recNode1^.Yc;
         For j := 1 to  High(ElemArr) do
         begin
            getal := ElemArr[j];
            recNode1 := NodeList.items[getal-1];

            inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
            x[nPoints-1] := (Knoop^.XC+Xfrom+recNode1^.Xc)/3;
            y[nPoints-1] := (Knoop^.YC+Yfrom+recNode1^.Yc)/3;
            //Write  (o, (Knoop^.XC+Xfrom+recNode1^.Xc)/3:14:4 , ' ');
            //WriteLn(o, (Knoop^.YC+Yfrom+recNode1^.Yc)/3:14:4);

            Xfrom :=recNode1^.Xc;
            YFrom :=recNode1^.Yc;

            inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
            x[nPoints-1] := (recNode1^.Xc + Knoop^.XC)/2;
            y[nPoints-1] := (recNode1^.Yc + Knoop^.YC)/2;
            //Write  (o, (recNode1^.Xc + Knoop^.XC)/2:14:4,' ');
            //WriteLn(o, (recNode1^.Yc + Knoop^.YC)/2:14:4);

         end;
         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1] := Knoop^.xc;
         y[nPoints-1] := Knoop^.yc;

         //Writeln(o, Knoop^.xc:14:4, ' ',Knoop^.yc:14:4);
         if BoolShapeFile then begin
            psShape := SHPCreateObject( nSHPType, -1, 0, NIL, NIL,
                                   nPoints, PDouble(x),PDouble(y),NIL,NIL);
            SHPWriteObject( hSHPHandle, -1, psShape );
            SHPDestroyObject( psShape );
         end
         else begin{generatefile}
            {for i := 0 to (thePoints.Count-1) do begin
               point := thePoints.Items[i];
               Writeln(o,point.X:14:4,' ',point.Y:14:4);
            end;}
            WriteLn(o, 'END');
         end;
      end
      else {geen randnode}
      begin
         getal := ElemArr[0];
         recNode1 := NodeList.items[getal-1];
         Xlast := recNode1^.Xc; YLast := recNode1^.Yc;
         Xfrom := XLast;
         Yfrom := YLast;

         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1]:= (Knoop^.xc + XFrom)/2;
         y[nPoints-1]:= (Knoop^.Yc + YFrom)/2;
         //Write  (o,(Knoop^.xc + XFrom)/2:14:4, ' ');
         //WriteLn(o,(Knoop^.Yc + YFrom)/2:14:4);

         getal := ElemArr[1];
         recNode1 := NodeList.items[getal-1];
         XTo   := recNode1^.Xc;
         YTo   := recNode1^.Yc;
         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1] := (Knoop^.xc + XFrom + XTo)/3;
         y[nPoints-1] := (Knoop^.Yc + YFrom + YTo)/3;
         //Write  (o,(Knoop^.xc + XFrom + XTo)/3:14:4, ' ');
         //WriteLn(o,(Knoop^.Yc + YFrom + YTo)/3:14:4, ' ');

         For j := 2 to High(ElemArr) do
         Begin
            XFrom := Xto;
            YFrom := YTo;

            inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
            x[nPoints-1]:= (Knoop^.xc + XFrom)/2;
            y[nPoints-1]:= (Knoop^.Yc + YFrom)/2;
            //Write  (o,(Knoop^.xc + XFrom)/2:14:4, ' ');
            //WriteLn(o,(Knoop^.Yc + YFrom)/2:14:4, ' ');

            getal := ElemArr[j];
            recNode1 := NodeList.items[getal-1];
            XTo   := recNode1^.Xc;
            YTo   := recNode1^.Yc;

            inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
            x[nPoints-1] := (Knoop^.xc + XFrom + XTo)/3;
            y[nPoints-1] := (Knoop^.Yc + YFrom + YTo)/3;
            //Write  (o,(Knoop^.xc + XFrom + XTo)/3:14:4, ' ');
            //WriteLn(o,(Knoop^.Yc + YFrom + YTo)/3:14:4, ' ');
         end;
         XFrom := Xto;
         YFrom := YTo;

         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1]:= (Knoop^.xc + XFrom)/2;
         y[nPoints-1]:= (Knoop^.Yc + YFrom)/2;
         //Write  (o,(Knoop^.xc + XFrom)/2:14:4, ' ');
         //WriteLn(o,(Knoop^.Yc + YFrom)/2:14:4, ' ');

         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1]  := (Knoop^.xc + XFrom + XLast)/3;
         y[nPoints-1]  := (Knoop^.Yc + YFrom + YLast)/3;
         //Write  (o,(Knoop^.xc + XFrom + XLast)/3:14:4, ' ');
         //WriteLn(o,(Knoop^.Yc + YFrom + YLast)/3:14:4, ' ');

         inc(nPoints); SetLength(x,nPoints); SetLength(y,nPoints);
         x[nPoints-1] := (Knoop^.xc + XLast)/2;
         y[nPoints-1] := (Knoop^.Yc + YLast)/2;
         //Write  (o,(Knoop^.xc + XLast)/2:14:4, ' ');
         //WriteLn(o,(Knoop^.Yc + YLast)/2:14:4);
         //WriteLn(o, 'END'); {alle punten zijn berekend}
         {----------------------------------------------------------}
         if BoolShapeFile then begin
            psShape := SHPCreateObject( nSHPType, -1, 0, NIL, NIL,
                                   nPoints, PDouble(x),PDouble(y),NIL,NIL);
            SHPWriteObject( hSHPHandle, -1, psShape );
            SHPDestroyObject( psShape );
         end
         else begin{generatefile}
            {for i := 0 to (thePoints.Count-1) do begin
               point := thePoints.Items[i];
               Writeln(o,point.X:14:4,' ',point.Y:14:4);
            end; }
            WriteLn(o, 'END');
         end;
         {----------------------------------------------------------}
      end; {else geen randnode}
    End;
    if BoolShapeFile then begin
      SHPClose( hSHPHandle );
      DBFClose( hDBFHandle );
    end
    else begin {generatefile}
      WriteLn(o, 'END');
      CloseFile(o);
    end;
    Info := info + #13#10 + 'Parameterbestand ''' + uit + ''' gemaakt.';
    MemoInfo.lines.add(info);
    ProgressBar1.Visible := false;

  End;   {SchrijfNIA}

procedure TForm1.ClearList;
var
  ListIndex : integer;
  Index:Integer;
  LeegList :TList;
begin
 for ListIndex := 1 to 2 do
 begin
   case ListIndex of
      1 : LeegList := NodeList;
      2 : LeegList := ElementList;
   else
      LeegList := nil;
   end;

   for Index:=0 to LeegList.Count-1 do
   begin
      Dispose(LeegList[Index]);
   end;
   LeegList.Free;
   LeegList:=nil;
 end;
 {
   for Index:=0 to NodeList.Count-1 do
   begin
      Dispose(NodeList[Index]);
   end;
   NodeList.Free;
   NodeList:=nil;

   for Index:=0 to ElementList.Count-1 do
   begin
      Dispose(ElementList[Index]);
   end;
   ElementList.Free;
   ElementList:=nil;
 }
   MemoInfo.lines.add('Klaar met maken van bestand.');
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
 InitialiseLogFile;
 Caption :=  ChangeFileExt( ExtractFileName( Application.ExeName ), '' );
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FinaliseLogFile;
end;

procedure TForm1.SchrijfFEMfile( const aFileName: String );
  var
    uit       : AnsiString;
    o         : textfile;
    j,getal,StrLen,StrAantal,StrDec,k,r,xx : integer;
    Knoop: PTriNode;
    ElemArr: array of integer;
    Regel,strVal : string;
    StrCelWaarde :string;
    Xfrom, Xto,XLast : double;
    Yfrom, Yto,YLast : double;

    info, infokop, strMax,SetNaam : string;
    //Aantal : PTriAantal;
      tmpfloat :double;

    BoolShapeFile : boolean;
    {--------------------------------}
    hFEMHandle:  textFile; {microfembestand}
    x,y,z,m:     TDoubleArray;
    anPartStart: TLongIntArray;
    anPartType:  TLongIntArray;
    panPartType: PLongInt;
    n, i, iShape:LongInt;
    nPoints,nSHPType : LongInt;
    {----------------------------------}
  Begin
  with FormatSettings do begin {-Delphi XE6}
    DecimalSeparator    := '.';
  end;

    BoolShapeFile := true;
    // het te schrijven bestand declaren
    uit := AnsiString( aFileName );
    if BoolShapeFile then BEGIN
      uit := lowercase(changeFileExt(uit,'.fem'));
      assignfile(hFEMHandle,uit);
	   {$I-} Rewrite(hFEMHandle); {I$+}
    END
    ELSE BEGIN {generatefile}
	   AssignFile(O,UIT);
	   {$I-} Rewrite(O); {I$+}
    END;

    infokop := 'De begrenzing per knooppunt wegschrijven';
    MemoInfo.lines.add(infokop);


    WriteLn(hFEMHandle,'Micro-fem FiniteElement File from TriwacoGrid');
    WriteLn(hFEMHandle,'Project');
    WriteLn(hFEMHandle,'model');
    WriteLn(hFEMHandle,'location');
    WriteLn(hFEMHandle,'date');
    WriteLn(hFEMHandle,'remark');
    WriteLn(hFEMHandle,'remark');
    WriteLn(hFEMHandle,'remark');
    WriteLn(hFEMHandle,'date name');
    WriteLn(hFEMHandle,'filename');
    WriteLn(hFEMHandle,'disk name');
    WriteLn(hFEMHandle,'investigator');
    WriteLn(hFEMHandle,'date');
    WriteLn(hFEMHandle,'remark');
    WriteLn(hFEMHandle,'remark');

    {node# element# aquifer# nonzero-discharge#}
    Write(hFEMHandle,RecAantal^.nodes, ' ');
    Write(hFEMHandle,RecAantal^.elements, ' ');
    Write(hFEMHandle,'1', ' '); {fictief watervoerend pakket}
    WriteLn(hFEMHandle,'0');

    {maximum minimum coordinaten}
    Write  (hFEMHandle,formatFloat('0.00',TriRange^.maxX));
    WriteLn(hFEMHandle,' ',formatFloat('0.00',TriRange^.minX));
    Write  (hFEMHandle,formatFloat('0.00',TriRange^.maxY));
    WriteLn(hFEMHandle,' ',formatFloat('0.00',TriRange^.minY));
    {één of andere stringnr}
    WriteLn(hFEMHandle,' 712372699   712372699');

    {Vanaf hier alle knoooppunten wegschrijven}

    ProgressBar1.Min := 1;
    ProgressBar1.Max := NodeList.Count;
    ProgressBar1.Visible := true;

    For r := 0 to (NodeList.count-1) do //(NodeList.count-1) do
    Begin
      nPoints := 0;
      ProgressBar1.Position := r+1;
      Knoop := NodeList.items[r];
      {regel 1 node X}
      Write(hFEMHandle,inttostr(Knoop^.Rand), ' ');
      Write(hFEMHandle,FormatFloat('0.00',Knoop^.xc), ' ');  {x-coord}
      Write(hFEMHandle,FormatFloat('0.00',Knoop^.yc), ' ');  {y-coord}
      Write(hFEMHandle,'10 ');                               {phi-0}
      Write(hFEMHandle,'0 10');                              {fixed? phi-1}
      WriteLn(hFEMHandle);

      {regel 2 node X}
      Write(hFEMHandle,'100 ');                                {aquitard}
      Write(hFEMHandle,'2000');                                {aquifer}
      WriteLn(hFEMHandle);

      {regel 3 node X}
      regel := trim(Knoop^.SubElementen);
      j := 1;
      {de elementnrs als string worden als een getal in de ElemArr
      opgeslagen}
      Repeat
            setlength(ElemArr,j);
            if pos(' ',regel) = 0 then
            begin
               strVal := regel;
               regel := '';
            end
            else
            begin
               strVal := copy(regel,1,pos(' ',regel)-1);
               delete(regel,1, pos(' ',regel));
            end;
            ElemArr[j-1] := strtoInt(strVal);
            j := j + 1;
      until  length(regel) = 0;

      {regel opnieuw initialiseren}
      regel := IntToStr(j) + ' '; {number of neighboring nodes + 1}
      regel := regel + IntToStr(r+1) + ' ' ;     {node in question}
      //Write(hFEMHandle,j, ' ');
      //Write(hFEMHandle, r+1, ' ');


      //Writeln(o,Knoop^.xc:14:4, ' ',Knoop^.yc:14:4);
      for j := low(ElemArr) to high(ElemArr) do begin
         getal := ElemArr[j];
         //recNode1 := NodeList.items[getal-1];
         regel := regel + IntToStr(getal) + ' ';
         //Write(hFEMHandle, getal , ' '); {node in question}
      end;
      regel := trim(regel);
      WriteLn(hFEMHandle,regel);
    end;
    if BoolShapeFile then begin
      Closefile( hFEMHandle );
    end
    else begin {generatefile}
      WriteLn(o, 'END');
      CloseFile(o);
    end;
    Info := info + #13#10 + 'MICRO-FEM bestand ''' + uit + ''' gemaakt.';
    MemoInfo.lines.add(info);
    ProgressBar1.Visible := false;

  End;   {SchrijfNIA}

begin
  with FormatSettings do begin {-Delphi XE6}
    DecimalSeparator    := '.';
  end;
end.
