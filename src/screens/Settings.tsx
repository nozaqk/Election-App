import { FormEvent, useEffect, useState } from "react";
import { api, ApiError, Me } from "../api";

const LEVELS = [100, 200, 300, 400, 500, 600];

export function Settings({ me, onSaved, onSignOut }: { me: Me | null; onSaved: (m: Me) => void; onSignOut: () => void }) {
  const [level, setLevel] = useState<number>(me?.level ?? 100);
  const [semester, setSemester] = useState<number>(me?.semester ?? 1);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  useEffect(() => { if (me) { setLevel(me.level); setSemester(me.semester ?? 1); } }, [me]);

  async function save(e: FormEvent) {
    e.preventDefault(); setBusy(true); setMsg(null);
    try {
      const m = await api<Me>("/auth/student/profile", { method: "PATCH", body: { level, semester } });
      onSaved(m); setMsg({ ok: true, text: "Saved. Your level and semester are updated." });
    } catch (x) { setMsg({ ok: false, text: (x as ApiError).message }); }
    finally { setBusy(false); }
  }

  const levels = LEVELS.includes(level) ? LEVELS : [...LEVELS, level].sort((a, b) => a - b);
  const changed = !!me && (level !== me.level || semester !== (me.semester ?? 1) || me.semester === null);
  return (
    <>
      <h2 className="page">Settings</h2>
      <section className="card">
        <h3>My account</h3>
        {!me ? <p className="muted">Loading…</p> : (
          <dl className="kv">
            <dt>Name</dt><dd>{me.fullName}</dd>
            <dt>Index number</dt><dd>{me.indexNumber}</dd>
            <dt>Department</dt><dd>{me.department}</dd>
            <dt>Programme</dt><dd>{me.programme}</dd>
          </dl>
        )}
        <p className="muted">These details come from the official student register. To correct them, contact the Electoral Commission.</p>
      </section>
      <form className="card" onSubmit={save}>
        <h3>Level and semester</h3>
        {msg && <div className={msg.ok ? "notice" : "err"} role="alert">{msg.text}</div>}
        <label className="field"><span>Level</span>
          <select value={level} onChange={(e) => setLevel(Number(e.target.value))}>{levels.map((l) => <option key={l} value={l}>Level {l}</option>)}</select></label>
        <label className="field"><span>Semester</span>
          <select value={semester} onChange={(e) => setSemester(Number(e.target.value))}><option value={1}>Semester 1</option><option value={2}>Semester 2</option></select></label>
        <button className="btn" disabled={busy || !me || !changed}>{busy ? "Saving…" : "Save changes"}</button>
        <p className="muted" style={{ marginBottom: 0 }}>This updates your profile. Which elections you can vote in is still decided by the official student register.</p>
      </form>
      <section className="card">
        <h3>About</h3>
        <p className="muted" style={{ margin: 0 }}>All election times are shown in Ghana time (Africa/Accra). Your votes are private and cannot be linked back to you.</p>
      </section>
      <button className="btn danger" onClick={onSignOut}>Sign out</button>
    </>
  );
}
