extends RefCounted
## Match log lines (the --demo balance log: KILL, DOWN, ECON, the status
## block...) printed from a worker thread, so writing to the console never
## stalls a frame (claude-faisal/crowns-spawn 2026-11-04, tools/stall_probe.gd:
## a KILL line cost 3-17 ms and the 30 s status block 30-170 ms of the frame
## that printed it). Lines keep their order; flush() (before RESULT/STAT, and
## when the game goes) prints everything still queued and stops the worker.

static var _q := PackedStringArray()
static var _m := Mutex.new()
static var _s := Semaphore.new()
static var _t: Thread = null
static var _stop := false


static func line(text: String) -> void:
	_m.lock()
	_q.append(text)
	if _t == null:
		_stop = false
		_t = Thread.new()
		_t.start(_run)
	_m.unlock()
	_s.post()


static func _run() -> void:
	while true:
		_s.wait()
		_m.lock()
		var batch := _q
		_q = PackedStringArray()
		var stop := _stop
		_m.unlock()
		if not batch.is_empty():
			print("\n".join(batch))
		if stop:
			return


static func flush() -> void:
	## Print what is queued (in order, before whatever the caller prints next).
	_m.lock()
	var t := _t
	_t = null
	_stop = true
	_m.unlock()
	if t == null:
		return
	_s.post()
	t.wait_to_finish()
