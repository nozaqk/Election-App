import { useEffect, useState } from "react";
import { api, ApiError, ElectionDetail, Position, Results } from "../api";
import { Avatar, Countdown } from "../components";
import { hasNative, NativeError, openAppSettings, scanForNode } from "../native";

export function ElectionScreen({ id }: { id: string }) {
  const [d, setD] = useState<ElectionDetail | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [voting, setVoting] = useState(false);
  const [skew, setSkew] = useState(0);

  useEffect(() => {
    let alive = true;
    const load = () => api<ElectionDetail>(`/student/elections/${id}`).then((x) => { if (alive) { setD(x); setSkew(new Date(x.serverTime).getTime() - Date.now()); setErr(null); } }).catch((e) => alive && setErr((e as ApiError).message));
    load(); const t = setInterval(load, 10_000);
    return () => { alive = false; clearInterval(t); };
  }, [id]);

  if (err && !d) return <div className="err">{err}</div>;
  if (!d) return <p className="muted">Loading…</p>;
  if (d.status === "PUBLISHED") return <ResultsView id={id} />;
  if (voting && d.status === "ACTIVE") return <VoteFlow d={d} onExit={() => setVoting(false)} />;

  return (
    <>
      <section className="card">
        <div className="row"><h2>{d.title}</h2><span className={`pill ${d.status}`}>{d.status.toLowerCase()}</span></div>
        {d.description && <p className="muted">{d.description}</p>}
        <div className="notice"><b>{d.ui.headline}</b>{"\n"}{d.ui.body}</div>
        {d.status === "SCHEDULED" && d.startAt && <><div className="muted">Voting opens in</div><Countdown to={new Date(d.startAt).getTime()} skew={skew} /></>}
        {d.hasVoted && <p className="notice">✓ You have voted in this election. Your choices are private and cannot be viewed.</p>}
        {d.canVote && <button className="btn" onClick={() => setVoting(true)}>Vote Now</button>}
      </section>
      <h3>Positions and candidates</h3>
      {d.positions.map((p) => (
        <section className="card" key={p.id}>
          <h3>{p.title}</h3>
          {p.candidates.map((c) => (
            <div className="cand" style={{ cursor: "default" }} key={c.id}>
              <Avatar name={c.name} src={c.photoUrl} />
              <div><div><b>{c.name}</b> <span className="num">#{c.number}</span></div>
                {(c.programme || c.department) && <div className="muted">{c.programme ?? c.department}</div>}
                {c.manifesto && <details className="m"><summary>Manifesto</summary><p style={{ whiteSpace: "pre-line" }}>{c.manifesto}</p></details>}
              </div>
            </div>
          ))}
        </section>
      ))}
    </>
  );
}

type Choice = { ids: string[]; abstain: boolean };
type Step = "verify" | "ballot" | "review" | "done";

