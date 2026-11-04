import { Check, Moon, Shield, VolumeX, Sun } from 'lucide-react';

type PublicPlayer = { id: string; name: string };
type NightReport = {
  round: number;
  deadPlayers: PublicPlayer[];
  savedCount: number;
  silencedPlayers: PublicPlayer[];
  summary: string;
};

export default function NightRecap({ game, busy, onRead }: {
  game: any;
  busy: boolean;
  onRead: () => void;
}) {
  if (!['day', 'nominate', 'secondary', 'vote', 'verdict', 'end'].includes(game.phase)) return null;
  const report: NightReport | null = game.lastNight?.round === game.round ? game.lastNight : null;
  const legacySummary = game.log.filter((line: string) => line.startsWith(`Night ${game.round}:`)).at(-1);
  if (!report && !legacySummary) return null;
  const me = game.players.find((player: any) => player.id === game.me);
  const living = game.players.filter((player: any) => player.alive);
  const acknowledged = living.filter((player: any) => game.ready.includes(player.id)).length;
  const read = game.ready.includes(game.me);

  return (
    <section className="night-recap" aria-labelledby="night-recap-title">
      <div className="recap-heading">
        <span className="recap-sun"><Sun size={28} aria-hidden="true" /></span>
        <div>
          <div className="eyebrow">MORNING REPORT · FOR THE WHOLE TABLE</div>
          <h2 id="night-recap-title">Night {game.round} recap</h2>
        </div>
      </div>
      <p className="recap-summary">{report?.summary || legacySummary}</p>
      {report && (
        <div className="recap-outcomes">
          <div className={'recap-outcome '+(report.deadPlayers.length ? 'recap-loss' : '')}>
            <div className="recap-outcome-label"><Moon size={17} aria-hidden="true" />ELIMINATED</div>
            <strong>{report.deadPlayers.length}</strong>
            {report.deadPlayers.length ? (
              <ul>{report.deadPlayers.map(player => <li key={player.id}>{player.name}</li>)}</ul>
            ) : <p>Everyone survived the night.</p>}
          </div>
          <div className="recap-outcome">
            <div className="recap-outcome-label"><Shield size={17} aria-hidden="true" />SAVED</div>
            <strong>{report.savedCount}</strong>
            <p>{report.savedCount ? 'Night kills were prevented. Protected players’ names stay private.' : 'No night kills were prevented by protection.'}</p>
          </div>
          <div className="recap-outcome">
            <div className="recap-outcome-label"><VolumeX size={17} aria-hidden="true" />SILENCED TODAY</div>
            <strong>{report.silencedPlayers.length}</strong>
            {report.silencedPlayers.length ? (
              <><ul>{report.silencedPlayers.map(player => <li key={player.id}>{player.name}</li>)}</ul><p>Cannot speak today. May still nominate, vote, and use powers.</p></>
            ) : <p>Everyone alive can speak today.</p>}
          </div>
        </div>
      )}
      {game.phase === 'day' && (
        <div className="recap-acknowledgement">
          <div>
            <b>Read the report aloud before discussing suspects.</b>
            <p>{acknowledged} of {living.length} living players have acknowledged the recap.</p>
          </div>
          {me?.alive ? (
            <button className="primary" disabled={busy || read} onClick={onRead}>
              <Check size={18} />{read ? 'Recap read — waiting for the table' : 'I’ve read the recap'}
            </button>
          ) : <span className="recap-spectator">You can follow the report as a spectator.</span>}
        </div>
      )}
      {game.phase !== 'day' && <p className="recap-footnote">This morning’s public report stays here throughout the day.</p>}
    </section>
  );
}
