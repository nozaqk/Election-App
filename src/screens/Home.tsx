import { Me, Overview } from "../api";
import { byImportance } from "../useOverview";
import { ElectionCard } from "./ElectionCard";

export function Home({ me, data, err, skew, onOpen, onAll }: { me: Me | null; data: Overview | null; err: string | null; skew: number; onOpen: (id: string) => void; onAll: () => void }) {
  const top = data ? byImportance(data.elections)[0] : undefined;
  return (
    <>
      {me && <p className="muted">Welcome, <b>{me.fullName}</b><br />{me.programme} · Level {me.level}{me.semester ? ` · Semester ${me.semester}` : ""}</p>}
      {err && <div className="err" role="alert">{err}</div>}
      {!data && !err && <p className="muted">Loading…</p>}
      {data?.empty && <div className="card"><h2>{data.empty.headline}</h2><p className="muted">{data.empty.body}</p></div>}
      {top && <>
        <h3 className="section">Happening now</h3>
        <ElectionCard e={top} skew={skew} onOpen={() => onOpen(top.id)} />
        {data!.elections.length > 1 && <button className="btn secondary" onClick={onAll}>See all elections ({data!.elections.length})</button>}
      </>}
    </>
  );
}
