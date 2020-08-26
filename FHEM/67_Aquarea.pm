##############################################
# $Id: 67_Aquarea.pm 2017-11-05
# Modul zum belauschen der Kommunikation Kabelfernbedienung >> Panasonic WH-MDC05F3E5 W�rmepumpe
# Vorraussetzung: Baudrate eines ELV RS232-USB Wandlers UM2102 �ndern auf 960 Baud, um den Datenbus einer
# Panasonic W�rmepumpe WH-MDC05F3E5 (Geisha) zu belauschen.
# initialisiert wird die Schnittstelle dann mit /dev/ttyUSBx@1200,8,E,1 wobei die angegebenen 1200 Baud
# in Wirklichkeit 960 Baud sind

package main;

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);

sub Aquarea_Read($);
sub Aquarea_Ready($);

my $state;
my $aktueller_fehler;
my $modus_text;
my $modus;
my $temp_r;
my $temp_v;
my $temp_a;
my $temp_s;
my $state_temp;

sub
Aquarea_Initialize($)
{
  my ($hash) = @_;

  require "$attr{global}{modpath}/FHEM/DevIo.pm";

  $hash->{ReadFn}  = "Aquarea_Read";
  $hash->{ReadyFn} = "Aquarea_Ready";
  $hash->{DefFn}   = "Aquarea_Define";
  $hash->{SetFn}   = "Aquarea_Set";
  $hash->{UndefFn} = "Aquarea_Undef";
  $hash->{AttrList}= $readingFnAttributes;
}

#####################################
sub Aquarea_Set($$@)
{
    my ($hash, $name, $cmd,$value) = @_;

    my $usage =	"Sollwertverschiebung ".
		"Modus:heizen,kuehlen,Speicher,Stby,Auto,heizenUNDSpeicher,kuehlenUNDSpeicher,aus ".
		"Speicher:slider,40,1,65 ".
		"Error:reset ".
		"Quiet:ein,aus ".
		"Sync ".
		"ein ".
		"aus ";

    if($cmd eq "Sollwertverschiebung")
    {

 	Log3 $name, 3, "Aquarea: Set Sollwertverschiebung $value";
    	if ($value<0)
	{
		$value=256+$value;
	}
	$hash->{w_value}=$value;
	$hash->{w_register}=138;
	$hash->{w_write}=1;
	return (undef,1);
    }
    elsif($cmd eq "Modus")
    {

			Log3 $name, 3, "Aquarea: Set Modus $value";
      if ($value eq "Stby")	                {$value=1;}
      if ($value eq "heizen")	              	{$value=3;}
      if ($value eq "kuehlen")            	{$value=5;}
      if ($value eq "Speicher")	                {$value=17;}
      if ($value eq "heizenUNDSpeicher")      	{$value=19;}
      if ($value eq "kuehlenUNDSpeicher")   	{$value=21;}
      if ($value eq "Auto")	                {$value=33;}
			$hash->{w_value}=$value;
			$hash->{w_register}=144;
			$hash->{w_write}=1;
			return (undef,1);
    }
    elsif($cmd eq "Speicher")
    {

 			Log3 $name, 3, "Aquarea: Set Speicher $value $name";
			$hash->{w_value}=$value;
			$hash->{w_register}=137;
			$hash->{w_write}=1;
			return (undef,1);
    }
    elsif($cmd eq "ein")
    {
			if ($modus & 1) {
			# ist breits auf ein
			} else {
			$value=$modus+1;
			Log3 $name, 3, "Aquarea: Set Modus $value";
			$hash->{w_value}=$value;
			$hash->{w_register}=144;
			$hash->{w_write}=1;
			return (undef,1);
			}
    }
    elsif($cmd eq "aus")
    {
			if ($modus & 1) {
				if ($modus==1) {
					$value=2;
				} else {
					$value=$modus-1;
				}
			Log3 $name, 3, "Aquarea: Set Modus $value";
			$hash->{w_value}=$value;
			$hash->{w_register}=144;
			$hash->{w_write}=1;
			return (undef,1);
			} else {
			# ist breits auf aus
			}
    }
    elsif($cmd eq "Quiet")
    {
			if ($value eq "ein") {
				if ($modus < 64) {
					$value=$modus+64;
				} else {
				# Quiet ist bereits auf ein.
				}
			}
			if ($value eq "aus") {
				if ($modus > 64) {
					$value=$modus-64;
				} else {
				# Quiet ist bereits auf aus.
				}
			}
			Log3 $name, 3, "Aquarea: Set Modus $value";
			$hash->{w_value}=$value;
			$hash->{w_register}=144;
			$hash->{w_write}=1;
			return (undef,1);
    }
    elsif($cmd eq "Error")
    {

			Log3 $name, 3, "Aquarea: Set Error $value";
      if ($value eq "reset")	  {$value=2;}
			$hash->{w_value}=$value;
			$hash->{w_register}=129;
			$hash->{w_write}=1;
			return (undef,1);
    }
    elsif($cmd eq "Sync")
    {
     # kommt noch
			# Sync KFB liest Daten ein, ohne einen Kommunikationsfehler zu erzeugen
		#	$hash->{w_sync}=1;
			Log3 $name, 3, "Aquarea: Sync";
			return (undef,1);
    }
    elsif($cmd eq "dummy")
    {

 			Log3 $name, 3, "Aquarea: Set dummy";
			return (undef);
    }
    else
    {
       return ($usage);

    }
}

