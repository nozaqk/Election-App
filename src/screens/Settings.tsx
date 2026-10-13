import { Me } from "../api";

export function Settings({ me, onSignOut }: { me: Me | null; onSignOut: () => void }) {
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
            <dt>Level</dt><dd>{me.level}</dd>
          </dl>
        )}
        <p className="muted">These details come from the official student register. To correct them, contact the Electoral Commission.</p>
      </section>
      <section className="card">
        <h3>About</h3>
        <p className="muted" style={{ margin: 0 }}>All election times are shown in Ghana time (Africa/Accra). Your votes are private and cannot be linked back to you.</p>
      </section>
      <button className="btn danger" onClick={onSignOut}>Sign out</button>
    </>
  );
}
