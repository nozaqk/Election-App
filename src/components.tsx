import { useEffect, useState } from "react";

export function Countdown({ to, skew }: { to: number; skew: number }) {
  const [now, setNow] = useState(Date.now() + skew);
  useEffect(() => { const t = setInterval(() => setNow(Date.now() + skew), 1000); return () => clearInterval(t); }, [skew]);
  const s = Math.max(0, Math.floor((to - now) / 1000));
  const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  const p = (n: number) => String(n).padStart(2, "0");
  return <div className="countdown" role="timer" aria-live="off">{d > 0 && `${d}d `}{p(h)}:{p(m)}:{p(sec)}</div>;
}

export function Avatar({ name, src }: { name: string; src?: string | null }) {
  return src ? <img src={src} alt="" loading="lazy" /> : <div className="avatar" aria-hidden>{name.split(" ").map((w) => w[0]).slice(0, 2).join("")}</div>;
}
