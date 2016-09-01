<CsoundSynthesizer>
<CsOptions>
-odac   -d -+rtaudio=alsa
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 64
nchnls = 2
0dbfs  = 1

#define MONO_INSTR #31#
#define STEREO_INSTR #32#

#define REC_LOOP_INSTR # 33 #
#define PLAY_LOOP_INSTR # 34 #

#define IDENTITY_FX_INSTR   # 40 # 
#define REVERB_FX_INSTR     # 41 #
#define BBCUTS_FX_INSTR     # 42 #
#define DELAY_FX_INSTR      # 43 #
#define TREMOLO_FX_INSTR    # 44 #
#define CHORUS_FX_INSTR     # 45 #
#define PULSAR_1_FX_INSTR   # 46 #  
#define PULSAR_2_FX_INSTR   # 47 #  
#define PULSAR_3_FX_INSTR   # 48 # 
#define PULSAR_4_FX_INSTR   # 49 #
#define PAN_CIRCLE_FX_INSTR # 50 #

#ifndef SIZE
    #define SIZE        # 16 #
#end

#define MAX_TIME    # 1000000 #

#define MONO_WAV    # 1 #  
#define STEREO_WAV  # 2 #
#define MP3         # 3 #

giTab1s[]       init $SIZE     ; Tables for wavs   Left   channel
giTab2s[]       init $SIZE     ;                   Right
giLens[]        init $SIZE

gkTempo         init 120
gkTick          init 0
gkLocalTicks[]  init $SIZE

gkCurrentPlay[] init $SIZE
gkNextPlay[]    init $SIZE 
gkVolumes[]     init $SIZE
gkTypes[]       init $SIZE
gkRatios[]      init $SIZE

gkSpeed[]       init $SIZE
gkNextSpeed[]   init $SIZE

gkMasterVolume  init 1
giVolumeScale   init 1

gaL             init 0
gaR             init 0

gkFadeTime      init 0.001

; ---------------------------------------------------------
; looper

#include "buffer_looper.csd"

#define PLAY_LOOP # 0 #
#define STOP_LOOP # 1 #
#define REC_LOOP  # 2 #
#define FIN_REC_LOOP # 3 #
#define DEL_LOOP # 4 #

#ifndef SIZE
    #define LOOP_SIZE        # 8 #
#end

gkLoopPlay[]        init $LOOP_SIZE
gkNextLoopPlay[]    init $LOOP_SIZE

giLoopTab1s[]       init $LOOP_SIZE     ; Tables for looper   Left   channel
giLoopTab2s[]       init $LOOP_SIZE     ;                     Right
giLoopLens[]        init $LOOP_SIZE

gkLoopLocalTicks[]  init $LOOP_SIZE

gkLoopRatios[]      init $LOOP_SIZE
gkLoopVolumes[]     init $LOOP_SIZE

gkLoopSpeed[]       init $LOOP_SIZE
gkNextLoopSpeed[]   init $LOOP_SIZE

gkLoopRecTimes[]     init 0
gkNextLoopRecTimes[] init 0

; ----------------------------------------------------------
; Fx matrix

#ifndef SIZE
    #define FX_SIZE        # 4 #
#end

gaOuts[][]          init 2 * ($FX_SIZE + 1), $SIZE
gaLoopOuts[][]      init 2 * ($FX_SIZE + 1), $LOOP_SIZE

giFxs[][]            init 2 * $FX_SIZE, $SIZE
giLoopFxs[][]        init 2 * $FX_SIZE, $LOOP_SIZE

; ---------------------------------------------------------
; effects

opcode ReadFx, aa, iii
    iType, iChannel, iId xin
    if iType == $SAMPLE_TYPE then
        aL = gaOuts[2 * iId][iChannel]
        aR = gaOuts[2 * iId + 1][iChannel]
    else
        aL = gaLoopOuts[2 * iId][iChannel]
        aR = gaLoopOuts[2 * iId + 1][iChannel]
    endif
endop

