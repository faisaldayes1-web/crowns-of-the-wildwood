import pathlib,subprocess,os,json
p=pathlib.Path("C:/ORY-Cache/qa/wave5-Codex-faisal");results=[]
for label in ("before","after"):
 save=p/("control-audio-save-"+label);save.mkdir(exist_ok=True)
 env=os.environ.copy();env["APPDATA"]=str(save);env["CROWNS_TEST_USER_BASE"]=save.as_posix();env["CROWNS_CAPTURE_STILL"]=(p/("audio-signal-"+label+".png")).as_posix()
 env["CROWNS_EXPECT_FIXED"]="1" if label=="after" else "0"
 args=["C:/ORY-Cache/qa/crowns-68-codex-faisal/templates/windows_debug_x86_64.exe","--main-pack",str(p/("crowns-audio-"+label+".pck")),"--rendering-method","gl_compatibility","--resolution","1280x720","--script",str(p/"pack_audio_signal_control.gd"),"--","--debug-unlock"]
 r=subprocess.run(args,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=300)
 (p/("control-audio-"+label+".log")).write_text(r.stdout,encoding="utf-8")
 result={"label":label,"exit":r.returncode,"evidence":[l for l in r.stdout.splitlines() if "PACK_AUDIO" in l or "CAPTURE " in l or "MIX_SIGNAL" in l or "UI_CONTROL" in l or "SIGNAL_GATES" in l or "FAIL" in l or "SCRIPT ERROR" in l],"tail":r.stdout.splitlines()[-6:]};results.append(result);print(json.dumps(result),flush=True)
(p/"control-audio-results.json").write_text(json.dumps(results,indent=2))
