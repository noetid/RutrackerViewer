unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Grids, ComCtrls, lclintf, DateUtils, fileutil, Clipbrd;

type

  { TForm1 }

  TForm1 = class(TForm)
    cmbCategory: TComboBox;
    edtQuery: TEdit;
    RuTrackerCon: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    StatusBar1: TStatusBar;
    stgTorrentInfo: TStringGrid;

    procedure edtQueryClick(Sender: TObject);
    procedure edtQueryKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure stgTorrentInfoDblClick(Sender: TObject);
    procedure stgTorrentInfoPrepareCanvas(Sender: TObject; aCol, aRow: integer;
      aState: TGridDrawState);
    procedure stgTorrentInfoSelectCell(Sender: TObject; aCol, aRow: integer;
      var CanSelect: boolean);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }


procedure TForm1.edtQueryClick(Sender: TObject);
begin
  edtQuery.SelectAll;
end;

procedure TForm1.edtQueryKeyPress(Sender: TObject; var Key: char);
const
  MAX_TORRENTS = 200;
var
  query: string;
  cnt: integer;
  DataTime: TStringArray;
begin
  if Key = #13 then
  begin
    query := Trim(edtQuery.Text);
    if query = '' then
    begin
      StatusBar1.Panels[0].Text := 'Введите запрос';
      edtQuery.SetFocus;
      exit;
    end;
    RuTrackerCon.Close;
    SQLQuery1.Close;
    if cmbCategory.ItemIndex < 1 then
      SQLQuery1.SQL.Text :=
        'SELECT torrent.title as title, CAST(torrent.size_b as BIGINT) as size, torrent.hash_info as hash, '
        + 'forum.name_forum as forumname,category.name_category as catname, torrent.date_reg as date_reg FROM torrent '
        + 'INNER JOIN forum on torrent.forum_id=forum.code_forum ' +
        'INNER JOIN category on forum.category_id=category.code_category ' +
        'WHERE torrent.title LIKE :query ORDER by torrent.date_reg DESC LIMIT ' +
        IntToStr(MAX_TORRENTS) + ';'
    else
    begin
      SQLQuery1.SQL.Text :=
        'SELECT torrent.title as title, CAST(torrent.size_b as BIGINT) as size, torrent.hash_info as hash, '
        + 'forum.name_forum as forumname,category.name_category as catname, torrent.date_reg as date_reg FROM torrent '
        + 'INNER JOIN forum on torrent.forum_id=forum.code_forum ' +
        'INNER JOIN category on forum.category_id=category.code_category ' +
        'WHERE category.name_category=:name_category AND torrent.title LIKE :query ORDER by torrent.date_reg DESC LIMIT '
        +
        IntToStr(MAX_TORRENTS) + ';';
      SQLQuery1.ParamByName('name_category').AsString :=
        cmbCategory.Items[cmbCategory.ItemIndex];
    end;
    SQLQuery1.ParamByName('query').AsString := '%' + query + '%';
    SQLQuery1.Open;
    SQLQuery1.First;
    stgTorrentInfo.RowCount := MAX_TORRENTS + 100;
    cnt := 0;
    while not SQLQuery1.EOF do
    begin
      Inc(cnt);
      stgTorrentInfo.Cells[0, cnt] := IntToStr(cnt);
      stgTorrentInfo.Cells[1, cnt] := SQLQuery1.FieldByName('title').AsString;
      stgTorrentInfo.Cells[2, cnt] :=
        IntToStr(Trunc(SQLQuery1.FieldByName('size').AsLargeInt / 1024 / 1024));
      stgTorrentInfo.Cells[3, cnt] :=
        Format('%s / %s', [SQLQuery1.FieldByName('forumname').AsString,
        SQLQuery1.FieldByName('catname').AsString]);
      DataTime := SQLQuery1.FieldByName('date_reg').AsString.Split(' ');
      stgTorrentInfo.Cells[4, cnt] := DataTime[0];
      SQLQuery1.Next;
    end;
    stgTorrentInfo.RowCount := cnt + 1;
    if cnt = 0 then
      StatusBar1.Panels[0].Text :=
        'Ничего не найдено. Попробуйте изменить (сузить) запрос.'
    else if cnt = MAX_TORRENTS then
      StatusBar1.Panels[0].Text :=
        Format('Выдано максимум %d записей /', [MAX_TORRENTS])
    else
      StatusBar1.Panels[0].Text := Format('Всего %d записей', [cnt]);
    edtQuery.SelectAll;
    edtQuery.SetFocus;
  end;