sub
Aquarea_Define($$)
{


  my ($hash, $def) = @_;
  my @a = split("[ \t]+", $def);

  my $name = $a[0];
  my $protocol = $a[2];
  my $devicename= $a[3];

  $hash->{NAME}=$name;
  $hash->{Protocol}= $protocol;
  $hash->{DeviceName} = $devicename;
	$hash->{helper}{start}=0;
	$hash->{Typ_Name} = "Panasonic WH-MDC05F3E5";

	Log3 $name, 3, "test: $name  $protocol  $devicename";

	Log3 undef, 2, "0=".$a[0];  # test
	Log3 undef, 2, "1=".$a[1];  # Aquarea
	Log3 undef, 2, "2=".$a[2];  # serial
	Log3 undef, 2, "3=".$a[3];  # /dev/ttyUSB0@1200



  if(@a < 4 || @a > 4 || ($protocol ne "serial"))
	{
    my $msg = "wrong syntax: define <name> Aquarea serial <devicename[\@baudrate]>";
    Log 2, $msg;
    return $msg;
  }

  DevIo_CloseDev($hash);
  my $ret = DevIo_OpenDev($hash, 0, undef);
  $hash->{can_dtrdsr} = $hash->{USBDev}->can_dtrdsr();
  $hash->{can_rtscts} = $hash->{USBDev}->can_rtscts();
  return $ret;
}

#####################################
sub
Aquarea_Undef($$)
{
  my ($hash, $arg) = @_;
  my $name = $hash->{NAME};
	Log3 $name, 3, "Aquarea_close";
  DevIo_CloseDev($hash);
  return undef;
}


#####################################
 sub
 Aquarea_Reopen($)
{

  my ($hash) = @_;
  my $name = $hash->{NAME};
	Log3 $name, 3, "Aquarea_reopen";
  DevIo_CloseDev($hash);
  DevIo_OpenDev($hash, 0, undef);
  $hash->{can_dtrdsr} = $hash->{USBDev}->can_dtrdsr();
  $hash->{can_rtscts} = $hash->{USBDev}->can_rtscts();
}


