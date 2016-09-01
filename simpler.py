import csnd6


class Clip:
    def __init__(self, launcher, channel):
        self.launcher = launcher
        self.channel = channel

    def play(self):
        self.launcher.send_msg("Play", "%d" % self.channel)

    def stop(self):
        self.launcher.send_msg("Stop", "%d" % self.channel)

    def volume(self, value):
        self.launcher.send_msg("SetVolume", "%d %f" % (self.channel, value))

    def speed(self, value):
        self.launcher.send_msg("SetSpeed", "%d %f" % (self.channel, value))


class Snd:
    def __init__(self, filename, volume = 1, speed = 1, is_on = false):
        self.file = filename
        self.volume = volume
        self.speed = speed

    def load(self, launcher):
        clip = launcher.load(self.file)
        clip.speed(self.speed)
        clip.volume(self.volume)
        return clip


class Loop:
    def __init__(self, launcher, channel):
        self.launcher = launcher
        self.channel = channel

    def play(self):
        self.launcher.send_msg("LoopPlay", "%d" % self.channel)

    def stop(self):
        self.launcher.send_msg("LoopStop", "%d" % self.channel)

    def volume(self, value):
        self.launcher.send_msg("LoopSetVolume", "%d %f" % (self.channel, value))

    def speed(self, value):
        self.launcher.send_msg("LoopSetSpeed", "%d %f" % (self.channel, value))

    def rec(times = -1):
        self.launcher.send_msg("LoopRec", "%d %d" % (self.channel, times))

    def delete():
        self.launcher.send_msg("LoopDelete", "%d" % self.channel)

class LoopDef:
    def __init__(self, duration, volume = 1, is_on = false, times = 0):
        self.duration = duration
        self.volume = volume

    def alloc(self, launcher):
        loop = launcher.alloc(duration)
        loop.volume(volume)
        return loop

class Simpler:
    def __init__(self):        
        self.engine = csnd6.Csound()
        self.start_csound()
        self.free_channel = 0
        self.free_loop_channel = 0

    def start_csound(self):
        c = self.engine
        c.SetOption("-odac")
        c.Compile('simpler.csd')
        #c.Start()
        perf_thread = csnd6.CsoundPerformanceThread(c)
        perf_thread.Play()
        self.perf_thread = perf_thread

    def stop_csound(self):
        self.perf_thread.Stop()
        self.perf_thread.Join()
        self.engine.Reset()  

    def send_msg(self, instr_name, args):
        self.perf_thread.InputMessage("i \"%s\" 0 0.01 %s" % (instr_name, args))

    def bump_free_channel(self):
        self.free_channel += 1

    def bump_free_loop_channel(self):
        self.free_loop_channel += 1        

    def load(self, filename):        
        channel = self.free_channel
        self.send_msg("Load", "\"%s\" %d" % (filename, channel))
        self.bump_free_channel()
        return Clip(self, channel)

    def alloc(self, duration):
        channel = self.free_loop_channel
        self.send_msg("InitLoop", "%d %f" % (channel, duration))
        self.bump_free_loop_channel()
        return Loop(self, channel)
    
    def _clear_channels(self):
        [Clip(self, channel).stop() for channel in range(self.free_channel)]
    
    def scene(self, snds):
        self._clear_channels(self)
        clips = [ x.load(self) for x in snds ]
        for n in range(self.free_channel):
            if snds[n].is_on:
                clips[n].play()

    def play(self, *elems):
        [x.play() for x in elems]

    def stop(self, *elems):
        [x.stop() for x in elems]  

    def set_master_volume(self, value):
        self.send_msg("SetMasterVolume", "%f" % value)

    def set_tempo(self, bpm):
        self.send_msg("SetTempo", "%f" % bpm)

def test():
    q = Simpler()
    [kick, bass, click, pad1, pad2] = q.scene([ 
        Snd("kick.wav"), 
        Snd("bass.wav", is_on= true), 
        Snd("shaker.wav"), 
        Snd("pad.wav", is_on = true), 
        Snd("pad.wav", speed = -1, is_on = true)])

    q.play(pad1, pad2, bass)
    q.play(kick)
    kick.volume(0.5)

    q.stop(kick, bass); q.play(click)
    q.play(lick, bass)


if __name__ == "__main__":
    test()
