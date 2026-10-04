# Builds a one-page progress report (progress.html) from status.json and
# the latest commits. Publish it with the Artifact tool, same file each time.
#   python3 agent_toolchains/progress_report/build.py
# status.json: groups (name, [cards]) in build order, done (cards), current
# ("T7.2 · what"), note (one line).
import json,os,subprocess,html,datetime
HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.dirname(os.path.dirname(HERE))
OUT=os.path.join(ROOT,'build','progress_report')
os.makedirs(OUT,exist_ok=True)
s=json.load(open(os.path.join(HERE,'status.json')))
allc=[c for _,cs in s['groups'] for c in cs]; done=set(s['done'])
pct=round(100*len(done)/len(allc))
log=subprocess.run(['git','-C',ROOT,'log','--format=%h|%s','-12'],capture_output=True,text=True).stdout.strip().splitlines()
now=datetime.datetime.utcnow().strftime('%d %b %Y, %H:%M UTC')
rows=''
for name,cs in s['groups']:
    d=sum(c in done for c in cs); st='done' if d==len(cs) else ('now' if d or s['current'].split(' ')[0] in cs else 'todo')
    chips=''.join(f'<span class="c {"y" if c in done else ("n" if s["current"].startswith(c+" ") else "")}">{c}</span>' for c in cs)
    rows+=f'<li class="{st}"><div class="h"><b>{html.escape(name)}</b><span class="m">{d}/{len(cs)}</span></div><div class="chips">{chips}</div></li>'
commits=''.join(f'<li><code>{h}</code> {html.escape(m[:90])}</li>' for h,m in (l.split('|',1) for l in log))
out=f'''<title>Pointer Rebuild Progress</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@500;700;800&family=IBM+Plex+Mono:wght@500&display=swap">
<style>
:root{{--bg:#F2F2EF;--card:#FFFFFF;--ink:#17170F;--mute:#5E5E54;--line:#E3E3DB;--mint:#B4DED0;--deep:#1F5C4D;--todo:#EBEBE4}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#0D0D0C;--card:#1C1C1A;--ink:#F4F4EF;--mute:#BDBDB2;--line:#2A2A26;--mint:#7FBFAA;--deep:#B4DED0;--todo:#262622;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#0D0D0C;--card:#1C1C1A;--ink:#F4F4EF;--mute:#BDBDB2;--line:#2A2A26;--mint:#7FBFAA;--deep:#B4DED0;--todo:#262622;color-scheme:dark}}
body{{background:var(--bg);color:var(--ink);font:500 14px/1.5 Manrope,system-ui,sans-serif}}
main{{max-width:760px;margin:0 auto;padding:32px 16px 48px;display:grid;gap:22px}}
.eb{{font:700 11px Manrope;letter-spacing:.12em;text-transform:uppercase;color:var(--mute)}}
h1{{font-size:clamp(34px,8vw,52px);font-weight:800;letter-spacing:-.04em;line-height:1;margin:4px 0 0}}
.hero{{background:var(--mint);color:#17170F;border-radius:26px;padding:22px;display:grid;gap:12px}}
.big{{font-size:64px;font-weight:800;letter-spacing:-.05em;line-height:1;font-variant-numeric:tabular-nums}}
.bar{{height:12px;border-radius:6px;background:rgba(23,23,15,.15);overflow:hidden}}.bar i{{display:block;height:100%;background:#17170F;width:{pct}%}}
.sub{{font-weight:700}}
ul{{list-style:none;margin:0;padding:0;display:grid;gap:8px}}
.groups li{{background:var(--card);border-radius:18px;padding:13px 15px;display:grid;gap:9px}}
.h{{display:flex;justify-content:space-between;gap:12px}}.m{{font:500 12px 'IBM Plex Mono',monospace;color:var(--mute)}}
.chips{{display:flex;flex-wrap:wrap;gap:5px}}
.c{{font:500 11px 'IBM Plex Mono',monospace;padding:3px 8px;border-radius:99px;background:var(--todo);color:var(--mute)}}
.c.y{{background:var(--mint);color:#17170F}}.c.n{{background:var(--ink);color:var(--bg)}}
li.done b::after{{content:" ✓";color:var(--deep)}}
.log li{{font-size:12.5px;color:var(--mute)}}.log code{{font:500 12px 'IBM Plex Mono',monospace;color:var(--ink)}}
</style>
<main>
<div><div class="eb">branch pointer-dev · updated {now}</div><h1>Pointer rebuild</h1></div>
<section class="hero"><div class="eb" style="color:#24564A">Complete</div><div class="big">{pct}%</div><div class="bar"><i></i></div>
<div class="sub">{len(done)} of {len(allc)} cards done · now on {html.escape(s["current"])}</div><div>{html.escape(s["note"])}</div></section>
<section><div class="eb">By group, in build order</div><ul class="groups" style="margin-top:8px">{rows}</ul></section>
<section><div class="eb">Latest commits (pushed)</div><ul class="log" style="margin-top:8px">{commits}</ul></section>
</main>'''
p=os.path.join(OUT,'progress.html'); open(p,'w').write(out); print(pct, p)
