import { Overview } from "../api";
import { byImportance } from "../useOverview";

export function News({ data, err, onOpen }: { data: Overview | null; err: string | null; onOpen: (id: string) => void }) {
  return (
    <>
      <h2 className="page">News</h2>
      {err && <div className="err" role="alert">{err}</div>}
      {!data && !err && <p className="muted">Loading…</p>}
      {data && data.elections.length === 0 && <div className="card"><h3>No news yet</h3><p className="muted">Election announcements and results will appear here.</p></div>}
      {data && byImportance(data.elections).map((e) => (
        <article className="card news" key={e.id}>
          <div className="row"><span className="muted">{e.title}</span><span className={`pill ${e.status}`}>{e.status === "ACTIVE" ? "Voting open" : e.status.toLowerCase()}</span></div>
          <h3>{e.ui.headline}</h3>
          <p className="muted" style={{ whiteSpace: "pre-line", marginTop: 0 }}>{e.ui.body}</p>
          {e.startLabel && e.endLabel && <p className="muted">Voting: {e.startLabel} to {e.endLabel}</p>}
          <button className="link" onClick={() => onOpen(e.id)}>{e.status === "PUBLISHED" ? "View results" : "Open election"} →</button>
        </article>
      ))}
    </>
  );
}
