import { FormEvent, useState } from "react";
import { api, ApiError, setToken } from "../api";

type Mode = "login" | "register" | "recover";

export function Auth({ onDone }: { onDone: () => void }) {
  const [mode, setMode] = useState<Mode>("login");
  const [f, setF] = useState({ indexNumber: "", password: "", code: "", confirm: "" });
  const [err, setErr] = useState<string | null>(null);
  const [recovered, setRecovered] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (mode !== "login") {
      if (f.password.length < 10) return setErr("Use a password of at least 10 characters.");
      if (f.password !== f.confirm) return setErr("The passwords do not match.");
    }
    setBusy(true);
    try {
      if (mode === "login") {
        const r = await api<{ token: string }>("/auth/student/login", { body: { indexNumber: f.indexNumber, password: f.password } });
        setToken(r.token); onDone();
      } else if (mode === "register") {
        const r = await api<{ token: string }>("/auth/student/register", { body: { indexNumber: f.indexNumber, code: f.code, password: f.password } });
        setToken(r.token); onDone();
      } else {
        await api("/auth/student/recover", { body: { indexNumber: f.indexNumber, code: f.code, newPassword: f.password } });
        setRecovered(true); setMode("login"); setF({ ...f, password: "", confirm: "", code: "" });
      }
    } catch (e) {
      const ae = e as ApiError;
      setErr(ae.message);
      if (ae.code === "ACCOUNT_EXISTS") setMode("login");
    } finally { setBusy(false); }
  }

  const title = { login: "Sign in", register: "Create account", recover: "Recover account" }[mode];
  return (
    <>
      <header className="top"><h1>Student Election</h1></header>
      <main>
        <form className="card" onSubmit={submit}>
          <h2>{title}</h2>
          {mode === "register" && <p className="muted">Enter your official index number and the one-time registration code issued by the Electoral Commission. An index number alone is not enough to create an account.</p>}
          {mode === "recover" && <p className="muted">Ask the Electoral Commission for a recovery code, then choose a new password.</p>}
          {recovered && mode === "login" && <div className="notice">Password updated. Sign in with your new password.</div>}
          {err && <div className="err" role="alert">{err}</div>}
          <label className="field"><span>Index number</span><input value={f.indexNumber} onChange={set("indexNumber")} autoCapitalize="characters" autoComplete="username" required /></label>
          {mode !== "login" && <label className="field"><span>{mode === "register" ? "Registration code" : "Recovery code"}</span><input value={f.code} onChange={set("code")} placeholder="XXXX-XXXX-XXXX" autoCapitalize="characters" required /></label>}
          <label className="field"><span>{mode === "recover" ? "New password" : "Password"}</span><input type="password" value={f.password} onChange={set("password")} autoComplete={mode === "login" ? "current-password" : "new-password"} required /></label>
          {mode !== "login" && <label className="field"><span>Confirm password</span><input type="password" value={f.confirm} onChange={set("confirm")} autoComplete="new-password" required /></label>}
          <button className="btn" disabled={busy}>{busy ? "Please wait…" : title}</button>
        </form>
        <p className="muted" style={{ textAlign: "center" }}>
          {mode === "login" ? <>New here? <button className="link" onClick={() => { setErr(null); setMode("register"); }}>Create account</button> · <button className="link" onClick={() => { setErr(null); setMode("recover"); }}>Forgot password?</button></>
            : <button className="link" onClick={() => { setErr(null); setMode("login"); }}>Back to sign in</button>}
        </p>
      </main>
    </>
  );
}
