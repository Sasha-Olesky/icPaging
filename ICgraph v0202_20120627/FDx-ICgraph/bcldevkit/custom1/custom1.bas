'---------------------------------------------------------------------
' Full-duplex door intercom for ICgraph & ICphone
'---------------------------------------------------------------------

    DIM ver$(20)
    ver$="V0.25sg 20120625"
    SYSLOG "Full-duplex door intercom for ICgraph & ICphone "+ver$

    DIM _Ms$(1600)								'send and common buffer

    DIM _Mr$(1500)								'receiver audio buffer from UDP
    DIM _Ma$(1500)								'receiver audio buffer from applet
    DIM _Mc$(20)								'receiver UDP command buffer

    DIM _Mx$(1500)								'RTP send buffer, raw audio plus RTP header
    MIDSET _Mx$,1,1,&H80							'0x80 - init tx RTP block
    MIDSET _Mx$,9,-4,1								'SSRC field to one

    DIM ad_gn
    DIM mc_gn,mod,enc,rpo,port,ster,levth,stout,ctime,pr,vol
    DIM rho$(32),rhost$								'remote host
    DIM name$(21)								'own name for dynamic IP
    DIM rport,inp,inp2,pls,cnt,ln,talk
  
    IOCTL 1,0									'relay off
    ctime = 200									'check time for slow processes, ms

    OPEN "STP:500"   AS 2 : READ 2,set$ : CLOSE 2
    name$ = mid$(set$,1,20) SYSLOG "Own name: "+name$
    vol   = MIDGET(set$,25,1) : IF vol   > 20 THEN vol   = 20
    ad_gn = MIDGET(set$,30,1) : IF ad_gn > 15 THEN ad_gn = 15
    mc_gn = MIDGET(set$,60,1) : IF mc_gn > 15 THEN mc_gn = 15
    mod   = MIDGET(set$,97,1)   : mod_s = mod					'playback mode: current and source
    levth = MIDGET(set$,35,2)							'trigger level for send on level
    stout = MIDGET(set$,40,2)							'inactivity timeout - stop "send on level" after this number of ms
    pr    = MIDGET(set$,45,1) : IF pr<>6 THEN pr=1				'protocol 1-UDP, 6-RTP

    IF MIDGET(set$,55,1)=129 THEN inp=1 ELSE inp=2				'input (129=line, 130=mic)
    ster  = 0                                     				'for Annuncicom always MONO
    enc   = MIDGET(set$,101,1)                  				'encoding
    rho$  = SPRINTF$("%lA",MIDGET(set$,61,4)) rrho$ = rho$ 			'dst IP
    rpo   = MIDGET(set$,70,2) : IF rpo=0 THEN back=1 : rho$=""			'send "to origin source"
    port  = MIDGET(set$,75,2)                      				'listen port here (local)

    IF enc = 6  THEN pl = 97 'uLaw/24kHz
    IF enc = 7  THEN pl =  0 'uLaw/8kHz
    IF enc = 8  THEN pl = 98 'aLaw/24kHz
    IF enc = 9  THEN pl =  8 'aLaw/8kHz
    IF enc = 10 THEN pl = 99 'PCM MSB/24kHz
    IF enc = 11 THEN pl = 96 'PCM MSB/8kHz
    IF enc = 12 THEN pl = 105 'PCM LSB/24kHz
    IF enc = 13 THEN pl = 104 'PCM LSB/8kHz
    pls = pl 									'source payload type

    GOSUB 900									'open/reopen audio with new encoding by payload type

    WRITE 7,str$(ad_gn),   -2							'set A/D Gain
    WRITE 7,str$(mc_gn),   -1							'set Mic Gain
    WRITE 7,str$(inp),     -3							'set input source to mic/line
    WRITE 7,str$(ster),    -4							'set mono/stereo
    WRITE 7,str$(vol),    -12							'set volume to vol

    SYSLOG "source remote partner is ("+str$(pls)+")"+str$(pr)+">"+rho$+":"+str$(rpo)

    OPEN "UDP:0.0.0.0:"+str$(port) AS 4						'audio (listen) port
    OPEN "UDP:0.0.0.0:12301"       AS 5						'command port

'---------------------------------------------------------------
1000 'main loop
'---------------------------------------------------------------
    'checks receiving audio from audio input
    READ 7,_Ms$,txsiz : ln = LASTLEN(7)
    IF ln > 0 THEN
      IF talk=0 THEN goto 998							'bypASs IF no audio output
      IF pr=6 THEN								'RTP
        MIDSET _Mx$,3,-2,seq
        MIDSET _Mx$,5,-4,cnt
        MIDCPY _Mx$,13,ln,_Ms$							'copy in the data
        WRITE 4,_Mx$,ln+12,rho$,rpo						'sends audio stream to remote RTP
        cnt=cnt+ln
        seq=and(65535,seq+1)
      ELSE									'raw UDP
        WRITE 4,_Ms$,ln,rho$,rpo						'sends audio stream to remote UDP
      ENDIF