sub
Aq_readingsSingleUpdate($$$$)
# hilft etwas die Datenflut im Griff zu behalten
{
   my ($hash,$reading , $value, $do_trigger) = @_;
  my $name = $hash->{NAME};
#  Log3 $name, 3, "Aq $hash  $reading  $value  $do_trigger";
	my $sek=ReadingsAge($name,$reading, "300");
	my $old_value = ReadingsVal($name, $reading, "0");
#  Log3 $name, 3, "sek 16 $sek  $hash";
	if (($sek>180) || ($old_value ne $value))
	{
		readingsSingleUpdate($hash,$reading,$value,$do_trigger);
	}
}


#####################################
# called from the global loop
sub
Aquarea_Read($)

{
  my ($hash) = @_;
  my $name = $hash->{NAME};
  my $fd=$hash->{FD};
  my $buf = DevIo_SimpleRead($hash);
  return "" if(!defined($buf));

  my $Aquareadata = $hash->{PARTIAL};
  $Aquareadata .= $buf;
  $hash->{PARTIAL} = $Aquareadata;
  return "" if((length($Aquareadata))<8);
	my $position=index($Aquareadata,chr(170),0);
	$Aquareadata=(substr($Aquareadata,$position,(length($Aquareadata))-$position));
  return "" if((length($Aquareadata))<8);

	my $msg;
	$msg=substr($Aquareadata,0,8,'');
	my @array = split("", $msg);

	 if ((ord($array[1]))==27 && $hash->{w_sync}==1)
	 {
	    my $setrts = $hash->{USBDev}->rts_active(0); # rts fur auf high
			select(undef, undef, undef, 1.950);	#
	    $setrts = $hash->{USBDev}->rts_active(1); # rts auf low
			$hash->{w_sync}=0;
	 }

	 #Log3 $name, 3, "Aquarea: Debug: array[1]:".(ord($array[1]))." w_write:".$hash->{w_write}." w_value:".$hash->{w_value};

	 if ((ord($array[1]))==17 && $hash->{w_write}==1) # 18 wird ausgeblendet und stattdessen der Befehl gesendet
	 {
			#Log3 $name, 3, "Aquarea: Debug: w_value:".$hash->{w_value}." w_register:".$hash->{w_register};

			my $data;
			my $data_0=170;
			my $data_1=$hash->{w_register};
			my $data_2=$hash->{w_value};
			my $data_3=($data_0+$data_1+$data_2)&255;
			Log3 $name, 3, "Aquarea: schreiben Adresse:".$data_0." Register:".$data_1." Value:".$data_2." CRC:".$data_3;

			$data = pack("C*",$data_0,$data_1,$data_2,$data_3);


			select(undef, undef, undef, 0.035);	# 35ms warten, damit der gesendete Befehl da kommt, wo sonst der FB-Befehl k�me
	    my $setrts = $hash->{USBDev}->rts_active(0); # rts fur auf high
			select(undef, undef, undef, 0.010);	# 10ms warten
		 	DevIo_SimpleWrite($hash,$data,0);	# Daten schreiben
			select(undef, undef, undef, 0.060);	# 60ms warten
	    $setrts = $hash->{USBDev}->rts_active(1); # rts auf low

	 }

	my @dec    = map { ord($_) } @array;
  Log3 $name, 5, "SERDevice-Message-dec @dec";


  if($dec[1] != $dec[5]) # wenn die beiden Register von Anfrage und Antwort nicht �bereinstimmen return
		{
    	$hash->{PARTIAL} = "";
			return "";
		}
		my $ergebnis;
  	my $crc_85 =($dec[4]+$dec[5]+$dec[6])&255;
  	my $crc_170=($dec[0]+$dec[1]+$dec[2])&255; # ok
		if (($crc_170==$dec[3]) && ($crc_85==$dec[7])) # CRC OK
		{
			$ergebnis=$dec[6];
#####################################################################################
			if ($hash->{w_write}==1)	# etwas in WP geschrieben
			{
				if ((ord($array[1]))==$hash->{w_register})     # pr�fe ob aktuelles register auch das w_register ist
				{
					if ($ergebnis==$hash->{w_value})	# ist der geschriebene Wert=Quittung von WP
					{
 						$hash->{w_write}=0;
 						$hash->{w_time}=FmtDateTime(time);
						Log3 $name, 3, "Aquarea: geschrieben Adresse:".$dec[0]." Register:".$dec[1]." Value:".$dec[2]." CRC:".$dec[3];
					}
				}

			}
#####################################################################################


			if (($dec[1] => 0) && ($dec[1] < 16))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}

			if ($dec[1]==16)	# ???
			{
#				Aq_readingsSingleUpdate($hash,"16",$ergebnis, 1);
    	}
			if ($dec[1]==17)	# beim abtauen=64
			{
#      	Aq_readingsSingleUpdate($hash,"17",$ergebnis, 1);
				if ($dec[6] & 64)
				{
					$ergebnis="1";
					Aq_readingsSingleUpdate($hash,"abtauen aktiv",$ergebnis, 1);
				}
				else
				{
					$ergebnis="0";
					Aq_readingsSingleUpdate($hash,"abtauen aktiv",$ergebnis, 1);
				}
    	}
			if ($dec[1]==18)	# Aussentemperatur
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
	$temp_a=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Temperatur aussen",$ergebnis, 1);
    	}
			if ($dec[1]==19)	# Vorlauftemperatur
			{
	$temp_v=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Temperatur Vorlauf",$ergebnis, 1);
    	}
			if ($dec[1]==20)	# aktueller Fehler, geht wieder auf 0 wenn fehler behoben dez 38=Fehler H72(Speichertemperaturf�hler)
			{
				if ($dec[6] == 0) {$aktueller_fehler="";}
				if ($dec[6] == 38) {$aktueller_fehler="H72(Speichertemperaturf�hler)";}
				if ($dec[6] == 156) {$aktueller_fehler="H76(Kommunikationsfehler der Fernbedienung)";}
      	Aq_readingsSingleUpdate($hash,"aktueller Fehler",$aktueller_fehler, 1);
    	}
			if ($dec[1]==21)	# R�cklauftemperatur
			{
	$temp_r=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Temperatur Ruecklauf",$ergebnis, 1);
    	}
			if ($dec[1]==22)	# Speichertemperatur
			{
	$temp_s=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Temperatur Speicher",$ergebnis, 1);
    	}
			if ($dec[1]==23)	# Kompressorfrequenz
			{
      	Aq_readingsSingleUpdate($hash,"Kompressorfrequenz",$ergebnis, 1);
    	}
			if ($dec[1]==24)	# aktueller Fehler, geht wieder auf 0 wenn fehler behoben dez 38=Fehler H72(Speichertemperaturf�hler)
			{
				if ($dec[6] == 38) {$ergebnis="H72(Speichertemperaturf�hler)";}
				if ($dec[6] == 156) {$ergebnis="H76(Kommunikationsfehler der Fernbedienung)";}
      	Aq_readingsSingleUpdate($hash,"letzter Fehler",$ergebnis, 1);
    	}
			if ($dec[1]==25)	# ???
			{
#      	Aq_readingsSingleUpdate($hash,"25",$ergebnis, 1);
    	}
			if ($dec[1]==26)	# ???
			{
#      	Aq_readingsSingleUpdate($hash,"26",$ergebnis, 1);
    	}
			if ($dec[1]==27)	# 		Bit 0 ein/stby ???? Bit 1	gesetzt=heizen  Bit 2		Bit 3  Bit 4	gesetzt=Speicher(Puffer)  Bit 5  Bit 6	gesetzt=Quiet	Bit 7
			{
	$modus=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Modus",$ergebnis, 1);
				if ($dec[6] & 1) {$modus_text="ein |";
					if ($dec[6] & 2) {$modus_text=$modus_text." heizen";Aq_readingsSingleUpdate($hash,"Modus heizen aktiv","1", 1);}
					else {Aq_readingsSingleUpdate($hash,"Modus heizen aktiv","0", 1);}
					if ($dec[6] & 4) {$modus_text=$modus_text." kuehlen";Aq_readingsSingleUpdate($hash,"Modus kuehlen aktiv","1", 1);}
					else {Aq_readingsSingleUpdate($hash,"Modus kuehlen aktiv","0", 1);}
					if ($dec[6] & 16) {$modus_text=$modus_text." Speicher";Aq_readingsSingleUpdate($hash,"Modus Speicher aktiv","1", 1);}
					else {Aq_readingsSingleUpdate($hash,"Modus Speicher aktiv","0", 1);}
					if ($dec[6] & 32) {$modus_text=$modus_text." Auto";}
					if ($dec[6] & 64) {$modus_text=$modus_text." Quiet";}
				}
				else {$modus_text="aus";Aq_readingsSingleUpdate($hash,"Modus Speicher aktiv","0", 1);Aq_readingsSingleUpdate($hash,"Modus heizen aktiv","0", 1);Aq_readingsSingleUpdate($hash,"Modus kuehlen aktiv","0", 1);}
				if ($dec[6] == 1) {$modus_text="stby";Aq_readingsSingleUpdate($hash,"Modus Speicher aktiv","0", 1);Aq_readingsSingleUpdate($hash,"Modus heizen aktiv","0", 1);Aq_readingsSingleUpdate($hash,"Modus kuehlen aktiv","0", 1);}
      	Aq_readingsSingleUpdate($hash,"Modus Klartext",$modus_text, 1);
				if ($dec[6] & 1) {$ergebnis="ein";}
				else {$ergebnis="aus";}
      	Aq_readingsSingleUpdate($hash,"Betriebszustand",$ergebnis, 1);
    	}
			if ($dec[1]==28)	# ???
			{
#      	Aq_readingsSingleUpdate($hash,"28",$ergebnis, 1);
    	}
			if ($dec[1]==29)	# lowByte Energie heizen
			{
				$hash->{helper}{29}=$dec[6];
      	# readingsSingleUpdate($hash,"29",$dec[6], 1);
    	}
			if ($dec[1]==30)	# highByte Energie heizen
			{
      	# readingsSingleUpdate($hash,"30",$dec[6], 1);
      	Aq_readingsSingleUpdate($hash,"Energie heizen in W",(($dec[6]*256)+$hash->{helper}{29}), 1);
			if ((($dec[6]*256)+$hash->{helper}{29}) > 0)
			{
			Aq_readingsSingleUpdate($hash,"Ventilstellung","heizen", 1);
			}
	}
			if ($dec[1]==31)	# ??? lowByte Energie k�hlen ???
			{
      	# Aq_readingsSingleUpdate($hash,"31",$ergebnis, 1);
				$hash->{helper}{31}=$dec[6];
    	}
			if ($dec[1]==32)	# ??? highByte Energie k�hlen ???
			{
      	# Aq_readingsSingleUpdate($hash,"32",$ergebnis, 1);
      	Aq_readingsSingleUpdate($hash,"Energie kuehlen in W",(($dec[6]*256)+$hash->{helper}{31}), 1);
			if ((($dec[6]*256)+$hash->{helper}{31}) > 0)
			{
			Aq_readingsSingleUpdate($hash,"Ventilstellung","kuehlen", 1);
			}
    	}
			if ($dec[1]==33)	# lowByte Puffer heizen
			{
				$hash->{helper}{33}=$dec[6];
      	# readingsSingleUpdate($hash,"29",$dec[6], 1);
    	}
			if ($dec[1]==34)	# highByte Puffer heizen
			{
      	Aq_readingsSingleUpdate($hash,"Energie Speicher in W",(($dec[6]*256)+$hash->{helper}{33}), 1);
			if ((($dec[6]*256)+$hash->{helper}{33}) > 0)
			{
			Aq_readingsSingleUpdate($hash,"Ventilstellung","Speicher", 1);
			}
    	}
			if ($dec[1]==35)	# Pumpenstufe Pumpe Geschwindigkeitsstufe dez 16=Stufe 1, dez 64=Stufe 4
			{
				$ergebnis=$ergebnis*0.0625;
      	Aq_readingsSingleUpdate($hash,"Pumpengeschwindigkeitsstufe",$ergebnis, 1);
    	}
			if ($dec[1]==36)	# ???
			{
#      	Aq_readingsSingleUpdate($hash,"36",$ergebnis, 1);
    	}

			if (($dec[1] > 36) && ($dec[1] < 129))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}
			if ($dec[1]==129)	# Reset Error (Taste an der Fernbedienung wurde gedr�ckt)
			{
#      	Aq_readingsSingleUpdate($hash,"Reset Error Taste gedr�ckt",$ergebnis, 1);
    	}
			if ($dec[1]==130)	# Einstellen der niedrigen Au�entemperatur  -15 bis +15
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heat_On_Out_Lo",$ergebnis, 1);
    	}
			if ($dec[1]==131)	# Einstellen der hohen Au�entemperatur  -15 bis +15
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heat_On_Out_Hi",$ergebnis, 1);
    	}
			if ($dec[1]==132)	# Einstellen der Wasseraustrittstemperatur bei niedriger Au�entemperatur   25 bis 55
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heat_On_H20_Lo",$ergebnis, 1);
    	}
			if ($dec[1]==133)	# Einstellen der Wasseraustrittstemperatur bei hoher Au�entemperatur      25 bis 55
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heat_On_H20_Hi",$ergebnis, 1);
    	}
			if ($dec[1]==134)	# Einstellen der Au�entemperatur, bei der der Heizbetrieb in der Heizbetriebsart abgeschaltet wird   5 bis 35
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heat_Off_Set",$ergebnis, 1);
    	}
			if ($dec[1]==135)	# Einsteller der Au�entemperatur, bei der die Elektrozusatzheizung eingeschaltet wird
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Heater_On_Out_Set",$ergebnis, 1);
    	}
			if ($dec[1]==136)	# ???  Cool Set ???
			{
  			# Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
				Aq_readingsSingleUpdate($hash,"Kuehlung Solltemperatur",$ergebnis, 1);
    	}
			if ($dec[1]==137)	# Hei�wasserspeichertemperatur  40 bis 75
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Speicher Solltemperatur",$ergebnis, 1);
    	}
			if ($dec[1]==138)	# Sollwertverschiebung -5 bis +5
			{
				if ($dec[6] & 128) {$ergebnis=$ergebnis-256;}
      	Aq_readingsSingleUpdate($hash,"Sollwertverschiebung",$ergebnis, 1);
    	}

			if ($dec[1]==141)	#
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==142)	#
			{
#     	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==143)	#
			{
#    	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==144)	#
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==145)	#
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==146)	#
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==147)	#
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}



			if ($dec[1]==177)	#
			{
      	Aq_readingsSingleUpdate($hash,"Kuehlen aktiviert",$ergebnis, 1);
    	}


			if ($dec[1]==192)	#
			{

				if ($dec[6] & 1) {Aq_readingsSingleUpdate($hash,"externes Raumthermostat","ja", 1);} else {Aq_readingsSingleUpdate($hash,"externes Raumthermostat","nein", 1);}
				if ($dec[6] & 2) {Aq_readingsSingleUpdate($hash,"Speicher vorhanden","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Speicher vorhanden","nein", 1);}
				if ($dec[6] & 4) {Aq_readingsSingleUpdate($hash,"Solar Vorrang","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Solar Vorrang","nein", 1);}
				if ($dec[6] & 16) {Aq_readingsSingleUpdate($hash,"Entkeimung","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Entkeimung","nein", 1);}
				if ($dec[6] & 32) {Aq_readingsSingleUpdate($hash,"Zusatzheizung","B", 1);} else {Aq_readingsSingleUpdate($hash,"Zusatzheizung","A", 1);}
				# if ($dec[6] & 64) {$ergebnis=$ergebnis." Quiet";}
				if ($dec[6] & 128) {Aq_readingsSingleUpdate($hash,"Wasserschutzfunktion","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Wasserschutzfunktion","nein", 1);}
      	# Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==193)	# Aufheizdauer Cool/Heat $dec[6] ist die Zeit in 30 min Schritten  2=60min, 1=30 min, 20=10h
			{
				$ergebnis=$ergebnis*30;
      	Aq_readingsSingleUpdate($hash,"Aufheizdauer kuehlen+heizen",$ergebnis." min", 1);
    	}
			if ($dec[1]==194)	# 194-Aufheizdauer_WW_Speicher_int 5=5min, 30=30min, 95=95min
			{
				$ergebnis=$ergebnis;
      	Aq_readingsSingleUpdate($hash,"Aufheizdauer Speicher int",$ergebnis." min", 1);
    	}
			if ($dec[1]==195)	# Sollwertverschiebung -5 bis +5
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==196)	# 196-Entkeimungstemperatur
			{
      	Aq_readingsSingleUpdate($hash,"Entkeimungstemperatur",$dec[6], 1);
				# Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==197)	# 197-Entkeimungsdauer"
			{
				Aq_readingsSingleUpdate($hash,"Entkeimungsdauer",$dec[6]." min", 1);
      	# Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==198)	# Sollwertverschiebung -5 bis +5
			{
				if ($dec[6] & 4) {Aq_readingsSingleUpdate($hash,"Booster Funktion","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Booster Funktion","nein", 1);}
				if ($dec[6] & 8) {Aq_readingsSingleUpdate($hash,"Zusatzgehaeuseheizung","ja", 1);} else {Aq_readingsSingleUpdate($hash,"Zusatzgehaeuseheizung","nein", 1);}

       #	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==199)	# Sollwertverschiebung -5 bis +5
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}
			if ($dec[1]==200)	# Sollwertverschiebung -5 bis +5
			{
#      	Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
    	}


			if (($dec[1] > 138) && ($dec[1] < 141))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}
			if (($dec[1] > 147) && ($dec[1] < 177))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}
			if (($dec[1] > 177) && ($dec[1] < 192))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}
			if (($dec[1] > 200) && ($dec[1] <= 255))
			{
#  			Aq_readingsSingleUpdate($hash, $dec[1],$dec[0]." ".$dec[1]." ".$dec[2]." ".$dec[3]." ".$dec[4]." ".$dec[5]." ".$dec[6]." ".$dec[7], 1);
			}

		}

	if ($aktueller_fehler=="") {
		$state = $modus_text." | V:".$temp_v." | R:".$temp_r." | S:".$temp_s." | A:".$temp_a;
	} else {
		$state = $aktueller_fehler;
	}
	Aq_readingsSingleUpdate($hash,"state",$state, 1);

  $hash->{PARTIAL} = $Aquareadata;

}


sub
Aquarea_Ready($)
{
  my ($hash) = @_;

  return DevIo_OpenDev($hash, 1, undef) if ($hash->{STATE} eq "disconnected");

	# This is relevant for Windows/USB only
	if(defined($hash->{USBDev}))
	{
		my $po = $hash->{USBDev};
		my ( $BlockingFlags, $InBytes, $OutBytes, $ErrorFlags ) = $po->status;
		return ( $InBytes > 0 );
 	}
}





1;

=pod
=item device
=item summary_DE liefert die Daten der Kommunikation zwischen der Waermepumpe Panasonic WH-MDC05F3E5 und der Fernbedienung

=begin html

 <a name="modulname"></a>
 define Geisha Aquarea serial /dev/ttyUSBx@1200,8,E,1

 =end html

=begin html_DE

 <a name="modulname"></a>
  define Geisha Aquarea serial /dev/ttyUSBx@1200,8,E,1

 =end html_DE

=cut
