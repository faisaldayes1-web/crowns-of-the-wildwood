"""Agent: Codex-faisal3/bugtest. Independent original candidate match/reward/ledger/reload and source custody audit; no replay."""
from pathlib import Path
import datetime as dt,hashlib,json,math,os,re,subprocess,sys
sys.path[:0]=['C:/Temp/bugtest','C:/Temp/bugtest/setup'];import runner
from source_bound_adoption import efficient_checkout
r=runner.ROOT;read=lambda p:json.loads(Path(p).read_text(encoding='utf-8-sig'));h=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();jp=r/'jobs/crowns7fd135-normal-native-continuation.json';j=read(jp);repo=Path(j['repo']);out=Path(j['output']);checks=[]
def C(name,ok):checks.append(dict(name=name,passed=bool(ok)));assert ok,name
C('finite original candidate controller completed with all gates',j['status']=='EXITED' and not j.get('error') and j['functional_pass'] and j['native_fullmatch_functional_pass'] and j['restart_functional_pass'])
rows=runner.process_inventory();records=list((r/'cycles').rglob('*.process.json'))+list((r/'setup').rglob('*.process.json'));groups={g:efficient_checkout(runner.tester_repo(g),rows,records) for g in runner.ROSTER};groups['mobile112']=efficient_checkout(r/'mobile112-pause-history-fix',rows,records);groups['Prince-owner-package']=efficient_checkout(Path(read(r/'jobs/prince6ce9-owner-package-download.json')['package_root'])/'Game',rows,records)
C('all ten registered checkout/process families actually idle',not any(groups.values()))
C('exact committed runtime head',subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,creationflags=subprocess.CREATE_NO_WINDOW).decode().strip()==j['source_sha'])
C('all candidate tracked source bytes unchanged',len(j['source_files'])==1518 and all(h(repo/p)==v for p,v in j['source_files'].items()))
prep=read(r/'jobs/crowns7fd135-runtime-candidate-prepare-continuation.json')
tree=subprocess.check_output(['git','ls-tree','-r','-z',j['source_sha']],cwd=repo,creationflags=subprocess.CREATE_NO_WINDOW)
blobs={v.split(b'\t',1)[1].decode():v.split(b'\t',1)[0].decode().split()[2] for v in tree.split(b'\0') if v}
C('all1518 actual runtime files independently match Git blobs',all(hashlib.sha1(b'blob '+str((repo/p).stat().st_size).encode()+b'\0'+(repo/p).read_bytes()).hexdigest()==blobs[p] for p in j['source_files']))
C('sparse docs omission is explicit and logical2032tree complete',len(blobs)==2032 and len(prep['documentation_omitted'])==514 and set(blobs)==set(j['source_files'])|set(prep['documentation_omitted']) and all(p.startswith('docs/') and not (repo/p).exists() for p in prep['documentation_omitted']))
initial=read(r/'jobs/crowns7fd135-normal-native.json');interruption=read(initial['interruption_classification'])
C('original abrupt partial remains incomplete not fabricated exit',initial['status']=='INTERRUPTED' and initial['actual_exit_code'] is None and interruption['actual_result_record'] is False and interruption['typed_events']==2905 and not any(v.startswith('BUGTEST_FULL_MATCH ') for v in (Path(initial['output'])/'FIRST-native-Normal-fullmatch.log').read_text().splitlines()))
C('fresh actual profile does not reuse interrupted partial profile',Path(j['actual_private_userdata']['actual'])!=Path(initial['actual_private_userdata']['actual']))

C('original prior source profiles failures artifacts unchanged',all(h(p)==v for p,v in j['protected_files'].items()))
C('executed fixtures/controller and exact parent frozen',all(h(p)==v for p,v in j['frozen_files'].items()) and h(j['parent_job'])==j['parent_job_sha256'] and h(j['plan'])==j['plan_sha256'])
ordinary=Path(os.environ['APPDATA'])/'Godot/app_userdata';C('ordinary Godot user data unchanged',{str(p.relative_to(ordinary)):h(p) for p in ordinary.rglob('*') if p.is_file()}==j['ordinary_before'])
C('no original profile seeded/copied or altered source in runtime',not j['profile_copy'] and not j['export_created'])
logs=[Path(v['log']).read_text(encoding='utf-8',errors='replace') for v in j['results']]
C('original six source-bound proof parse native and restart steps',len(logs)==6 and all(Path(v['log']).with_suffix('.process.json').exists() for v in j['results']))
for i,v in enumerate(j['results']):
 q=read(Path(v['log']).with_suffix('.process.json'));C('step source cwd and closed process record '+v['step'],Path(q['source_repo'])==repo and Path(q['cwd'])==repo and q['exit']==v['exit'])
 if i in (3,5):C('actual native OS identity observed '+v['step'],bool(q['observed_processes']))
 C('no debug-end demo fixed-fps or seed flags '+v['step'],not any(str(a).startswith(('--debug-end','--demo','--fixed-fps','--seed')) for a in q['command']))