998 ENDIF

    'checks receiving audio from UDP port
    ln = lAStlen(4)
    IF ln < 0 THEN
        rhost$ = RMTHOST$(4)
        rport = RMTPORT(4)
      READ 4,_Mr$ : p_cnt = p_cnt+1 						'received packet counter increment
      IF back THEN
        rho$ = rhost$
        rpo  = rport
        IF MIDGET(_Mr$,1,1)=&H80 THEN pr = 6 : pln = and(MIDGET(_Mr$,2,1),127) ELSE pr = 1 : pln = pls 'RTP or raw UDP
        IF pl <> pln THEN pl = pln : GOSUB 900 					'set new audio encoding by gotten payload type
        new_m$ = "new remote partner is ("+str$(pl)+")"+str$(pr)+">"+rho$+":"+str$(rpo)
        IF new_m$ <> old_m$ THEN old_m$ = new_m$ : SYSLOG new_m$
      ENDIF
      IF rho$="" THEN GOTO 999							'cannot send IF no address
      IF pr=1 THEN WRITE 7,_Mr$,-ln 						'plays UDP stream into audio output
      IF pr=6 THEN
        lr =(-ln)-12
        seq_r = MIDGET(_Mr$,3,-2)
        lost  = seq_r - seq_o : seq_o = seq_r
        IF lost > 1 THEN SYSLOG "Lost RTP packets: "+str$(lost-1)+" before # "+str$(seq_r)
        MIDCPY _Mr$,1,lr,_Mr$,13						'copy audio data from offset 13
        IF lost < 10 THEN							'ignore RTP header data IF too much lost packets
          FOR i = 1 TO lost : WRITE 7,_Mr$,lr : NEXT i				'output audio
        ENDIF
      ENDIF
    '''goto 998 'try to keep all packages
999 ENDIF 

    IF _TMR_(0)-tsd < ctime THEN GOTO 1000 ELSE tsd = _TMR_(0)	'check slow processes each ctime ms

	
'checks received command from UDP port
'----------------------------------------------------------------
    ln = lAStlen(5)
    IF ln < 0 THEN
      rhost$ = RMTHOST$(5)
      READ 5,_Mc$ : SYSLOG "command input: "+_Mc$
      IF _Mc$ = "c=65535" THEN							'broadcast DISCOVER command
        WRITE 5,"<ANNUNCICOMIC><NAME>"+name$+"</NAME></ANNUNCICOMIC>",0,rhost$,3040
      ELSE
        IF rho$ = rhost$ THEN							'fulfil the command only from current remote IP
          IF _Mc$ = "c=91" THEN mod = 0						'flag up for force talk
          IF _Mc$ = "c=84" THEN mod = mod_s					'flag down for force talk, restore source mode
          IF _Mc$ = "c=80" THEN IOCTL 1,1 : ods = _TMR_(0)			'open door for 3 sec
          IF _Mc$ = "c=78" THEN IOCTL 1,1					'open door
          IF _Mc$ = "c=79" THEN IOCTL 1,0					'close door
          IF _Mc$ = "c=60" THEN IOCTL 200,1					'switch on RTS
          IF _Mc$ = "c=61" THEN IOCTL 200,0					'switch off RTS
          IF _Mc$ = "c=89" THEN SYSLOG "value " + SPRINTF$("%u",IOSTATE(300)),1 'report CTS
          WRITE 5,"<ACK/>",0,rho$,3040						'send confirmation
        ENDIF
      ENDIF
    ENDIF
    IF ods THEN IF _TMR_(0)-ods > 3000 THEN IOCTL 1,0 ods = 0	'close door after 3 sec

    'checks receiving data from button inputs
    IF OR(IOSTATE(202)=1,IOSTATE(202)=3) THEN ring = 0 ELSE ring = ring + 1	'ring button I1 is not pressed
    IF ring = 1 THEN								'sends RING only just after pressing
      IF rho$ THEN
        WRITE 5,"RING ",0, rho$,3040 SYSLOG "RING request"			'sends RING to talk IP
      ELSE
        WRITE 5,"RING ",0,rrho$,3040 SYSLOG "RING request"			'sends RING to setup IP
      ENDIF
    ENDIF
    IF mod = 0 THEN talk = 1							'send always
    IF mod = 1 THEN IF OR(IOSTATE(201)=3,IOSTATE(201)=1) THEN talk = 0 ELSE talk = 1	'talk button I0 is not pressed
    IF mod = 2 THEN IF p_cnt THEN talk = 1 ELSE talk = 0			'UDP audio was received for latest ctime ms
    IF mod = 3 THEN
      READ 7,_Ms$,-1 : levl=lAStlen(7)						'left (suppose, only left is enough for mono)
      IF levl >= levth THEN
        IF talk = 0 THEN SYSLOG "start talk with level "+str$(levl)+" >= "+str$(levth)
        talk = 1 : ltime = _TMR_(0)						'remember latest time "send on level"
      ELSE
        IF talk THEN IF _TMR_(0)-ltime >= stout THEN talk = 0 : SYSLOG "stop talk with level "+str$(levl)+" after pause "+str$(stout)+" ms"
      ENDIF
    ENDIF

    p_cnt = 0									'drop received packet counter
    GOTO 1000
'---------------------------------------------------------------
END

'---------------------------------------------------------------
900 'open/reopen audio with new encoding by payload type
'---------------------------------------------------------------
    IF  MEDIATYPE(7) THEN WRITE 7,"",0 : CLOSE 7				'flush buffer and close
    bufhi = 3000 : txsiz = 480

    IF pl = 0   THEN qlty = &H0008 : bit5 = 0					'uLaw, 8bit, mono, 8kHz
    IF pl = 8   THEN qlty = &H0108 : bit5 = 0					'aLaw, 8bit, mono, 8kHz
    IF pl = 10  THEN qlty = &H122C : bit5 = 0					'PCM, 16bit, MSB first, signed, 44.1kHz stereo, left channel first
    IF pl = 11  THEN qlty = &H022C : bit5 = 0					'PCM, 16bit, MSB first, signed, 44.1kHz mono
    IF pl = 96  THEN qlty = &H0208 : bit5 = 0					'PCM, 16bit, MSB first, signed,  8kHz mono
    IF pl = 97  THEN qlty = &H0018 : bit5 = 0 : bufhi = 16384 : txsiz = 1200	'u-Law, 8bit, mono, 24kHz
    IF pl = 98  THEN qlty = &H0118 : bit5 = 0 : bufhi = 16384 : txsiz = 1200	'a-Law, 8bit, mono, 24kHz
    IF pl = 99  THEN qlty = &H0218 : bit5 = 0 : bufhi = 16384 : txsiz = 1200	'PCM, 16bit, MSB first, signed, 24kHz mono
    IF pl = 100 THEN qlty = &H0020 : bit5 = 0					'uLaw, 8bit, mono, 32kHz
    IF pl = 101 THEN qlty = &H0120 : bit5 = 0					'aLaw, 8bit, mono, 32kHz
    IF pl = 102 THEN qlty = &H0220 : bit5 = 0					'PCM, 16bit, MSB first, signed, 32kHz mono
    IF pl = 103 THEN qlty = &H1230 : bit5 = 0					'PCM, 16bit, MSB first, signed, 48kHz stereo, left channel first
    IF pl = 104 THEN qlty = &H0208 : bit5 = 1					'PCM, 16bit, LSB first, signed,  8kHz mono
    IF pl = 105 THEN qlty = &H0218 : bit5 = 1 : bufhi = 16384 : txsiz = 1200	'PCM, 16bit, LSB first, signed, 24kHz mono
    IF pl = 106 THEN qlty = &H0220 : bit5 = 1					'PCM, 16bit, LSB first, signed, 32kHz mono
    IF pl = 107 THEN qlty = &H122C : bit5 = 1					'PCM, 16bit, LSB first, signed, 44.1kHz stereo, left channel first
    IF pl = 108 THEN qlty = &H1230 : bit5 = 1					'PCM, 16bit, LSB first, signed, 48kHz stereo, left channel first
    IF pl = 109 THEN qlty = &H000C : bit5 = 0					'uLaw, 8bit, mono, 12kHz
    IF pl = 110 THEN qlty = &H010C : bit5 = 0					'aLaw, 8bit, mono, 12kHz
    IF pl = 111 THEN qlty = &H020C : bit5 = 0					'PCM, 16bit, MSB first, signed, 12kHz mono
    IF pl = 112 THEN qlty = &H020C : bit5 = 1					'PCM, 16bit, LSB first, signed, 12kHz mono

    audio$ = "AUD:11,"+str$(or(0,shl(bit5,5)))+","+str$(or(qlty,shl(3,10)))+","+str$(bufhi) 'encoder/decoder
    OPEN audio$ AS 7								'open audio
    MIDSET _Mx$,2,1,pl								'set proper payload type for RTP
    RETURN
'------------------------------------------------------------------------------
