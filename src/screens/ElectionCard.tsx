import { ElectionSummary } from "../api";
import { Countdown } from "../components";

export function ElectionCard({ e, skew, onOpen }: { e: ElectionSummary; skew: number; onOpen: () => void }) {
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