n=j['results'][3];restart=j['results'][5];m=n['matches'][0];summary=n['results'][0];events=n['events'];states=n['states'];actual=Path(j['actual_private_userdata']['actual'])
C('fresh actual user path established before native input',actual.resolve().is_relative_to(Path(j['profile_env']['APPDATA']).resolve()) and len(n['storage'])==1 and Path(n['storage'][0]['actual'])==actual)
C('native meaningful checks all pass',len(n['checks'])>30 and all(v['pass'] for v in n['checks']) and summary['failures']==0 and summary['full_match_qualified'])
required={'actual shared XP tally equals exactly banked gain','all actual players source ledger reconciles with shared match XP','two actual player XP ledgers observed at natural result','actual result eligibility follows current played-seconds threshold','actual bank gain includes only eligible result XP and primary accolades','actual summary includes result row exactly when eligible','actual summary keeps primary local player identity'}
C('actual named current aggregation and eligibility assertions all pass',required.issubset({v['label'] for v in n['checks'] if v['pass']}))

C('normal source time and actual two-device input',m['engine_scale']==1 and summary['difficulty']=='Normal' and len(events)>1000 and {v['device'] for v in events if v['kind'].startswith('InputEventJoypad')}=={0,7})
C('native typed events only and sequential',all(v['sequence']==i+1 for i,v in enumerate(events)) and all(v['kind'] in ['InputEventMouseMotion','InputEventMouseButton','InputEventKey','InputEventJoypadMotion','InputEventJoypadButton'] for v in events))
C('native joystick axes finite in actual stick range',all(math.isfinite(v['value']) and -1.00001<=v['value']<=1.00001 for v in events if v['kind']=='InputEventJoypadMotion'))
C('normal observed source clock advances without speedup',all(v['difficulty']=='Normal' and v['engine_scale']==1 for v in states) and all(b['clock']>=a['clock'] and b['clock']-a['clock']<=(b['wall_ms']-a['wall_ms'])/1000+2 for a,b in zip(states,states[1:])))
C('natural complete match end by source rules',max(m['score'])>=2 or m['clock']>=600)
stats=(repo/'scripts/stats.gd').read_text();tables={key:json.loads(re.search(r'^const '+key+r' := (\{[^\r\n]+\})',stats,re.M)[1]) for key in ['MATCH_BONUS','MATCH_GOLD','MATCH_SHARDS']}
C('exactly two actual earned player ledgers recorded',len(m['all_player_xp_sources'])==2 and len({v['unit'] for v in m['all_player_xp_sources']})==2)
sources={}
for u in m['all_player_xp_sources']:
 for k,v in u['sources'].items():sources[k]=sources.get(k,0)+v
C('independent ledger aggregation equals original observed shared sources',sources==m['shared_sources'] and sum(sources.values())==m['match_xp'])
C('training outside current issue not exercised',sources.get('training',0)==0)
mapping={'combat':'Combat','takedowns':'Takedowns','crown':'Crown','siege':'Siege','support':'Support'}
for key,label in mapping.items():C('actual category '+key+' reconciles with both natural player ledgers',sum(v[2] for v in m['summary_lines'] if v[0]==label)==sources.get(key,0))
threshold=float(re.search(r'^const RESULT_BONUS_MIN_TIME := ([0-9.]+)',stats,re.M)[1])
C('actual eligibility derives from current60second source rule',m['bonus_min_seconds']==threshold==60 and m['result_bonus_earned']==(m['match_played']>=threshold))
bonus=tables['MATCH_BONUS'][m['outcome']] if m['result_bonus_earned'] else 0
label={'win':'Victory','draw':'Draw','loss':'Played to the end'}[m['outcome']]
bonusrows=[v for v in m['summary_lines'] if v[0]==label]
C('actual result row is included exactly when eligible',m['expected_result_bonus']==bonus and m['result_rows']==bonusrows and ((len(bonusrows)==1 and bonusrows[0][2]==bonus) if m['result_bonus_earned'] else not bonusrows))
C('observed played seconds advance in real time',all(v['result_bonus_earned']==(v['match_played']>=threshold) for v in states) and all(0<=b['match_played']-a['match_played']<=(b['wall_ms']-a['wall_ms'])/1000+2 for a,b in zip(states,states[1:])))
acc=sum(v['xp'] for v in m['accolades']);gain=m['match_xp']+acc+bonus
C('actual final tally bank and account delta all equal',sum(v[2] for v in m['summary_lines'])==m['tally_total']==m['last_match_gain']==gain==m['wallet_after']['xp']-m['wallet_before']['xp'])
C('primary stats and accolades remain primary',m['summary_me']==m['local0'] and len(m['summary_lines'])<=7)
C('source defined gold shards and one chest unchanged',m['reward_gold']==tables['MATCH_GOLD'][m['outcome']] and m['reward_shards']==tables['MATCH_SHARDS'][m['outcome']] and m['wallet_after']==dict(xp=m['wallet_before']['xp']+gain,gold=m['wallet_before']['gold']+m['reward_gold'],shards=m['wallet_before']['shards']+m['reward_shards'],chests=m['wallet_before']['chests']+1))
C('normal result inputs do not bank twice and title EXIT used',len(n['normal_quits'])==1 and n['normal_quits'][0]['screen']=='title' and j['wallet_after_match']==m['wallet_after'])
C('separate native restart all checks and exact earned wallet',len(restart['checks'])==5 and all(v['pass'] for v in restart['checks']) and restart['results'][0]['failures']==0 and restart['wallets'][0]['wallet']==m['wallet_after'] and Path(restart['wallets'][0]['actual_user_path'])==actual)
C('controller expected wallet copy metadata cannot mutate raw oracle',read(out/'actually-earned-wallet.json')==dict(m['wallet_after'],agent='Codex-faisal3/bugtest') and 'agent' not in j['wallet_after_match'])
def wallet(p):
 section=re.search(r'^\[profile\]\s*\n(.*?)(?=^\[|\Z)',Path(p).read_text(),re.M|re.S)[1];return {k:int(re.search(r'^account_'+k+r'\s*=\s*([0-9]+)\s*$',section,re.M)[1]) for k in ['xp','gold','shards','chests']}