opcode WriteFx, 0, aakaaiii
    aDryL, aDryR, kMix, aWetL, aWetR, kMix, iType, iChannel, iPrevId xin
    iId = iPrevId + 1

    aL ntrpol aDryL, aWetL, kMix
    aR ntrpol aDryR, aWetR, kMix 
    if iType == $SAMPLE_TYPE then
        gaOuts[2 * iId][iChannel] = aL
        gaOuts[2 * iId + 1][iChannel] = aR
    else
        gaLoopOuts[2 * iId][iChannel] = aL
        gaLoopOuts[2 * iId + 1][iChannel] = aR
    endif        
endop

instr $IDENTITY_FX_INSTR 
    iType, iChannel, iId passign 4
    aL, aR ReadFx iType, iChannel, iId
    WriteFx aDryL, aDryR, 0, aL, aR, iType, iChannel, iId
endin

instr $REVERB_FX_INSTR
    iType, iChannel, iId, iMix, ifblvl, ifco passign 4  
    aDryL, aDryR ReadFx iType, iChannel, iId

    aL, aR reverbsc aDryL, aDryR, ifblvl, ifco

    WriteFx aDryL, aDryR, iMix, aL, aR, iType, iChannel, iId  
endin

instr $BBCUTS_FX_INSTR
    iType, iChannel, iId, iMix, isubdiv, ibarlength, iphrasebars, inumrepeats passign 4  
    aDryL, aDryR ReadFx iType, iChannel, iId
    ibps = i(gkTempo)

    aL, aR bbcuts aDryL, aDryR, ibps, isubdiv, ibarlength, iphrasebars, inumrepeats    

    WriteFx aDryL, aDryR, iMix, aL, aR, iType, iChannel, iId  
endin

; ---------------------------------------------------------

opcode IsMp3, i, S
    SFile xin
    iLen strlen SFile
    SExt strsub SFile, iLen - 4, iLen
    iCmp strcmp SExt, ".mp3"
    iRes = (iCmp == 0) ? 1 : 0
    xout iRes
endop

opcode WriteOut, 0, aak
    aL, aR, kRawVol xin
    kVol    port kRawVolume, 0.05    
    gaL     = gaL + kVol * aL
    gaR     = gaR + kVol * aR    
endop

instr Load   
    SFile, iId passign 4
    event_i "i", "PlaybackChannel", 0, $MAX_TIME, iId

    iTab1 = giTab1s[iId]
    iTab2 = giTab2s[iId]

    iIsMp3 IsMp3 SFile

    if (iIsMp3 == 1) then
        iType = $MP3
        iDummy ftgen iTab1, 0, 0, 49, SFile, 0, 3
        iDummy ftgen iTab2, 0, 0, 49, SFile, 0, 4
        iLen   mp3len SFile
    else
        iChnls filenchnls SFile
        iLen   filelen SFile
        if (iChnls == 1) then
            iType = $MONO_WAV
            iDummy  ftgen iTab1, 0, 0, 1, SFile, 0, 0, 1            
        else
            iType = $STEREO_WAV
            iDummy  ftgen iTab1, 0, 0, 1, SFile, 0, 0, 1            
            iDummy  ftgen iTab2, 0, 0, 1, SFile, 0, 0, 2            
        endif
    endif  
    kId init iId      
    
    gkTypes[kId] = iType  
    giLens[iId] = iLen  
    turnoff
endin

; -------------------------------------------------
; Settings API

instr SetMasterVolume    
    gkMasterVolume = p4
    turnoff
endin

instr SetTempo 
    gkTempo = p4
    turnoff    
endin

; -------------------------------------------------
; Sample playback API

instr Play
    iChannel = p4
    gkNextPlay[iChannel] = 1
    turnoff
endin

instr Stop
    iChannel = p4
    gkNextPlay[iChannel] = 0
    turnoff
endin

instr SetVolume 
    iChannel, iVol passign 4
    gkVolumes[iChannel] = iVol
    turnoff
