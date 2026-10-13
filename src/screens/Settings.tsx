import { FormEvent, useState } from "react";
import { api, ApiError, Me } from "../api";

const LEVELS = [100, 200, 300, 400, 500, 600];

export function Settings({ me, onSaved, onSignOut }: { me: Me | null; onSaved: (m: Me) => void; onSignOut: () => void }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState("");
  const [level, setLevel] = useState(100);
  const [semester, setSemester] = useState(1);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  function startEdit() {
    if (!me) return;
    setName(me.fullName); setLevel(me.level); setSemester(me.semester ?? 1); setMsg(null); setEditing(true);
  }

  async function save(e: FormEvent) {
    e.preventDefault(); setBusy(true); setMsg(null);
    try {
      const m = await api<Me>("/auth/student/profile", { method: "PATCH", body: { fullName: name.trim(), level, semester } });
      onSaved(m); setEditing(false); setMsg({ ok: true, text: "Saved." });
    } catch (x) { setMsg({ ok: false, text: (x as ApiError).message }); }
    finally { setBusy(false); }
  }

  const levels = LEVELS.includes(level) ? LEVELS : [...LEVELS, level].sort((a, b) => a - b);
  return (
    <>
      <h2 className="page">Settings</h2>
      <section className="card">
        <div className="card-head">
          <h3>My account</h3>
          {me && !editing && <button type="button" className="link-btn" onClick={startEdit}>Edit</button>}
        </div>
        {msg && <div className={msg.ok ? "notice" : "err"} role="alert">{msg.text}</div>}
        {!me ? <p className="muted">Loading…</p> : editing ? (
          <form onSubmit={save}>
            <label className="field"><span>Name</span>
              <input value={name} onChange={(e) => setName(e.target.value)} minLength={2} maxLength={100} required /></label>
            <label className="field"><span>Level</span>
              <select value={level} onChange={(e) => setLevel(Number(e.target.value))}>{levels.map((l) => <option key={l} value={l}>Level {l}</option>)}</select></label>
            <label className="field"><span>Semester</span>
              <select value={semester} onChange={(e) => setSemester(Number(e.target.value))}><option value={1}>Semester 1</option><option value={2}>Semester 2</option></select></label>
            <button className="btn" disabled={busy || name.trim().length < 2}>{busy ? "Saving…" : "Save changes"}</button>
            <button type="button" className="btn secondary" disabled={busy} onClick={() => setEditing(false)}>Cancel</button>
          </form>
        ) : (
          <dl className="kv">
            <dt>Name</dt><dd>{me.fullName}</dd>
            <dt>Index number</dt><dd>{me.indexNumber}</dd>
            <dt>Department</dt><dd>{me.department}</dd>
            <dt>Programme</dt><dd>{me.programme}</dd>
            <dt>Level</dt><dd>Level {me.level}</dd>
            <dt>Semester</dt><dd>{me.semester ? `Semester ${me.semester}` : "Not set"}</dd>
          </dl>
        )}
        <p className="muted" style={{ marginBottom: 0 }}>Only your name, level and semester can be changed here, and only on your profile. Department, programme and which elections you can vote in come from the official student register.</p>
      </section>
      <section className="card">
        <h3>About</h3>
        <p className="muted" style={{ margin: 0 }}>All election times are shown in Ghana time (Africa/Accra). Your votes are private and cannot be linked back to you.</p>
      </section>
      <button className="btn danger" onClick={onSignOut}>Sign out</button>
    </>
  );
}
