import { FormEvent, useState } from "react";
import { api, ApiError, setToken } from "../api";

type Mode = "login" | "register" | "recover";

export function Auth({ onDone }: { onDone: () => void }) {
  const [mode, setMode] = useState<Mode>("login");
  const [f, setF] = useState({ fullName: "", indexNumber: "", email: "", password: "", code: "", confirm: "" });
  const [step, setStep] = useState<"details" | "verify">("details");   // register/recover: 1 = details, 2 = emailed code + password
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [recovered, setRecovered] = useState(false);
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement>) => setF({ ...f, [k]: e.target.value });

  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (mode !== "login" && step === "details") {
      setBusy(true);
      try {
        if (mode === "register") {
          const r = await api<{ maskedEmail: string }>("/auth/student/register/start", { body: { fullName: f.fullName, indexNumber: f.indexNumber, email: f.email } });
          setSentTo(r.maskedEmail);
        } else {
          await api("/auth/student/recover/start", { body: { indexNumber: f.indexNumber, email: f.email } });
          setSentTo(f.email.trim());
        }
        setStep("verify");
      } catch (e) { const ae = e as ApiError; setErr(ae.message); if (ae.code === "ACCOUNT_EXISTS") go("login"); }
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
        setRecovered(true); go("login"); setF({ ...f, password: "", confirm: "", code: "" });
      }
    } catch (e) {
      const ae = e as ApiError;
      setErr(ae.message);
      if (ae.code === "ACCOUNT_EXISTS") go("login");
    } finally { setBusy(false); }
  }

  const title = { login: "Sign in", register: "Create account", recover: "Reset password" }[mode];
  const go = (m: Mode) => { setErr(null); setStep("details"); setSentTo(null); setMode(m); };
  const verifying = mode !== "login" && step === "verify";
  const submitLabel = mode === "login" ? "Sign in" : step === "details" ? "Send verification code" : mode === "register" ? "Verify and create account" : "Reset password";
  return (
    <>
      <header className="top"><h1>Student Election</h1></header>
      <main className="auth">
        <form className="card auth-card" onSubmit={submit}>
          <h2>{title}</h2>
          {mode === "register" && step === "details" && <p className="muted">Enter your name, official index number and your institutional email. We will email a verification code to confirm it is you.</p>}
          {mode === "recover" && step === "details" && <p className="muted">Enter your index number and the email on your student record. We will email you a code to reset your password.</p>}
          {verifying && <div className="notice">{mode === "register" ? `We sent a 6-character code to ${sentTo}. It expires in 10 minutes.` : `If the details match an account, a 6-character reset code was sent to ${sentTo}. It expires in 10 minutes.`}</div>}
          {recovered && mode === "login" && <div className="notice">Password updated. Sign in with your new password.</div>}
          {err && <div className="err" role="alert">{err}</div>}
          {mode === "register" && <label className="field"><span>Full name</span><input value={f.fullName} onChange={set("fullName")} autoComplete="name" disabled={verifying} required /></label>}
          <label className="field"><span>Index number</span><input value={f.indexNumber} onChange={set("indexNumber")} autoCapitalize="characters" autoComplete="username" disabled={verifying} required /></label>
          {mode !== "login" && <label className="field"><span>Email</span><input type="email" value={f.email} onChange={set("email")} autoComplete="email" inputMode="email" disabled={verifying} required /></label>}
          {verifying && <label className="field"><span>{mode === "register" ? "Verification code" : "Reset code"}</span><input value={f.code} onChange={set("code")} placeholder="ABC123" autoCapitalize="characters" autoComplete="one-time-code" required /></label>}
          {(mode === "login" || verifying) && <label className="field"><span>{mode === "recover" ? "New password" : "Password"}</span><input type="password" value={f.password} onChange={set("password")} autoComplete={mode === "login" ? "current-password" : "new-password"} required /></label>}
          {verifying && <label className="field"><span>Confirm password</span><input type="password" value={f.confirm} onChange={set("confirm")} autoComplete="new-password" required /></label>}
          <button className="btn" disabled={busy}>{busy ? "Please wait…" : submitLabel}</button>
          {verifying && <p className="muted center"><button type="button" className="link" onClick={() => { setErr(null); setStep("details"); }}>Resend code / change details</button></p>}
        </form>
        <div className="auth-links muted">
          {mode === "login" ? <>
            <div>New here? <button className="link" onClick={() => go("register")}>Create account</button></div>
            <div><button className="link" onClick={() => go("recover")}>Forgot password?</button></div>
          </> : <div><button className="link" onClick={() => go("login")}>Back to sign in</button></div>}
        </div>
      </main>
    </>
  );
}
