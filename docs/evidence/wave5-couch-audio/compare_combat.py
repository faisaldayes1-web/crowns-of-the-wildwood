import pathlib, subprocess, os, json
p=pathlib.Path('C:/ORY-Cache/qa/wave5-Codex-faisal'); results=[]
for label in ['before','after']:
 env=os.environ.copy(); env['APPDATA']=str(p/('combat-pack-'+label)); env['CROWNS_TEST_USER_BASE']=env['APPDATA']
 r=subprocess.run(['C:/ORY-Cache/qa/crowns-68-codex-faisal/templates/windows_debug_x86_64.exe','--headless','--main-pack',str(p/('crowns-audio-'+label+'.pck')),'--fixed-fps','60','--quit-after','3000','--','--demo','--selftest'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180)
 (p/('combat-pack-'+label+'.log')).write_text(r.stdout,encoding='utf-8')
 result={'label':label,'exit':r.returncode,'passes':r.stdout.count('TEST PASS '),'completed':'TESTS DONE failures=0' in r.stdout,'diagnostics':[line for line in r.stdout.splitlines() if 'ERROR:' in line or 'WARNING:' in line]};results.append(result);print(json.dumps(result),flush=True)
(p/'combat-pack-results.json').write_text(json.dumps(results,indent=2))
