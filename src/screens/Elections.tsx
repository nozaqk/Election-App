import { Overview } from "../api";
import { byImportance } from "../useOverview";
import { ElectionCard } from "./ElectionCard";

export function Elections({ data, err, skew, onOpen }: { data: Overview | null; err: string | null; skew: number; onOpen: (id: string) => void }) {
  return (
    <>
      <h2 className="page">Elections</h2>
      {err && <div className="err" role="alert">{err}</div>}
      {!data && !err && <p className="muted">Loading elections…</p>}
      {data?.empty && <div className="card"><h2>{data.empty.headline}</h2><p className="muted">{data.empty.body}</p></div>}
      {data && byImportance(data.elections).map((e) => <ElectionCard key={e.id} e={e} skew={skew} onOpen={() => onOpen(e.id)} />)}
    </>
  );
}