function VoteFlow({ d, onExit }: { d: ElectionDetail; onExit: () => void }) {
  const [step, setStep] = useState<Step>("verify");
  const [auth, setAuth] = useState<{ token: string; expiresAt: number } | null>(null);
  const [choices, setChoices] = useState<Record<string, Choice>>({});
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [needSettings, setNeedSettings] = useState(false);
  const [receipt, setReceipt] = useState<string | null>(null);

  async function verify() {
    setErr(null); setBusy(true); setNeedSettings(false);
    try {
      // Try each nearby beacon (strongest first) until the server accepts one; ignore look-alikes from other devices.
      const claims = d.requirePresence ? await scanForNode() : [undefined];
      let r: { authorization: string; expiresAt: string } | null = null;
      let last: ApiError | null = null;
      for (const claim of claims) {
        try { r = await api<{ authorization: string; expiresAt: string }>(`/student/elections/${d.id}/presence`, { body: { claim } }); break; }
        catch (e) { last = e as ApiError; if (last.code !== "NODE_REJECTED") throw e; }
      }
      if (!r) throw last ?? new ApiError(0, "Could not verify your location.");
      setAuth({ token: r.authorization, expiresAt: new Date(r.expiresAt).getTime() });
      setStep("ballot");
    } catch (e) {
      if (e instanceof NativeError) { setErr(e.message); setNeedSettings(e.code === "PERMISSION_DENIED" || e.code === "BLUETOOTH_OFF"); }
      else setErr((e as ApiError).message);
    } finally { setBusy(false); }
  }
  // Presence is not required: obtain the single-use authorisation straight away.
  useEffect(() => { if (!d.requirePresence) void verify(); /* eslint-disable-next-line */ }, []);

  const [left, setLeft] = useState(0);
  useEffect(() => {
    if (!auth || step === "done") return;
    const t = setInterval(() => {
      const s = Math.floor((auth.expiresAt - Date.now()) / 1000); setLeft(s);
      if (s <= 0) { setAuth(null); setStep("verify"); setErr("Your voting authorisation expired. Verify again to continue; your selections are kept."); }
    }, 1000);
    return () => clearInterval(t);
  }, [auth, step]);

  const toggle = (p: Position, cid: string) => setChoices((c) => {
    const cur = c[p.id] ?? { ids: [], abstain: false };
    let ids = cur.ids.includes(cid) ? cur.ids.filter((x) => x !== cid) : [...cur.ids, cid];
    if (p.maxSelections === 1) ids = cur.ids.includes(cid) ? [] : [cid];
    if (ids.length > p.maxSelections) return c;
    return { ...c, [p.id]: { ids, abstain: false } };
  });
  const abstain = (p: Position) => setChoices((c) => ({ ...c, [p.id]: { ids: [], abstain: !c[p.id]?.abstain } }));
  const complete = d.positions.every((p) => { const c = choices[p.id]; return c && (c.abstain || c.ids.length > 0); });

  async function submit() {
    if (!auth) return;
    setBusy(true); setErr(null);
    try {
      const body = { authorization: auth.token, choices: d.positions.map((p) => ({ positionId: p.id, candidateIds: choices[p.id].abstain ? [] : choices[p.id].ids, abstain: choices[p.id].abstain })) };
      const r = await api<{ receiptId: string }>(`/student/elections/${d.id}/vote`, { body });
      setReceipt(r.receiptId); setAuth(null); setStep("done");
    } catch (e) {
      const ae = e as ApiError; setErr(ae.message);
      if (ae.code === "AUTH_EXPIRED" || ae.code === "AUTH_USED") { setAuth(null); setStep("verify"); }
      if (ae.code === "ALREADY_VOTED") setStep("done");
    } finally { setBusy(false); }
  }

  if (step === "done") return (
    <section className="card">
      <h2>{receipt ? "Vote recorded" : "Already voted"}</h2>
      <p>{receipt ? "Thank you. Your ballot was accepted." : "Our records show you have already voted in this election."}</p>
      {receipt && <p className="muted">Receipt: <code>{receipt.slice(0, 8)}</code><br />This receipt proves you voted, not how you voted.</p>}
      <button className="btn" onClick={onExit}>Done</button>
    </section>
  );

  if (step === "verify") return (
    <section className="card">
      <h2>{d.requirePresence ? "Verify you are at the polling location" : "Preparing your ballot"}</h2>
      {d.requirePresence && <>
        <p className="muted">Stand near the polling device and keep Bluetooth on. You only need to be nearby for this step; once verified you can vote from where you are.</p>
        {!hasNative() && <div className="err">Presence verification needs the Election Android app. Open this election in the app to vote.</div>}
      </>}
      {err && <div className="err" role="alert">{err}</div>}
      {needSettings && <button className="btn secondary" style={{ marginBottom: 8 }} onClick={openAppSettings}>Open app settings</button>}
      <button className="btn" disabled={busy || (d.requirePresence && !hasNative())} onClick={verify}>{busy ? "Scanning…" : d.requirePresence ? "Verify my location" : "Continue"}</button>
      <button className="btn secondary" style={{ marginTop: 8 }} onClick={onExit}>Cancel</button>
    </section>
  );

  if (step === "review") return (
    <>
      <section className="card"><h2>Review your ballot</h2><p className="muted">Once submitted, your vote cannot be changed. Authorisation expires in {Math.max(left, 0)}s.</p></section>
      {d.positions.map((p) => { const c = choices[p.id]; return (
        <div className="card" key={p.id}><div className="muted">{p.title}</div>
          <b>{c.abstain ? "Abstain" : p.candidates.filter((x) => c.ids.includes(x.id)).map((x) => x.name).join(", ")}</b></div>
      ); })}
      {err && <div className="err" role="alert">{err}</div>}
      <button className="btn" disabled={busy} onClick={submit}>{busy ? "Submitting…" : "Submit my vote"}</button>
      <button className="btn secondary" style={{ marginTop: 8 }} disabled={busy} onClick={() => setStep("ballot")}>Back</button>
    </>
  );

  return (
    <>
      <div className="notice">Verified. Complete your ballot within {Math.max(left, 0)}s.</div>
      {err && <div className="err">{err}</div>}
      {d.positions.map((p) => { const c = choices[p.id] ?? { ids: [], abstain: false }; return (
        <section className="card" key={p.id}>
          <h3>{p.title}</h3>
          <p className="muted">{p.maxSelections === 1 ? "Choose one candidate." : `Choose up to ${p.maxSelections} candidates.`}</p>
          {p.candidates.map((cand) => (
            <label key={cand.id} className={`cand ${c.ids.includes(cand.id) ? "sel" : ""}`}>
              <input type={p.maxSelections === 1 ? "radio" : "checkbox"} name={p.id} checked={c.ids.includes(cand.id)} onChange={() => toggle(p, cand.id)} />
              <Avatar name={cand.name} src={cand.photoUrl} />
              <div><b>{cand.name}</b> <span className="num">#{cand.number}</span>{cand.programme && <div className="muted">{cand.programme}</div>}</div>
            </label>
          ))}
          {p.allowAbstain && <label className={`cand ${c.abstain ? "sel" : ""}`}><input type="checkbox" checked={c.abstain} onChange={() => abstain(p)} /><div><b>Abstain</b><div className="muted">I choose not to vote for this position.</div></div></label>}
        </section>
      ); })}
      <button className="btn" disabled={!complete} onClick={() => setStep("review")}>Review ballot</button>
      {!complete && <p className="muted" style={{ textAlign: "center" }}>Make a choice (or abstain) for every position.</p>}
    </>
  );
}

