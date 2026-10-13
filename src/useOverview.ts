import { useEffect, useRef, useState } from "react";
import { api, ApiError, Overview } from "./api";

/** One shared live feed of the student's elections (polls every 10 s and when the tab becomes visible). */
export function useOverview() {
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
    const t = setInterval(load, 10_000);
    const vis = () => document.visibilityState === "visible" && load();
    document.addEventListener("visibilitychange", vis);
    return () => { alive = false; clearInterval(t); document.removeEventListener("visibilitychange", vis); };
  }, []);
  return { data, err, skew: skew.current };
}

const RANK: Record<string, number> = { ACTIVE: 0, PAUSED: 1, SCHEDULED: 2, ENDED: 3, COUNTING: 3, VERIFIED: 3, FINALIZED: 3, PUBLISHED: 4, DEACTIVATED: 5 };
export const byImportance = <T extends { status: string }>(list: T[]) => [...list].sort((a, b) => (RANK[a.status] ?? 9) - (RANK[b.status] ?? 9));
