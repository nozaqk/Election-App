import { useEffect, useRef, useState } from "react";
import { api, ApiError, ElectionSummary, Me, Overview } from "../api";
import { Countdown } from "../components";

const POLL_MS = 10_000;

export function Home({ me, onOpen }: { me: Me | null; onOpen: (id: string) => void }) {
  const [data, setData] = useState<Overview | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const skew = useRef(0);

  useEffect(() => {
    let alive = true;
    const load = async () => {
      try {
        const o = await api<Overview>("/student/overview");
        if (!alive) return;
        skew.current = new Date(o.serverTime).getTime() - Date.now();
        setData(o); setErr(null);
      } catch (e) { if (alive) setErr((e as ApiError).message); }
    };
    load();
    const t = setInterval(load, POLL_MS);
    const vis = () => document.visibilityState === "visible" && load();
    document.addEventListener("visibilitychange", vis);
    return () => { alive = false; clearInterval(t); document.removeEventListener("visibilitychange", vis); };
  }, []);

  return (
    <>
      {me && <p className="muted">Welcome, <b>{me.fullName}</b><br />{me.programme} · Level {me.level}</p>}
      {err && <div className="err" role="alert">{err}</div>}
      {!data && !err && <p className="muted">Loading elections…</p>}
      {data?.empty && (
        <div className="card"><h2>{data.empty.headline}</h2><p className="muted">{data.empty.body}</p></div>
      )}
      {data?.elections.map((e) => <Card key={e.id} e={e} skew={skew.current} onOpen={() => onOpen(e.id)} />)}
    </>
  );
}

function Card({ e, skew, onOpen }: { e: ElectionSummary; skew: number; onOpen: () => void }) {
  return (
    <section className="card">
      <div className="row"><h2>{e.title}</h2><span className={`pill ${e.status}`}>{e.status === "ACTIVE" ? "Voting open" : e.status.toLowerCase()}</span></div>
      <p style={{ fontWeight: 700, margin: "8px 0 2px" }}>{e.ui.headline}</p>
      <p className="muted" style={{ whiteSpace: "pre-line", marginTop: 0 }}>{e.ui.body}</p>
      {e.status === "SCHEDULED" && e.startAt && <><div className="muted">Voting opens in</div><Countdown to={new Date(e.startAt).getTime()} skew={skew} /></>}
      {e.hasVoted && <p className="notice">✓ You have voted in this election.</p>}
      <button className="btn" style={{ marginTop: 12 }} onClick={onOpen}>{e.canVote ? "Vote Now" : e.status === "PUBLISHED" ? "View results" : "View details"}</button>
    </section>
  );
}