function ResultsView({ id }: { id: string }) {
  const [r, setR] = useState<Results | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => { api<Results>(`/student/elections/${id}/results`).then(setR).catch((e) => setErr((e as ApiError).message)); }, [id]);
  if (err) return <div className="err">{err}</div>;
  if (!r) return <p className="muted">Loading results…</p>;
  return (
    <>
      <section className="card"><div className="row"><h2>{r.title}</h2><span className="pill PUBLISHED">Published</span></div>
        <p className="muted">Official results · published {r.publishedLabel}<br />Total ballots cast: {r.turnout}</p></section>
      {r.results.map((p) => (
        <section className="card" key={p.positionId}>
          <h3>{p.title}</h3>
          {p.tie && <div className="notice">Tie: a runoff is required between the tied candidates.</div>}
          {p.candidates.map((c) => (
            <div key={c.candidateId}>
              <div className="row"><span className={c.winner ? "win" : ""}>{c.winner ? "★ " : ""}{c.name} <span className="num">#{c.number}</span>{c.tied ? " (tied)" : ""}</span><b>{c.votes}</b></div>
              <div className="bar"><i style={{ width: `${p.totalVotes ? (c.votes / p.totalVotes) * 100 : 0}%` }} /></div>
            </div>
          ))}
          <div className="muted">Abstained: {p.abstained}</div>
        </section>
      ))}
    </>
  );
}
