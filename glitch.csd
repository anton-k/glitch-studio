
<CsoundSynthesizer>
<CsOptions>
; Select audio/midi flags here according to platform
-odac     ;;;realtime audio out
;-iadc    ;;;uncomment -iadc if realtime audio input is needed too
; For Non-realtime ouput leave only the line below:
; -o flooper2.wav -W ;;; for file output any platform
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 32
nchnls = 2
0dbfs  = 1

#include "buffer_looper.csd"


opcode trackerSplice, a, akk
asig, kseglength, kmode xin

setksmps 1
kindx init 0
ksamp init 1
aout init 0

itbl ftgenonce 0, 0, 2^16, 7, 0, 2^16, 0	;create table to hold samples
kseglength = kseglength*sr			;convert length to samples
andx phasor sr/ftlen(itbl)			;ensure phasor is set to correct freq
tabw asig, andx*ftlen(itbl), itbl		;write signal to table
andx1 delay andx, 1				;insert a 1 sample delay so that the read point
						;always stays one sample behind the write pointer
apos samphold andx1*ftlen(itbl), ksamp		;hold sample position whem ksamp=0

if(kmode>=1 && kmode <2) then 				;do retrigger when kmode==1
	kpos downsamp apos
	kindx = (kindx>kseglength ? 0 : kindx+1)
	if(kindx+kpos> ftlen(itbl)) then
	kindx = -kseglength
	endif
	aout table apos+kindx, itbl, 0, 1
	ksamp = 0	

elseif(kmode>=2 && kmode<3) then				;do reverse when kmode==2 
	kpos downsamp apos
	kindx = ((kindx+kpos)<=0 ? ftlen(itbl)-kpos : kindx-1)
	aout table apos+kindx, itbl, 0, 1
	ksamp = 0

else 						;when kmode==0 simple pass signal through
	ksamp = 1
	aout = asig
endif
xout aout
endop

; #include "adsr140.udo"

opcode Glitch, a, iiiiiiiii
	iTab, iSpeed, iBpm, iNum, iSub, iRep, iRev, iSubDiv, iSkip xin

	iRate = iBpm / (60 * iSub)
	iSegLength = 1 / iRate
	iTabLength = nsamp(iTab) / sr

	kSpeed init iSpeed
	kLength init iTabLength
	kStart  init 0
	
	iAlt = 1 - (iRep + iRev)
	kMode init 0
	kSegLength init iSegLength

	kTrig metro iRate
	kVol init 1
	kCount init 0
	if kTrig == 1 then
		if kCount != 0 then
			kAlt random 0, 1
			
			if kAlt > iAlt then 
				kSubDiv random 0, 1
				kSegLength = ((kSubDiv > 1 - iSubDiv) ? 0.25 : 1) * iSegLength

				kRev random 0, 1
				if kRev < iRev then
					kMode = 1
				else
					kMode = 2
				endif
			else 			
				kMode = 0				
			endif			
		else 
			kMode = 0
			kSegLength = iSegLength
		endif

		kCount = (kCount == iNum) ? 0 : kCount + 1
	endif

	asig flooper2 1, kSpeed, kStart, kLength, 0, iTab
	aout trackerSplice asig, kSegLength, kMode

	kVolTrig metro (iRate * 4)
	iVolNum = iNum * 4
	kVolCount init 0
	if kVolTrig == 1 then
		if kVolCount > 4 then
			kSkip random 0, 1
			if (kSkip > 1 - iSkip) then
				kVol = 0
			else 
				kVol = 1
			endif
		endif

		kVolCount = (kVolCount == iVolNum) ? 0 : kVolCount + 1
	endif

	; aretrig init 0
	; kEnvTrig changed kMode
	; aEnvTrig = kEnvTrig
	; aEnv adsr140 aEnvTrig, aretrig, 0.01, 1000, 1, 1000

	kVol1 port kVol, 0.01
	xout aout * kVol1
endop


instr 1
; looping back and forth,  0.05 crossfade 
kst  = 0 ;line     .2, p3, 2 ;vary loopstartpoint
iLen = ftlen(1) / sr
;aout flooper2 .8, 1, 0, iLen, 0.05, 1

aout Glitch 1, 1, 87, 4, 2, 0.25, 0.4, 0.3, 0.05
     outs     aout, aout

endin
</CsInstruments>
<CsScore>
; Its table size is deferred,
; and format taken from the soundfile header
f 1 0 0 1 "TQT28.wav" 0 0 0

i 1 0 16
e
</CsScore>
</CsoundSynthesizer>