endin

instr SetSpeed
    iChannel, iSpeed passign 4
    gkNextSpeed[iChannel] = iSpeed
    turnoff
endin

; -------------------------------------------------
; Looper API

instr InitLoop
    iChannel, iLength passign 4
    event_i "i", "LoopChannel", 0, $MAX_TIME, iId

    iTab1, iTab2 BufCrt2 iLength, giLoopTab1s[iChannel], giLoopTab2s[iChannel]
    giLoopLens[iChannel] = iLength    
endin

instr LoopPlay
    iChannel = p4
    gkNextLoopPlay[iChannel] = $PLAY_LOOP
    turnoff
endin

instr LoopStop
    iChannel = p4
    gkNextLoopPlay[iChannel] = $STOP_LOOP
    turnoff
endin

instr LoopRec
    iChannel, iTimes passign 4
    gkNextLoopPlay[iChannel] = $REC_LOOP
    gkNextLoopRecTimes = iTimes
    turnoff
endin

instr LoopFinRec
    iChannel = p4
    gkNextLoopPlay[iChannel] = $FIN_REC_LOOP
    gkNextLoopRecTimes = 0
    turnoff
endin

instr LoopDelete
    iChannel = p4
    gkNextLoopPlay[iChannel] = $DEL_LOOP
    gkNextLoopRecTimes = 0
    turnoff
endin

instr SetLoopVolume 
    iChannel, iVol passign 4
    gkLoopVolumes[iChannel] = iVol
    turnoff
endin

instr SetLoopSpeed
    iChannel, iSpeed passign 4
    gkNextLoopSpeed[iChannel] = iSpeed
    turnoff
endin

; -------------------------------------------------
; FX chain API

instr ReverbFx 
    iIsLoop, iChannel, iPos, iMix, iFbklvl, iFco passign 4
    StopFx iIsLoop, iChannel, iPos
    iId GetFxId $REVERB_FX_INSTR, iIsLoop, iChannel, iPos
    event_i "i", iId, 0, -1, iIsLoop, iChannel, iPos, iMix, iFbklvl, iFco
endin

instr BbcutsFx 
    iType, iChannel, iId, iMix, isubdiv, ibarlength, iphrasebars, inumrepeats passign 4
    StopFx iIsLoop, iChannel, iPos
    iId GetFxId $BBCUTS_FX_INSTR, iIsLoop, iChannel, iPos
    event_i "i", iId, 0, -1, iType, iChannel, iId, iMix, isubdiv, ibarlength, iphrasebars, inumrepeats
endin


; -------------------------------------------------

opcode FracInstr, k, kk
    kInstrNum, kChannel xin
    kres = kInstrNum + ((kChannel + 1) / 1000)
    xout kres
endop

opcode GetInstrId, k, i
    iChannel xin
    if gkTypes[iChannel] == $MONO_WAV then
        kRes = $MONO_INSTR
    else
        kRes = $STEREO_INSTR
    endif
    kFracRes FracInstr kRes, iChannel
    xout kFracRes
endop

opcode GetPlayInstrId, k, i
    iChannel xin
    kFracRes FracInstr $PLAY_LOOP_INSTR, iChannel
    xout kFracRes
endop

opcode GetRecInstrId, k, i
    iChannel xin
    kFracRes FracInstr $REC_LOOP_INSTR, iChannel
    xout kFracRes
endop

opcode UpdateLocalTick, 0,k 
    kChannel xin

    if gkTick == 1 then
        gkLocalTicks[kChannel] = gkLocalTicks[kChannel] + 1
        if gkLocalTicks[kChannel] >= gkRatios[kChannel] then
            gkLocalTicks[kChannel] = 0
        endif
    endif
endop

opcode IsTriggerTime, k,k
    kChannel xin    
    kRes = (gkTick == 1 && gkLocalTicks[kChannel] == 0) ? 1 : 0
    xout kRes
endop

