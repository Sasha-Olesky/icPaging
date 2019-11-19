CoB1$)�   custom1.bas� �)  custom1.html%�*  custom1.tokq)�8  custom1_config.html[b  custom1_help.html
�sm  ERRORS.HLP-~  mimetype.ini '---------------------------------------------------------------------
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
HTTP/1.0 200
Content-type: text/html

<html>
<frameset cols="500,*" frameborder=no border=0>
        <frame src="custom1_config.html">
        <frame src="custom1_help.html">
</frameset>
</html>
TB(�                         !      %       )      $.      (3      ,9      0?      4E      8H      <L      uR      yV      }[      �_      �c      �f      �k      �q      �v      �y      �      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��      ��    �  @( �  �h�  �D�    �  �4�    @�   `�   `�   �    �   �   �   �� 	V0.25sg 20120625 ?Full-duplex door intercom for ICgraph & ICphone  � D�� D�	<`
	� -STP:500 .0�	/�	Z�	?Own name:  �`	%�	` `	`	%�	` `	`	%�	<` `	`	%�	a`	``	%�	#`		%�	(`	%�	-` `	%�	7	� 	 `	E `	`	`	%�	e�	\%lA %�	=�
	�`	%�	F`	 `	�	 `	%�	K`	 `	a`	 `	`	 `	b`		 `	`	
 `	c`	 `	``	 `	i`	 `	h`	` �1X`1X`1X`1X`1X`?source remote partner is ( X`) X`> �: X`-UDP:0.0.0.0: X`.-UDP:0.0.0.0:12301 .0�``	2`� `	 �`	\ D�`D�`&�`�1�`�``	```	H��  `E 1�`�`FF`	2`��	]`	50�`	``� �	�`	`%�	�  `	`	H%�E `	`	``` `	` ��	new remote partner is ( X`) X`> �: X`�� �	�?�F�	  b`	 1�``	� `	``	%�`	```	``3 ?Lost RTP packets:  X` before #  X`&�`�`
 `	`1�``FFF` ` `
	 E ` 	` `	2`U�	]0�?command input:  ��	c=65535 F 1<ANNUNCICOMIC><NAME> �</NAME></ANNUNCICOMIC> ��E� �	�� �	c=91  `	�	c=84  `	`�	c=80  <`!	` �	c=78  <�	c=79  <�	c=60 	 <� �	c=61 	 <� �	c=89  ?value  \%u ;,1<ACK/> ��FFF`! ` `!� <`!	I;� 	;� 		 `"	E
 `"	`"`"	Y �* 1RING  ��?RING request E( 1RING  �
�?RING request FF`	 `	`	' I;� 	;� 		 `	E `	`	 `	 `	E `	`	� 0�`#	2`#	`H `	/ ?start talk with level  X`# >=  X``	`$	` EY `Q ` `$	`	A `	?stop talk with level  X`# after pause  X`	 ms FF`	"4 1 /`%	�`	�`	 `&	`'	`	 `&	`'	`	
 `&	,`'	`	 `&	,`'	`	` `&	`'	`	a `&	`'	`%	 @`	�`	b `&	`'	`%	 @`	�`	c `&	`'	`%	 @`	�`	d `&	 `'	`	e `&	 `'	`	f `&	 `'	`	g `&	0`'	`	h `&	`'	`	i `&	`'	`%	 @`	�`	j `&	 `'	`	k `&	,`'	`	l `&	0`'	`	m `&	`'	`	n `&	`'	`	o `&	`'	`	p `&	`'	�	AUD:11, XI6`', XI`&6
, X`%-�.D�`!_TMR_ AD_GN MC_GN MOD ENC RPO PORT STER LEVTH STOUT CTIME PR VOL RPORT INP INP2 PLS CNT LN TALK MOD_S BACK PL TXSIZ SEQ P_CNT PLN LR SEQ_R LOST SEQ_O I TSD ODS RING LEVL LTIME BUFHI QLTY BIT5 VER$ _MS$ _MR$ _MA$ _MC$ _MX$ RHO$ RHOST$ NAME$ SET$ RRHO$ NEW_M$ OLD_M$ AUDIO$ HTTP/1.0 200
Content-type: text/html

<html>&L(0,"*");
<head><script language=JavaScript src=util.js></script>
</head>
<body link=#FFFFFF vlink=#FFFFFF alink=#FFFFFF leftmargin=0 topmargin=0><font face="Arial, Helvetica, sans-serif">
<br>
<table width=640 border=0 bgcolor=#8F2635>
<tr>
        <td><font size=2 color="#FFFFFF"><b><br>&nbsp;FULL DUPLEX DOOR INTERCOM FOR ICGRAPH<br>&nbsp;</td>
</tr>
</table>

<table cellspacing=5>
        <form action=setup.cgi method=get><input type=hidden name=L value=rebooting.html>
        <tr>
                <th><font size=2><br>AUDIO</th><td></td>
        </tr>
        <tr>
                <td><b><font size=2>Input source</td>
                <td><font size=2>
                        <input type=radio name=B554 value=129 &LSetup(3,"%s",554,B,129,"checked");> Line
                        <input type=radio name=B554 value=130 &LSetup(3,"%s",554,B,130,"checked");> Mic         </td>
        </tr>
        <tr>
                <td><b><font size=2>Encoding</td>
                <td>
                        <select size=1 name=B600>
                                <option value=6 &LSetup(3,"%s",600,B,6,"selected");>uLaw / 24 kHz (G.711)</option>
                                <option value=7 &LSetup(3,"%s",600,B,7,"selected");>uLaw / 8 kHz (G.711)</option>
                                <option value=8 &LSetup(3,"%s",600,B,8,"selected");>aLaw / 24 kHz (G.711)</option>
                                <option value=9 &LSetup(3,"%s",600,B,9,"selected");>aLaw / 8 kHz (G.711)</option>
                                <option value=10 &LSetup(3,"%s",600,B,10,"selected");>PCM MSB / 24 kHz (16bit)</option>
                                <option value=11 &LSetup(3,"%s",600,B,11,"selected");>PCM MSB / 8 kHz (16bit)</option>
                                <option value=12 &LSetup(3,"%s",600,B,12,"selected");>PCM LSB / 24 kHz (16bit)</option>
                                <option value=13 &LSetup(3,"%s",600,B,13,"selected");>PCM LSB / 8 kHz (16bit)</option>
                        </select>               </td>
        </tr>
        <tr>
                <td><b><font size=2>Volume</td>
                <td>
                        <select size=1 name=B524>
                                <option value=0 &LSetup(3,"%s",524,B,0,"selected");>0</option>
                                <option value=1 &LSetup(3,"%s",524,B,1,"selected");>5</option>
                                <option value=2 &LSetup(3,"%s",524,B,2,"selected");>10</option>
                                <option value=3 &LSetup(3,"%s",524,B,3,"selected");>15</option>
                                <option value=4 &LSetup(3,"%s",524,B,4,"selected");>20</option>
                                <option value=5 &LSetup(3,"%s",524,B,5,"selected");>25</option>
                                <option value=6 &LSetup(3,"%s",524,B,6,"selected");>30</option>
                                <option value=7 &LSetup(3,"%s",524,B,7,"selected");>35</option>
                                <option value=8 &LSetup(3,"%s",524,B,8,"selected");>40</option>
                                <option value=9 &LSetup(3,"%s",524,B,9,"selected");>45</option>
                                <option value=10 &LSetup(3,"%s",524,B,10,"selected");>50</option>
                                <option value=11 &LSetup(3,"%s",524,B,11,"selected");>55</option>
                                <option value=12 &LSetup(3,"%s",524,B,12,"selected");>60</option>
                                <option value=13 &LSetup(3,"%s",524,B,13,"selected");>65</option>
                                <option value=14 &LSetup(3,"%s",524,B,14,"selected");>70</option>
                                <option value=15 &LSetup(3,"%s",524,B,15,"selected");>75</option>
                                <option value=16 &LSetup(3,"%s",524,B,16,"selected");>80</option>
                                <option value=17 &LSetup(3,"%s",524,B,17,"selected");>85</option>
                                <option value=18 &LSetup(3,"%s",524,B,18,"selected");>90</option>
                                <option value=19 &LSetup(3,"%s",524,B,19,"selected");>95</option>
                                <option value=20 &LSetup(3,"%s",524,B,20,"selected");>100</option>
                        </select><font size=2> %                </td>
        </tr>
        <tr>
                <td><b><font size=2>Microphone gain</td>
                <td>
                        <select size=1 name=B559>
                                <option value=0 &LSetup(3,"%s",559,B,0,"selected");>21</option>
                                <option value=1 &LSetup(3,"%s",559,B,1,"selected");>22.5</option>
                                <option value=2 &LSetup(3,"%s",559,B,2,"selected");>24</option>
                                <option value=3 &LSetup(3,"%s",559,B,3,"selected");>25.5</option>
                                <option value=4 &LSetup(3,"%s",559,B,4,"selected");>27</option>
                                <option value=5 &LSetup(3,"%s",559,B,5,"selected");>28.5</option>
                                <option value=6 &LSetup(3,"%s",559,B,6,"selected");>30</option>
                                <option value=7 &LSetup(3,"%s",559,B,7,"selected");>31.5</option>
                                <option value=8 &LSetup(3,"%s",559,B,8,"selected");>33</option>
                                <option value=9 &LSetup(3,"%s",559,B,9,"selected");>34.5</option>
                                <option value=10 &LSetup(3,"%s",559,B,10,"selected");>36</option>
                                <option value=11 &LSetup(3,"%s",559,B,11,"selected");>37.5</option>
                                <option value=12 &LSetup(3,"%s",559,B,12,"selected");>39</option>
                                <option value=13 &LSetup(3,"%s",559,B,13,"selected");>40.5</option>
                                <option value=14 &LSetup(3,"%s",559,B,14,"selected");>42</option>
                                <option value=15 &LSetup(3,"%s",559,B,15,"selected");>43.5</option>
                        </select><font size=2> dB
                </td>
        </tr>
        <tr>
                <td><b><font size=2>A/D amplifier gain</td>
                <td>
                        <select size=1 name=B529>
                                <option value=0 &LSetup(3,"%s",529,B,0,"selected");>-3</option>
                                <option value=1 &LSetup(3,"%s",529,B,1,"selected");>-1.5</option>
                                <option value=2 &LSetup(3,"%s",529,B,2,"selected");>0</option>
                                <option value=3 &LSetup(3,"%s",529,B,3,"selected");>1.5</option>
                                <option value=4 &LSetup(3,"%s",529,B,4,"selected");>3</option>
                                <option value=5 &LSetup(3,"%s",529,B,5,"selected");>4.5</option>
                                <option value=6 &LSetup(3,"%s",529,B,6,"selected");>6</option>
                                <option value=7 &LSetup(3,"%s",529,B,7,"selected");>7.5</option>
                                <option value=8 &LSetup(3,"%s",529,B,8,"selected");>9</option>
                                <option value=9 &LSetup(3,"%s",529,B,9,"selected");>10.5</option>
                                <option value=10 &LSetup(3,"%s",529,B,10,"selected");>12</option>
                                <option value=11 &LSetup(3,"%s",529,B,11,"selected");>13.5</option>
                                <option value=12 &LSetup(3,"%s",529,B,12,"selected");>15</option>
                                <option value=13 &LSetup(3,"%s",529,B,13,"selected");>16.5</option>
                                <option value=14 &LSetup(3,"%s",529,B,14,"selected");>18</option>
                                <option value=15 &LSetup(3,"%s",529,B,15,"selected");>19.5</option>
                        </select><font size=2> dB
                </td>
        </tr>
        <tr>
                <th><font size=2><br>STREAMING</th><td></td>
        </tr>
        <tr>
                <td><font size=2><b>Streaming mode</td>
                <td><select size=1 name=B596>
          <option value=0 &LSetup(3,"%s",596,B,0,"selected");>send always</option>
          <option value=3 &LSetup(3,"%s",596,B,3,"selected");>send on level</option>
          <option value=1 &LSetup(3,"%s",596,B,1,"selected");>send on I0</option>
          <option value=2 &LSetup(3,"%s",596,B,2,"selected");>respond</option>
        </select></td>
        </tr>
        <tr>
                <td><b><font size=2>Input Trigger Level</td>
                <td><input name=W534 size=5 maxlength=5 value=&LSetup(1,"%u",534,W); onChange=PortCheck(this)><font size=2></td>
        </tr>
        <tr>
                <td><b><font size=2>Inactivity Timeout</td>
                <td><input name=W539 size=5 maxlength=5 value=&LSetup(1,"%u",539,W);><font size=2> msec</td>
        </tr>
        <tr>
                <td><font size=2><b>Connection protocol</td>
                <td><select size=1 name=B544>
          <option value=1 &LSetup(3,"%s",544,B,1,"selected");>Raw UDP</option>
          <option value=6 &LSetup(3,"%s",544,B,6,"selected");>RTP</option>
        </select></td>
        </tr>

        <tr>
                <td><b><font size=2>Destination IP</td>
                <td><b><font size=2><input name=B560 size=3 maxlength=3 value=&LSetup(1,"%u",560); onChange=IPCheck(this)> . <input name=B561 size=3 maxlength=3 value=&LSetup(1,"%u",561); onChange=IPCheck(this)> . <input name=B562 size=3 maxlength=3 value=&LSetup(1,"%u",562); onChange=IPCheck(this)> . <input name=B563 size=3 maxlength=3 value=&LSetup(1,"%u",563); onChange=IPCheck(this)></td>
        </tr>
        <tr>
                <td><b><font size=2>Destination Port</td>
                <td><b><font size=2><input name=W569 size=5 maxlength=5 value=&LSetup(1,"%u",569,W);></td>
        </tr>
        <tr>
                <td><b><font size=2>Receive Port</td>
                <td><input name=W574 size=5 maxlength=5 value=&LSetup(1,"%u",574,W); onChange=PortCheck(this)></td>
        </tr>
        <tr>
                <td><b><font size=2>Own Name</td>
                <td><input name=S500 size=20 maxlength=20 value="&LSetup(4,"%s",500);"></td>
        </tr>
        <tr>
                <td><br><input type=submit value=" Apply "> <input type=reset value=" Cancel "></td>
                <td>&nbsp;</td>
        </tr>
        </form>
</table>
</body>
</html>
HTTP/1.0 200
Content-type: text/html

<html>
<body bgcolor=#CCCCCC>
<font size=2 face="Arial, Helvetica, sans-serif">
<span lang="en-us">
<b>Help</b><br><br>
To store changed settings click on "Apply" at the bottom of the page.<br>
The device will restart with the new setting.<br><br>
<b>Input source</b><br>
Choose the desired input source.<br>
On Detect Source the device chooses, during start up, the input with the highest audio level.<br>
Default setting is <em>"Mic"</em>.<br><br>
<b>Encoding</b><br>
Choose between different encoding types and sampling frequencies
(<em>"uLaw"</em>, <em>"aLaw"</em>, <em>"PCM MSB"</em> or <em>"PCM LSB"</em> at 8 or 24 kHz).<br>
Default setting is <em>"uLaw 24 kHz"</em>.<br><br>
<b>Volume</b><br>
Choose between <em>"0"</em>% and <em>"100"</em>% in 5% steps.<br>
Default: <em>"50"</em>%<br><br>
<b>Streaming mode</b><br>
<em>"send always"</em> will stream always<br>
<em>"send on level"</em> will stream if the input audio level goes above the configured <em>"Input Trigger Level"</em><br>
<em>"send on I0 "</em> will stream if the input I0 button is pressed<br>
<em>"respond"</em> will stream back as long as a stream is being received<br>
Default setting is <em>"send always"</em>.<br>
<b>NB! </b> The I1 button can be used as RING request to remote side (to UDP port 3040).
Your unit (to UDP port 12301) will also accept the commands FORCE ON (c=91),
FORCE OFF (c=84), DOOR ON (c=78), DOOR OFF (c=79), pulse OPEN DOOR for 3 sec (c=80), RTS ON (c=60) and RTS OFF (c=61) from current connected remote side.<br><br>
<b>Input Trigger Level</b><br>
Triggering input audio level if <em>"send on level"</em> mode is selected. Accepted range: 0-32767<br>
Default: <em>"1000"</em><br><br>
<b>Inactivity Timeout</b><br>
<em>"Send on level"</em> streaming stops after this number of milliseconds of no input audio signal.<br>
Default: <em>"1000ms"</em><br><br>
<b>Connection protocol</b><br>
<em>"Raw UDP"</em> will stream by using raw UDP protocol<br>
<em>"RTP"</em> will stream by using RTP protocol<br>
Default setting is <em>"Raw UDP"</em>.<br><br>
<b>Destination IP</b><br>
Enter 4 values of the IP address of the receiving unit.<br>
If no Destination Port is used then this IP address is for addressing the ring command to ICgraph only.<br><br>
<b>Destination Port</b><br>
Enter the port number of the receiving unit.<br>
<b>NB! </b> If 0, your unit will send "to origin source" by using Encoding (Payload Type for RTP), Protocol, and IP:Port of the latest received packet<br><br>
<b>Receive Port</b><br>
Enter the port number for receiving a stream.<br>
<!--Set to a value between 0 (disabled) and 65535.<br> -->
Default port  is <em>"3030"</em>.<br><br>
<b>Own Name</b><br>
This Name is necessary only with using dynamic IP in order to recognize this unit by broadcast DISCOVER request.<br><br>

</body></html>
0  BCL file not exisiting or invalid tokencode version (use correct tokenizer version)
1  PRINT was not last statement in line or wrong delimiter used (allowed ',' or ';')
2  Wrong logical operator in IF statement (allowed '=','>','>=','<','<=','<>')
3  ONLY String VARIABLE can be used as parameter in OPEN,READ,MIDxxx,EXEC
4  Wrong delimiter/parameter is used in list of parameters for this statement/function
5  ON statement must be followed by GOTO/GOSUB statement
6  First parameter of TIMER statement must be 1..4 (# for ON TIMER# GOSUB...)
7  Wrong element is used in this string/numeric expression, maybe a type mismatch
8  Divided by Zero
9  Wrong label is used in GOTO/GOSUB statement (allowed only a numeric constant)
10 Wrong symbol is used in source code, syntax error, tokenization is impossible
11 Wrong size of string/array is used in DIM (allowed only a numeric constant)
12 Wrong type in DIM statement used (only string variable or long variable/array allowed)
13 DIM was not last statement in line or wrong delimiter used (allowed only ',')
14 Missing bracket in expression or missing quote in string constant
15 Maximum nesting of calculations exceeded (too many brackets)
16 Assignment assumed (missing equal sign)
17 Wrong size of external tokenized TOK file (file might be corrupt)
18 Too many labels needed, tokenization is impossible
19 Identical labels in source code found, tokenization is impossible
20 Undefined label in GOTO/GOSUB statement found, tokenization is impossible
21 Missing THEN in IF/THEN statement
22 Missing TO in FOR/TO statement
23 Run-time warning: Possibly, maximum nesting of FOR-NEXT loops exceeded
24 NEXT statement without FOR statement or wrong index variable in NEXT statement
25 Maximum nesting of GOSUB-RETURN calls exceeded
26 RETURN statement without proper GOSUB statement
27 Lack of memory for dynamic memory allocation
28 String variable name conflict or too many string variables used
29 Long variable name conflict or too many long variables used
30 Insufficient space in memory for temp string, variable or program allocation
31 Current Array index bigger then maximal defined index in DIM statement
32 Wrong current number of file/stream handler (allowed only 0..4)
33 Wrong file/stream type/type name or file/stream is already closed
34 This file/stream handler is already used or file/stream already opened
35 Missing AS statement in OPEN AS statement
36 Wrong address in IOCTL or IOSTATE
37 Wrong serial port number in OPEN statement
38 Wrong baudrate parameter for serial port in OPEN statement
39 Wrong parity parameter for serial port in OPEN statement
40 Wrong data bits parameter for serial port in OPEN statement
41 Wrong stop bits parameter for serial port in OPEN statement
42 Wrong serial port type parameter in OPEN statement
43 Run-time warning: You lost data during PLAY -- Please, increase string size
44 For TCP/CIFS file/stream only handler with number 0..5 are allowed
45 Only standard size (256 bytes) string variable allowed for READ and WRITE in STP file
46 Wrong or out of string range parameters in MID$ or MIDxxx
47 Only one STP/F_C file can be opened at a time
48 '&' can be used ONLY at the end of a line
49 Syntax error in multiline IF...ENDIF (maybe wrong nesting)
50 Length of Search Tag must not exceed size of target String Variable for READ
51 DIM string/array variable name already used
52 Wrong user function name or array declaration missing
53 General syntax error: wrong or not allowed delimiter or statement at this position
54 Run-time warning: Lost data during UDP READ -- Please, increase string size
55 Run-time warning: Lost data during UDP receiving -- 1k buffer limit
56 Run-time warning: Impossible to allocate 6 TCP handles, if 6 are needed free up TCP command port and/or serial local ports
57 Run-time warning: Lost data during concatenation of strings -- Please, increase target string size (DIM statement)
58 Run-time warning: Lost data during assignment of string -- Please, increase target string size (DIM statement)
59 Indicated flash page (WEBx) is out of range for this HW
60 COB file (F_C type) exceeds 64k limit
61 Token size too long
62 Unrecognized token type
txt text/plain
text text/plain
xsl text/xml
xml text/xml
html text/html
htm text/html
shtml text/html
plg text/html
bmp image/bmp
dib image/bmp
gif image/gif
jpeg image/jpeg
jpg image/jpeg
jpe image/jpeg
jfif image/jpeg
pjpeg image/jpeg
pjp image/jpeg
tif image/tiff
tiff image/tiff
hta application/hta
js application/x-javascript
mocha application/x-javascript
class application/octet-stream
zip application/zip
rmi audio/mid
mid audio/mid
mp3 audio/mpeg
mp2 audio/x-mpeg
mpa audio/x-mpeg
abs audio/x-mpeg
mpega audio/x-mpeg
