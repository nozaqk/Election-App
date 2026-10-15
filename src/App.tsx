import { useCallback, useEffect, useState } from "react";
import { api, BASE, getToken, Me, setToken } from "./api";
import { Auth } from "./screens/Auth";
import { Home } from "./screens/Home";
import { News } from "./screens/News";
import { Elections } from "./screens/Elections";
import { Settings } from "./screens/Settings";
import { ElectionScreen } from "./screens/Election";
import { useOverview } from "./useOverview";
import { askBluetoothOn, BtState, hasNative, startNotifications, stopNotifications, watchBluetooth } from "./native";

type Tab = "home" | "news" | "elections" | "settings";
const ICONS: Record<Tab, string> = {
  home: "M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
  news: "M4 4h13a2 2 0 0 1 2 2v13a1 1 0 0 0 1 1H6a2 2 0 0 1-2-2zM8 8h7M8 12h7M8 16h4",
  elections: "M5 3h14v18H5zM9 8l2 2 4-4M8 15h8M8 18h5",
  settings: "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM19 12l2-1-2-4-2 .5-1.5-1L15 4h-4l-.5 2.5-1.5 1L6.5 7 4.5 11l2 1v2l-2 1 2 4 2-.5 1.5 1L11 20h4l.5-2.5 1.5-1 2 .5 2-4-2-1z",
};
const LABEL: Record<Tab, string> = { home: "Home", news: "News", elections: "Election", settings: "Settings" };

/** Bluetooth status, app only. Red = phone Bluetooth off (tap to be asked to turn it on), yellow = Bluetooth on, green = polling-node signal in range. */
const BT_TEXT = { off: "Bluetooth is off. Tap to turn it on.", on: "Bluetooth is on. No polling device in range.", node: "Connected: polling device in range." } as const;
function BtBadge() {
  const [st, setSt] = useState<BtState | null>(null);
  useEffect(() => watchBluetooth(setSt), []);
  if (st === null) return null;
  return (
    <button type="button" className={`bt ${st}`} onClick={() => { if (st === "off") askBluetoothOn(); }} aria-label={BT_TEXT[st]} title={BT_TEXT[st]}>
      <svg viewBox="0 0 30 24" width="30" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
        <path d="M5 7l10 10-5 5V2l5 5L5 17" />
        {st !== "off" && <path d="M20 8.5a5 5 0 0 1 0 7" />}
        {st === "node" && <path d="M23.5 5.5a9 9 0 0 1 0 13" />}
        {st === "off" && <path d="M19 8l7 8M26 8l-7 8" />}
      </svg>
    </button>
  );
}

export default function App() {
  const [signedIn, setSignedIn] = useState(!!getToken());
  const [me, setMe] = useState<Me | null>(null);
  const [tab, setTab] = useState<Tab>("home");
  const [electionId, setElectionId] = useState<string | null>(null);

  const signOut = useCallback(() => { stopNotifications(); setToken(null); setSignedIn(false); setMe(null); setElectionId(null); setTab("home"); }, []);
  useEffect(() => { const f = () => { stopNotifications(); setSignedIn(false); }; window.addEventListener("election:signed-out", f); return () => window.removeEventListener("election:signed-out", f); }, []);
  useEffect(() => { if (signedIn) api<Me>("/auth/student/me").then(setMe).catch(() => undefined); }, [signedIn]);
  useEffect(() => {
    if (!signedIn || !hasNative()) return;
    api<{ token: string }>("/student/notify-token", { method: "POST" }).then((r) => startNotifications(r.token, BASE || location.origin)).catch(() => undefined);
  }, [signedIn]);
  useEffect(() => { window.scrollTo(0, 0); }, [tab, electionId]);

  if (!signedIn) return <Auth onDone={() => setSignedIn(true)} />;
  return <Shell me={me} setMe={setMe} tab={tab} setTab={setTab} electionId={electionId} setElectionId={setElectionId} onSignOut={signOut} />;
}

function Shell({ me, setMe, tab, setTab, electionId, setElectionId, onSignOut }: { me: Me | null; setMe: (m: Me) => void; tab: Tab; setTab: (t: Tab) => void; electionId: string | null; setElectionId: (id: string | null) => void; onSignOut: () => void }) {
  const { data, err, skew } = useOverview();
  const inElection = electionId !== null;
  return (
    <>
      <header className="top">
        <h1>{inElection ? <button onClick={() => setElectionId(null)} aria-label="Back">← Back</button> : "Student Election"}</h1>
        {hasNative() && <BtBadge />}
      </header>
      <main className={inElection ? "" : "has-tabs"}>
        {inElection ? <ElectionScreen id={electionId!} /> : <>
          {tab === "home" && <Home me={me} data={data} err={err} skew={skew} onOpen={setElectionId} onAll={() => setTab("elections")} />}
          {tab === "news" && <News data={data} err={err} onOpen={setElectionId} />}
          {tab === "elections" && <Elections data={data} err={err} skew={skew} onOpen={setElectionId} />}
          {tab === "settings" && <Settings me={me} onSaved={setMe} onSignOut={onSignOut} />}
        </>}
      </main>
      {/* Hidden while an election is open so nobody leaves a half-finished ballot by accident; "Back" returns here. */}
      {!inElection && (
        <nav className="tabs" aria-label="Main">
          {(Object.keys(LABEL) as Tab[]).map((t) => (
            <button key={t} className={tab === t ? "on" : ""} aria-current={tab === t ? "page" : undefined} onClick={() => setTab(t)}>
              <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden><path d={ICONS[t]} /></svg>
              <span>{LABEL[t]}</span>
            </button>
          ))}
        </nav>
      )}
    </>
  );
}