opcode StartInstr 0, kkk
    kInstrId, kChannelm kDur xin
    event "i", kInstrId, 0, kDur, kChannel
endop

opcode StartInstrInf 0, kk
    kInstrId, kChannel xin
    event "i", kInstrId, 0, -1, kChannel
endop

opcode StopInstr 0,k
    kInstrId xin
    turnoff2 kInstrId, 4, gkFadeTime
endop

opcode, UpdateFxChain, 0, i
    ; TODO
endop

instr PlaybackChannel
    iChannel = p4
    kChannel init iChannel

    UpdateLocalTick kChannel
    kIsTriggerTime IsTriggerTime kChannel
    if kIsTriggerTime == 1 then   
        if gkCurrentPlay[kChannel] != gkNextPlay[kChannel] then
            kInstrId GetInstrId iChannel
            printks "Trigger time: %f", 0, kInstrId

            if gkNextPlay[kChannel] == 1 then
                StartInstrInf kInstrId, iChannel
            endif
            
            if gkNextPlay[kChannel] == 0 then
                StopInstr kInstrId                
            endif

            gkCurrentPlay[kChannel] = gkNextPlay[kChannel]
        endif

        if gkSpeed[kChannel] != gkNextSpeed[kChannel] then
            gkSpeed[kChannel] = gkNextSpeed[kChannel]
        endif
    endif

    UpdateFxChain kChannel
endin

opcode UpdateLoopLocalTick, 0,k 
    kChannel xin    
    if gkTick == 1 then
        gkLoopLocalTicks[kChannel] = gkLoopLocalTicks[kChannel] + 1
        if gkLoopLocalTicks[kChannel] >= gkLoopRatios[kChannel] then
            gkLoopLocalTicks[kChannel] = 0
        endif
    endif
endop

opcode IsTriggerTime, k,k
    kChannel xin    
    kRes = (gkTick == 1 && gkLoopLocalTicks[kChannel] == 0) ? 1 : 0
    xout kRes
endop

opcode, UpdateLoopFxChain, 0, i
    ; TODO
endop

instr LoopChannel
    iChannel = p4
    kChannel init iChannel

    UpdateLoopLocalTick kChannel
    kIsTriggerTime IsLoopTriggerTime kChannel
    if kIsTriggerTime == 1 then        
        if gkLoopPlay[kChannel] != gkNextLoopPlay[kChannel]

            if      gkLoopPlay[kChannel] == $PLAY_LOOP then
                kInstrId GetPlayLoopInstrId kChannel
                StartInstrInf kInstrId   

            elseif  gkLoopPlay[kChannel] == $STOP_LOOP then

                kInstrId GetPlayLoopInstrId kChannel
                StopInstr kInstrId

            elseif  gkLoopPlay[kChannel] == $REC_LOOP  then
                kInstrId GetPlayLoopInstrId kChannel

                kActiveRecs kInstrId
                if kActiveRecs > 0 then
                    StoInstr kInstrId
                endif

                if gkLoopRecTimes < 0 then                
                    StartInstrInf kInstrId
                else
                    StartInstr kInstrId, gkLoopRecTimes * gkLoopRatios[kChannel]
                endif 

            elseif  gkLoopPlay[kChannel] == $DEL_LOOP  then
                ; TODO
            elseif  gkLoopPlay[kChannel] == $FIN_REC_LOOP then
                kInstrId GetPlayLoopInstrId kChannel
                StopInstr kInstrId
            endif

            gkNextLoopPlay[kChannel] = gkLoopPlay[kChannel]
        endif

        if gkLoopSpeed[kChannel] != gkNextLoopSpeed[kChannel] then
            gkLoopSpeed[kChannel] = gkNextLoopSpeed[kChannel]
        endif
    endif

    UpdateLoopFxChain iChannel
endin


opcode WriteTicks, 0,0
    kTempo port gkTempo, 0.05
    gkTick metro (kTempo / 60)
endop

