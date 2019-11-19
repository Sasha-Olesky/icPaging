function PortCheck(I){
  d =parseInt(I.value, 10);
  if ( !( d<65536 && d>=1) ) {
    alert('Port value is out of range [1 - 65535]');
    I.value = I.defaultValue;
  }
}

function IPCheck(I){
  d =parseInt(I.value, 10);
  if ( !(d<256 && d>=0) ) {
    alert('IP value is out of range [0 - 255]');
    I.value = I.defaultValue;
  }
}

function IP0to254(I){
  d =parseInt(I.value, 10);
  if ( !(d<255 && d>=0) ) {
    alert('IP value is out of range [0 - 254]');
    I.value = I.defaultValue;
  }
}

function IP1to254(I){
  d =parseInt(I.value, 10);
  if ( !(d<255 && d>0) ) {
    alert('IP value is out of range [1 - 254]');
    I.value = I.defaultValue;
  }
}

function CheckMetric(I){
  d =parseInt(I.value, 10);
  if ( !(d<16 && d>=0) ) {
    alert('Hop count value is out of range [0 - 15]');
    I.value = I.defaultValue;
  }
}

function netMaskCheck(I,last){
	d =parseInt(I.value, 10);
	if( !(d==0 || d==128 || d==192 || d==224 || d==240 || d==248 || d==252 || d==254 || (!last && d==255) )) {
		alert('Incorrect netmask value');
		I.value = I.defaultValue;
	}
}

function Go(x) {
   parent.frames[3].location.href = x;
   document.forms[0].reset();
   document.forms[0].elements[0].blur();
}


function serial_check(){
	f=document.forms["settings"];
        x=(f.B199.selectedIndex!=0);	/* VSC or RTC */
	f.B81.disabled=x;
	f["B80b2-3"].disabled=x;
	f["B80b4-5"].disabled=x;
	f["B80b6-7"].disabled=x;
	f.B82.disabled=x;
}

function translate_hw_type(element)
{
	var hw_list = [];

	hw_list["1"] = "Legacy 1";
	hw_list["2"] = "Legacy 2";
	hw_list["3"] = "Legacy 3";
	hw_list["4"] = "Legacy 4";
	hw_list["5"] = "Legacy 5";
	hw_list["6"] = "Legacy 6";
	hw_list["7"] = "Annuncicom 100";
	hw_list["8"] = "Instreamer 100";
	hw_list["9"] = "Exstreamer Digital";
	hw_list["13"] = "IPAM 100";
	hw_list["14"] = "Exstreamer 100";
	hw_list["15"] = "Exstreamer 200";
	hw_list["16"] = "IPAM Evaluation kit";
	hw_list["17"] = "Annuncicom 1000";
	hw_list["18"] = "Bosch IP Audio";
	hw_list["19"] = "Annuncicom 200";
	hw_list["20"] = "Exstreamer 110";
	hw_list["21"] = "Exstreamer 1000";
	hw_list["22"] = "Barionet 200";
	hw_list["25"] = "Annuncicom PS16";
	hw_list["26"] = "Barionet 50";
	hw_list["32"] = "Annuncicom 155";
	hw_list["33"] = "Annuncicom VME";
	hw_list["34"] = "Exstreamer 120";
	hw_list["35"] = "Exstreamer 500";
	hw_list["36"] = "Exstreamer P5";
	hw_list["37"] = "Exstreamer 105";
	hw_list["38"] = "Exstreamer 205";
	hw_list["39"] = "IPAM 101";
	hw_list["40"] = "IPAM 102";
	hw_list["41"] = "Annuncicom 50";
	hw_list["42"] = "Annuncicom PS1";
	hw_list["44"] = "Annuncicom 50 OEM";
	hw_list["45"] = "IPAM 301";
	hw_list["46"] = "IPAM 302";
	hw_list["93"] = "Barionet";


	e=document.getElementById(element);
	num=e.innerHTML;
	text = hw_list[num];

	if (text!="") e.innerHTML=text;
	else e.innerHTML=num;

	if (e.style.display=="none")	e.style.display="inline";
}



function translate_ipam_type(element)
{
	var ipam_list = [];

	ipam_list["0"] = "generic";
	ipam_list["1"] = "IPAM 101";
	ipam_list["2"] = "IPAM 102";
	ipam_list["3"] = "IPAM 301";
	ipam_list["4"] = "IPAM 302";


	e=document.getElementById(element);
	num=e.innerHTML;
	text = ipam_list[num];

	if (text!="") e.innerHTML=text;
	else e.innerHTML=num;

	if (e.style.display=="none")	e.style.display="inline";
}