profile=actual/'profiles/p1.cfg';C('actual final and postmatch archived profile both earned numeric fields',wallet(profile)==wallet(out/'actual-earned-profile-after-match/profiles/p1.cfg')==m['wallet_after'])
C('private folder exact final job hashes',{str(p.relative_to(actual)):h(p) for p in actual.rglob('*') if p.is_file()}==j['private_profile_files'])
fixture=Path(j['fixture']).read_text();patterns=[r'app\.(?:_start_match|_finish|_end_on_time|_bank_match_xp|_write_save|_save_settings|continue_after_summary)\s*\(',r'\b(?:app|p|player|unit|foe|friend)\.global_position\s*=(?!=)',r'Engine\.time_scale\s*=(?!=)',r'app\.(?:account_xp|account_gold|account_chests|account_shards|time_left|bot_difficulty|game_over|playing)\s*=(?!=)']
C('no gameplay pose clock outcome reward or save API writes',not any(re.search(p,fixture) for p in patterns) and fixture.count('Input.parse_input_event(')==1)
C('all actual engine errors and exits retained raw classification',j['raw_status']==('FAIL' if any(v['errors'] or v['exit'] for v in j['results']) else 'PASS'))
C('no rendered images or physical acceptance invented',j['rendered'] is False and j['PNG']==0 and not list(out.rglob('*.png')))
target=r/'setup/crowns2fea-native-continuation-independent-audit.json';assert not target.exists();runner.atomic_json(target,dict(agent='Codex-faisal3/bugtest',at=dt.datetime.now(dt.timezone.utc).isoformat(),job=str(jp),job_sha256=h(jp),source_sha=j['source_sha'],checks=checks,audit_checks=len(checks),functional_pass=True,native_assertions=len(n['checks']),restart_assertions=len(restart['checks']),typed_events=len(events),states=len(states),actual_result=m,actual_genuine_profile=str(profile),actual_genuine_profile_sha256=h(profile),tracked_source_files=len(j['source_files']),protected_files=len(j['protected_files']),all10_idle=groups,source_prior_ordinary_unchanged=True,raw_status=j['raw_status'],raw_errors=[dict(step=v['step'],errors=v['errors']) for v in j['results']],warnings=[dict(step=v['step'],warnings=[s for s in logs[i].splitlines() if s.startswith('WARNING:')]) for i,v in enumerate(j['results'])],no_qualified_green_replay=True,initial_partial_interruption_preserved=True,rendered=False,PNG=0,physical=False,audio=False,performance=False,training_not_exercised=True,unsupported=n['unsupported'],evidence_hashes={str(p):h(p) for p in [jp,Path(j['fixture']),Path(j['restart_fixture']),out/'executed-controller.py',profile]+[Path(v['log']) for v in j['results']]+[Path(v['log']).with_suffix('.process.json') for v in j['results']]}))
print(json.dumps(dict(audit=str(target),checks=len(checks),tally=m['tally_total'],gain=gain,events=len(events),raw_status=j['raw_status'])))
