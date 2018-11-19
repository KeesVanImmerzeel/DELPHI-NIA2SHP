program NIA2SHP;

uses
  Forms,
  Sysutils,
  Dialogs,
  IniFiles,
  uError,
  system.UItypes,
  CheckNumeric in 'CheckNumeric.pas',
  Ogridteo in 'Ogridteo.pas',
  grd2area in 'grd2area.pas' {Form1};

var
  FileExt, S: String;
  Myfini : TiniFile;

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Try
    Try
      Mode := Interactive;
      if ( ParamCount = 1 ) and FileExists( ParamStr( 1 ) ) then begin
        WriteToLogFile(  'Text if mode is batch');
        FileExt := Uppercase( ExtractFileExt( ParamStr( 1 ) ) );
        WriteToLogFile(  'FileExt = ' + FileExt );
        S := '';
        if SameStr( FileExt, '.CFG' ) then begin
           WriteToLogFile(  'CFG-file specified.' );
           Myfini := TIniFile.Create( ExpandFileName( ParamStr( 1 ) ) );
           S := Myfini.ReadString( 'Allocator', 'gridfile', 'Error');
           WriteToLogFile(  'String read from CFG file: ' + S );
           if ( S <> 'Error' ) and ( FileExists( S ) ) then begin
             S := ExpandFileName( S );
             WriteToLogFile(  'File found: [' + S + ']' );
           end else begin
             WriteToLogFile(  'File NOT found: [' + S + ']' );
             S := '';
           end;
           Myfini.Free;
        end else
          if SameStr( FileExt, '.TEO' )  then
            S := ExpandFileName( ParamStr( 1 ) );
        if ( S <> '' ) then begin
          Mode := Batch;
          Form1.LabeledEditTriwacoGridFileName.Text := S;
          WriteToLogFile(  'Mode = Batch, Triwaco grid file = [' + S + ']' );
        end;
      end;
      if ( Mode = Interactive ) then begin
        Application.Run;
      end else begin
        Form1.Visible := False;
        Form1.GoButton.Click;
      end;

    Except
      Try WriteToLogFile(  Format( 'Error in application: [%s].', [Application.ExeName] ) ); except end;
      MessageDlg( Format( 'Error in application: [%s].', [Application.ExeName] ), mtError, [mbOk], 0);
    end;
  Finally

  end;

end.
