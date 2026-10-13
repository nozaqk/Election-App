import { FormEvent, useState } from "react";
import { api, ApiError, setToken } from "../api";

type Mode = "login" | "register" | "recover";

export function Auth({ onDone }: { onDone: () => void }) {
  const [mode, setMode] = useState<Mode>("login");
  const [f, setF] = useState({ fullName: "", indexNumber: "", password: "", code: "", confirm: "" });
  const [step, setStep] = useState<"details" | "verify">("details");   // register: 1 = name + index, 2 = emailed code + password
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [recovered, setRecovered] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (mode === "register" && step === "details") {
      setBusy(true);
      try {
        const r = await api<{ maskedEmail: string }>("/auth/student/register/start", { body: { fullName: f.fullName, indexNumber: f.indexNumber } });
        setSentTo(r.maskedEmail); setStep("verify");
      } catch (e) { const ae = e as ApiError; setErr(ae.message); if (ae.code === "ACCOUNT_EXISTS") setMode("login"); }
      finally { setBusy(false); }
      return;
    }
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
  const go = (m: Mode) => { setErr(null); setStep("details"); setSentTo(null); setMode(m); };
  const submitLabel = mode === "register" && step === "details" ? "Send verification code" : mode === "register" ? "Verify and create account" : title;
  return (
    <>
      <header className="top"><h1>Student Election</h1></header>
      <main className="auth">
        <form className="card auth-card" onSubmit={submit}>
          <h2>{title}</h2>
          {mode === "register" && step === "details" && <p className="muted">Enter your name and official index number. We will email a verification code to the institutional email address on your student record. An index number alone is not enough to create an account.</p>}
          {mode === "register" && step === "verify" && <div className="notice">{sentTo ? `We sent a 6-character code to ${sentTo}. It expires in 10 minutes.` : "Enter the registration code you were given."}</div>}
          {mode === "recover" && <p className="muted">Ask the Electoral Commission for a recovery code, then choose a new password.</p>}
          {recovered && mode === "login" && <div className="notice">Password updated. Sign in with your new password.</div>}
          {err && <div className="err" role="alert">{err}</div>}
          {mode === "register" && <label className="field"><span>Full name</span><input value={f.fullName} onChange={set("fullName")} autoComplete="name" disabled={step === "verify" && !!sentTo} required={step === "details"} /></label>}
          <label className="field"><span>Index number</span><input value={f.indexNumber} onChange={set("indexNumber")} autoCapitalize="characters" autoComplete="username" disabled={mode === "register" && step === "verify" && !!sentTo} required /></label>
          {(mode === "recover" || (mode === "register" && step === "verify")) && <label className="field"><span>{mode === "register" ? "Verification code" : "Recovery code"}</span><input value={f.code} onChange={set("code")} placeholder={mode === "register" ? "ABC123" : "XXXX-XXXX-XXXX"} autoCapitalize="characters" autoComplete="one-time-code" required /></label>}
          {(mode !== "register" || step === "verify") && <label className="field"><span>{mode === "recover" ? "New password" : "Password"}</span><input type="password" value={f.password} onChange={set("password")} autoComplete={mode === "login" ? "current-password" : "new-password"} required /></label>}
          {mode !== "login" && (mode !== "register" || step === "verify") && <label className="field"><span>Confirm password</span><input type="password" value={f.confirm} onChange={set("confirm")} autoComplete="new-password" required /></label>}
          <button className="btn" disabled={busy}>{busy ? "Please wait…" : submitLabel}</button>
          {mode === "register" && step === "details" && <p className="muted center"><button type="button" className="link" onClick={() => { setErr(null); setSentTo(null); setStep("verify"); }}>I already have a code</button></p>}
          {mode === "register" && step === "verify" && sentTo && <p className="muted center"><button type="button" className="link" onClick={() => { setErr(null); setStep("details"); }}>Resend code / change details</button></p>}
        </form>
        <p className="muted center">
          {mode === "login" ? <>New here? <button className="link" onClick={() => go("register")}>Create account</button> · <button className="link" onClick={() => go("recover")}>Forgot password?</button></>
            : <button className="link" onClick={() => go("login")}>Back to sign in</button>}
        </p>
      </main>
    </>
  );
}
