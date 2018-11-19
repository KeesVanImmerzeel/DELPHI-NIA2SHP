object Form1: TForm1
  Left = 263
  Top = 120
  Caption = 
    'Make a polygon shapefile of the InfluenceArea of a Triwaco-netwo' +
    'rk'
  ClientHeight = 613
  ClientWidth = 886
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -10
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Visible = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object TLabel
    Left = 20
    Top = 26
    Width = 3
    Height = 13
  end
  object Label1: TLabel
    Left = 53
    Top = 145
    Width = 32
    Height = 13
    Caption = 'Label1'
    Visible = False
  end
  object GoButton: TButton
    Left = 707
    Top = 385
    Width = 118
    Height = 46
    Hint = 'Starts allocating griddata'
    Caption = 'Start'
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    OnClick = GoButtonClick
  end
  object MemoInfo: TMemo
    Left = 53
    Top = 164
    Width = 772
    Height = 181
    Lines.Strings = (
      'MemoInfo')
    TabOrder = 1
  end
  object ProgressBar1: TProgressBar
    Left = 53
    Top = 358
    Width = 772
    Height = 13
    TabOrder = 2
  end
  object LabeledEditTriwacoGridFileName: TLabeledEdit
    Left = 53
    Top = 96
    Width = 772
    Height = 21
    EditLabel.Width = 105
    EditLabel.Height = 13
    EditLabel.Caption = 'Triwaco Grid Filename'
    TabOrder = 3
    Text = 'Grid.teo'
    OnClick = LabeledEditTriwacoGridFileNameClick
  end
  object OpenDialog1: TOpenDialog
    DefaultExt = '*.teo'
    FileName = 'grid.teo'
    Filter = '*.teo|*.teo'
    Title = 'Specify Triwaco Gridfile'
    Left = 304
    Top = 8
  end
  object SaveDialog1: TSaveDialog
    Left = 552
    Top = 8
  end
end
