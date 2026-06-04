"""Heartbeat progress logger for the (potentially long) production model run.

A background daemon thread prints a timestamped status line every `interval`
seconds REGARDLESS of what the main thread is doing - so even while a single
large-model forward pass is in flight, or the model is downloading/loading, the
operator still sees a fresh line every 1-2s and knows it is alive. The main
thread just advances counters; the thread does the printing (and only printing,
never any torch call, so it is thread-safe).

Output goes to stdout AND an append-only logfile (out/build.log) so a run done
"outside here" leaves an auditable trail. Uses time.monotonic for rate/ETA.
"""

from __future__ import annotations

import threading
import time


class HeartbeatLogger:
    def __init__(self, logfile=None, interval: float = 1.5):
        self.interval = interval
        self.phase = "starting"
        self.done = 0
        self.total = 0
        self._phase_t0 = time.monotonic()
        self._run_t0 = time.monotonic()
        self._stop = threading.Event()
        self._lock = threading.Lock()
        self._lf = open(logfile, "a", encoding="utf-8") if logfile else None
        self._thread = threading.Thread(target=self._loop, daemon=True)

    # --- main-thread API ---------------------------------------------------
    def start(self):
        self._emit(f"=== run start (heartbeat every {self.interval}s) ===")
        self._thread.start()
        return self

    def set_phase(self, phase: str, total: int = 0):
        with self._lock:
            self.phase = phase
            self.done = 0
            self.total = total
            self._phase_t0 = time.monotonic()
        self._emit(f">>> {phase}" + (f" (0/{total})" if total else ""))

    def step(self, n: int = 1):
        with self._lock:
            self.done += n

    def log(self, msg: str):
        """Immediate, un-throttled event line (start/finish/summary)."""
        self._emit(msg)

    def stop(self):
        self._stop.set()
        if self._thread.is_alive():
            self._thread.join(timeout=2 * self.interval)
        total_el = time.monotonic() - self._run_t0
        self._emit(f"=== run end | total elapsed {total_el:.0f}s ===")
        if self._lf:
            self._lf.close()

    # --- internals ---------------------------------------------------------
    def _emit(self, msg: str):
        line = f"[{time.strftime('%H:%M:%S')}] {msg}"
        print(line, flush=True)
        if self._lf:
            self._lf.write(line + "\n")
            self._lf.flush()

    def _loop(self):
        while not self._stop.wait(self.interval):
            with self._lock:
                phase, done, total = self.phase, self.done, self.total
                el = time.monotonic() - self._phase_t0
            if total:
                rate = done / el if el > 0 else 0.0
                eta = (total - done) / rate if rate > 0 else float("inf")
                eta_s = "?" if eta == float("inf") else f"{eta:.0f}s"
                self._emit(
                    f"{phase} | {done}/{total} | {rate:.1f}/s | "
                    f"elapsed {el:.0f}s | ETA {eta_s}"
                )
            else:
                self._emit(f"{phase} | working... elapsed {el:.0f}s")