opcode WriteMasterOut, 0,0
    aL, aR xin
    kVol   port gkMasterVolume, 0.05
    outs gaL * kVol * giVolumeScale, gaR * kVol * giVolumeScale
    gaL = 0
    gaR = 0
endop

instr TheHeart
    WriteTicks
    WriteMasterOut 
endin

opcode ReadTab, a, kii
    kSpeed, iTab, iLen xin
    ;aSnd lposcil3 1, kSpeed, 0, ftlen(iTab1), iTab1   ; doesn't allows reverse playback
    aSnd flooper 1, kSpeed, 0, iLen, 0, iTab
    xout asig
endop


opcode RunDirectMono, aa, i
    iId xin
    aSnd ReadTab gkSpeed[iId], giTab1s[iId], giLens[iId]
    xout aSnd, aSnd
endop 

opcode RunDirectStereo, aa, i
    iId xin
    kSpeed = gkSpeed[iId]    
    aSnd1 ReadTab kSpeed, giTab1s[iId], giLens[iId]
    aSnd2 ReadTab kSpeed, giTab1s[iId], giLens[iId]    
    xout aSnd1, aSnd2
endop 

instr $MONO_INSTR    
    iChannel = p4
    aL, aR RunDirectMono iChannel
    WriteOut aL, aR, gkVolumes[iChannel]
endin

instr $STEREO_INSTR    
    iChannel = p4
    aL, aR RunDirectStereo iChannel    
    WriteOut aL, aR, gkVolumes[iChannel]
endin

instr $PLAY_LOOP_INSTR
BufPlay2, aak, iikkkkkk
    aL, aR, kRec BufPlay2 giLoopTab1s[iChannel], giLoopTab2s[iChannel], 1, gkLoopSpeed[iChannel], 1, 0, giLoopLens[iChannel], $WRAP_START_END
    WriteOut aL, aR, gkLoopVolumes[iChannel]
endin

#define WRAP_START_END # 1 #

instr $REC_LOOP_INSTR
    iChannel = p4
    BufRec2 gaIn1, gaIn2, giLoopTab1s[iChannel], giLoopTab2s[iChannel], 1, 0, giLoopLens[iChannel], $WRAP_START_END
endin

opcode DummyTab i,0
    iTab ftgen 0, 0, 4, 7, 0, 4, 0
    xout iTab    
endop

instr Init
    iTab1 = 0
    iTab2 = 0

    ii = 0
    while ii < $SIZE do
        iTab1 DummyTab
        iTab2 DummyTab
        giTab1s[ii] = iTab1
        giTab2s[ii] = iTab2
        giLens[ii] = 0
        print iTab1        
        print iTab2        
        ii = ii + 1        
    od

    ki = 0
    while ki < $SIZE do
        gkLocalTicks[ki] = 0
        gkCurrentPlay[ki] = 0
        gkNextPlay[ki] = 0
        gkVolumes[ki] = 1
        gkTypes[ki] = 0
        gkRatios[ki] = 8
        gkSpeed[ki] = 1
        gkNextSpeed[ki] = 1        
        ki = ki + 1        
    od

    ii = 0
    while ii < $LOOP_SIZE do
        iTab1 DummyTab
        iTab2 DummyTab
        giLoopTab1s[ii] = iTab1
        giLoopTab2s[ii] = iTab2
        giLoopLens[ii] = 0
    od

    ki = 0
    while ki < $LOOP_SIZE do
        gkLoopPlay[ki]        = $STOP_LOOP
        gkNextLoopPlay[ki]    = $STOP_LOOP
        gkLoopLocalTicks      = 8

        gkLoopRatios[ki]      = 8
        gkLoopVolumes[ki]     = 1

        gkLoopSpeed[ki]       = 1
        gkNextLoopSpeed[ki]   = 1
    od
    turnoff
endin

</CsInstruments> 

<CsScore>
#define MAX_TIME    # 1000000 #
f0 $MAX_TIME

i "Init" 0 0.01
i "TheHeart" 0 -1
e

</CsScore>

</CsoundSynthesizer>
