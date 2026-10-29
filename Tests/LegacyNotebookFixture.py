import sqlite3,json,os,sys
p=sys.argv[1];os.makedirs(p,exist_ok=True)
d=sqlite3.connect(os.path.join(p,'WorkOS.sqlite'))
d.execute('''CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, title TEXT NOT NULL, body_plain TEXT NOT NULL, type_id TEXT NOT NULL, book_id TEXT NOT NULL, note_date TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL, raw_json TEXT NOT NULL)''')
raw={'id':'old-note-id','title':'Legacy','body':'Legacy body','typeId':'type-note','bookId':'book-A','bodyFormat':'markdown','noteDate':'2026-10-27','status':'진행 중','createdAt':'2026-10-27T00:00:00.000Z','updatedAt':'2026-10-27T00:00:00.000Z','deletedAt':''}
d.execute('INSERT INTO notes VALUES (?,?,?,?,?,?,?,?,?)',('old-note-id','Legacy','Legacy body','type-note','book-A','2026-10-27','2026-10-27T00:00:00.000Z','',json.dumps(raw)))
d.commit();d.close()