end;

procedure TForm1.FormCreate(Sender: TObject);
var
  cnt: integer;
begin
  if not FileExists(RuTrackerCon.DatabaseName) then
  begin
    MessageDlg('Database torrents.db3 not exist!' + sLineBreak +
      'https://disk.yandex.ru/d/EPd4aUMWzv2aSQ', mtError, mbOKCancel, 0);
    Halt;
  end;
  edtQuery.SelectAll;
  RuTrackerCon.Close;
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := 'SELECT name_category from category';
  SQLQuery1.Open;
  SQLQuery1.First;
  cnt := 0;
  cmbCategory.Items.Add('Все торренты');
  while not SQLQuery1.EOF do
  begin
    Inc(cnt);
    cmbCategory.Items.Add(SQLQuery1.FieldByName('name_category').AsString);
    SQLQuery1.Next;
  end;
  stgTorrentInfo.Options := stgTorrentInfo.Options + [goRowSelect];
  stgTorrentInfo.ColWidths[0] := 30;
  stgTorrentInfo.ColWidths[2] := 100;
  stgTorrentInfo.ColWidths[3] := 300;
  stgTorrentInfo.ColWidths[4] := 100;
  stgTorrentInfo.ColWidths[1] := stgTorrentInfo.Width - 100 * 2 - 300 - 30;

end;

procedure TForm1.FormResize(Sender: TObject);
begin
  stgTorrentInfo.ColWidths[0] := 30;
  stgTorrentInfo.ColWidths[2] := 100;
  stgTorrentInfo.ColWidths[3] := 300;
  stgTorrentInfo.ColWidths[4] := 100;
  stgTorrentInfo.ColWidths[1] := stgTorrentInfo.Width - 100 * 2 - 300 - 30;
end;

procedure TForm1.stgTorrentInfoDblClick(Sender: TObject);
var
  title: string;
begin
  // Open selected torrent magnet link and copy it to clipboard
  title := stgTorrentInfo.Cells[1, stgTorrentInfo.Row];
  RuTrackerCon.Close;
  SQLQuery1.Close;
  SQLQuery1.SQL.Text := 'SELECT hash_info from torrent WHERE title=:title';
  SQLQuery1.ParamByName('title').AsString := title;
  SQLQuery1.Open;
  SQLQuery1.First;
  OpenURL(Format('magnet:?xt=urn:btih:%s', [SQLQuery1.FieldByName(
    'hash_info').AsString]));
  Clipboard.AsText := Format('magnet:?xt=urn:btih:%s',
    [SQLQuery1.FieldByName('hash_info').AsString]);
  edtQuery.SelectAll;
  edtQuery.SetFocus;
end;

procedure TForm1.stgTorrentInfoPrepareCanvas(Sender: TObject;
  aCol, aRow: integer; aState: TGridDrawState);
var
  ts: TTextStyle;
begin
  // Center column title text for readability
  if ((aCol = 2) or (aCol = 4)) or (arow = 0) then
  begin
    ts := TStringGrid(Sender).Canvas.TextStyle;
    ts.Alignment := taCenter;
    TStringGrid(Sender).Canvas.TextStyle := ts;
  end;
end;

procedure TForm1.stgTorrentInfoSelectCell(Sender: TObject; aCol, aRow: integer;
  var CanSelect: boolean);
begin
  // Selected torrent title
  StatusBar1.Panels[1].Text := stgTorrentInfo.Cells[1, aRow];
end;

end.
