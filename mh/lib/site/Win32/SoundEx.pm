package Win32::SoundEx;

use Carp;
require Win32::API;

sub MAXPNAMELEN() { 32 }
sub DWORD_ALIGN ($) {
  $_[0] = $_[0] + 4 - $_[0] % 4 if $_[0] % 4;
}

init();

sub mixerGetNumDevs {
  $mixerGetNumDevs ||= Win32::API->new("winmm", "mixerGetNumDevs", [],N) or return;
  $mixerGetNumDevs->Call;
}

sub auxGetNumDevs {
  $auxGetNumDevs ||= Win32::API->new("winmm", "auxGetNumDevs", [],N) or return;
  $auxGetNumDevs->Call;
}

sub waveOutGetNumDevs {
  $waveOutGetNumDevs ||= Win32::API->new("winmm", "waveOutGetNumDevs", [],N) or return;
  $waveOutGetNumDevs->Call;
}

sub mixerGetDevCaps {
  my $uMxId = shift;
  $mixerGetDevCaps ||= Win32::API->new("winmm", "mixerGetDevCaps", [N,P,N],N) or return;

  my $cbmxcaps  = 2*3 + MAXPNAMELEN()+ 4*2; DWORD_ALIGN($cbmxcaps);
  my $MIXERCAPS = "\0"x$cbmxcaps;

  my $err = $mixerGetDevCaps->Call($uMxId, $MIXERCAPS, $cbmxcaps);
  $err == MMSYSERR_NOERROR() or croak "WinMM Error: $err\n";

  my ($wMid,$wPid,$vDriverVersion,$szPname,$fdwSupport,$cDestinations) =
      unpack "SSSx2a".MAXPNAMELEN()."LL", $MIXERCAPS;
  $szPname =~ s/\0.*$//s;

  { ManufacturerID   => $wMid,
    Manufacturer     => $MANUF{$wMid},
    ProductID        => $wPid,
    DriverVersion    => $vDriverVersion,
    DriverVersionStr => sprintf("%.1d.%.1d", ($vDriverVersion >> 8),($vDriverVersion & 0xFF)),
    ProductName      => $szPname,
    Destinations     => $cDestinations,
  };
}

sub auxGetDevCaps {
  my $uDeviceID = shift;
  $auxGetDevCaps ||= Win32::API->new("winmm", "auxGetDevCaps", [N,P,N],N) or return;

  my $cbCaps  = 2*3 + MAXPNAMELEN()+ 2*2+4; DWORD_ALIGN($cbCaps);
  my $AUXCAPS = "\0"x$cbCaps;

  my $err = $auxGetDevCaps->Call($uDeviceID, $AUXCAPS, $cbCaps);
  $err == MMSYSERR_NOERROR() or croak "WinMM Error: $err\n";

  my ($wMid,$wPid,$vDriverVersion,$szPname,$wTechnology,$wReserved1,$dwSupport) =
      unpack "SSSx2a".MAXPNAMELEN()."SSL", $AUXCAPS;
  $szPname =~ s/\0.*$//s;

  { ManufacturerID   => $wMid,
    Manufacturer     => $MANUF{$wMid},
    ProductID        => $wPid,
    DriverVersion    => $vDriverVersion,
    DriverVersionStr => sprintf("%.1d.%.1d", ($vDriverVersion >> 8),($vDriverVersion & 0xFF)),
    ProductName      => $szPname,
    Flags => {
	VOLUME    => ($dwSupport & AUXCAPS_VOLUME()    ? 1 : 0),
	LRVOLUME  => ($dwSupport & AUXCAPS_LRVOLUME()  ? 1 : 0),
	AUXIN     => ($wTechnology & AUXCAPS_AUXIN()   ? 1 : 0),
	CDAUDIO   => ($wTechnology & AUXCAPS_CDAUDIO() ? 1 : 0),
    },
  };
}

sub waveOutGetDevCaps {
  my $uDeviceID = shift;
  $waveOutGetDevCaps ||= Win32::API->new("winmm", "waveOutGetDevCaps", [N,P,N],N) or return;

  my $cbwoc       = 2*3 + MAXPNAMELEN()+ 2*2+4*2; DWORD_ALIGN($cbwoc);
  my $WAVEOUTCAPS = "\0"x$cbwoc;

  my $err = $waveOutGetDevCaps->Call($uDeviceID, $WAVEOUTCAPS, $cbwoc);
  $err == MMSYSERR_NOERROR() or croak "WinMM Error: $err\n";

  my ($wMid,$wPid,$vDriverVersion,$szPname,$dwFormats,$wChannels,$wReserved1,$dwSupport) =
      unpack "SSSx2a".MAXPNAMELEN()."LSSL", $WAVEOUTCAPS;
  $szPname =~ s/\0.*$//s;

  my @formstr = (
	"11.025 kHz, mono, 8-bit",
	"11.025 kHz, mono, 16-bit",
	"11.025 kHz, stereo, 8-bit",
	"11.025 kHz, stereo, 16-bit",
	"22.05 kHz, mono, 8-bit",
	"22.05 kHz, mono, 16-bit",
	"22.05 kHz, stereo, 8-bit",
	"22.05 kHz, stereo, 16-bit",
	"44.1 kHz, mono, 8-bit",
	"44.1 kHz, mono, 16-bit",
	"44.1 kHz, stereo, 8-bit",
	"44.1 kHz, stereo, 16-bit",
  );

  my @formats = (); my $i=0;
  for (qw(1M08 1M16 1S08 1S16 2M08 2M16 2S08 2S16 4M08 4M16 4S08 4S16)) {
    eval("WAVE_FORMAT_$_()") & $dwFormats and push @formats, $formstr[$i];
    $i++;
  }

  { ManufacturerID   => $wMid,
    Manufacturer     => $MANUF{$wMid},
    ProductID        => $wPid,
    DriverVersion    => $vDriverVersion,
    DriverVersionStr => sprintf("%.1d.%.1d", ($vDriverVersion >> 8),($vDriverVersion & 0xFF)),
    ProductName      => $szPname,
    FormatsRaw       => $dwFormats,
    Formats          => \@formats,
    Stereo           => ($wChannels == 2 ? 1 : 0),
    Flags => {
	PITCH          => ($dwSupport & WAVECAPS_PITCH         () ? 1 : 0),
	PLAYBACKRATE   => ($dwSupport & WAVECAPS_PLAYBACKRATE  () ? 1 : 0),
	VOLUME         => ($dwSupport & WAVECAPS_VOLUME        () ? 1 : 0),
	LRVOLUME       => ($dwSupport & WAVECAPS_LRVOLUME      () ? 1 : 0),
	SYNC           => ($dwSupport & WAVECAPS_SYNC          () ? 1 : 0),
	SAMPLEACCURATE => ($dwSupport & WAVECAPS_SAMPLEACCURATE() ? 1 : 0),
	DIRECTSOUND    => ($dwSupport & WAVECAPS_DIRECTSOUND   () ? 1 : 0),
    },
  };
}

sub auxGetVolume {
  my ($uDeviceID, $lpdwVolume) = (shift, pack "L",0);
  $auxGetVolume ||= Win32::API->new("winmm", "auxGetVolume", [N,P],N) or return;
  $auxGetVolume->Call($uDeviceID, $lpdwVolume);
  unpack "L", $lpdwVolume;
}

sub auxSetVolume {
  my ($uDeviceID, $dwVolume) = (shift, shift);
  $auxSetVolume ||= Win32::API->new("winmm", "auxSetVolume", [N,N],N) or return;
  $auxSetVolume->Call($uDeviceID, $dwVolume);
}

sub auxSetVolumeAll {
  my $volume = shift;
  my $num = auxGetNumDevs();
  local $_;
  print "In SoundEx Setting volume for $num devices\n";
  for(0..$num-1){
     my $dev = auxGetDevCaps($_);
     print "db i=$_ dev=$dev vol=$volumn\n";
     auxSetVolume($_, $volume) if $dev->{Flags}{VOLUME};
  }
}

sub auxSetVolumeCD {
  my $volume = shift;
  my $num = auxGetNumDevs();
  local $_;
  for(0..$num-1){
     my $dev = auxGetDevCaps($_);
     auxSetVolume($_, $volume) if $dev->{Flags}{CDAUDIO};
  }
}

sub waveOutGetVolume {
  my ($uDeviceID, $lpdwVolume) = (shift, pack "L",0);
  $waveOutGetVolume ||= Win32::API->new("winmm", "waveOutGetVolume", [N,P],N) or return;
  $waveOutGetVolume->Call($uDeviceID, $lpdwVolume);
  unpack "L", $lpdwVolume;
}


use enum qw(
:MMSYSERR_=0
NOERROR
ERROR
BADDEVICEID
NOTENABLED
ALLOCATED
INVALHANDLE
NODRIVER
NOMEM
NOTSUPPORTED
BADERRNUM
INVALFLAG
INVALPARAM
HANDLEBUSY
INVALIDALIAS
BADDB
KEYNOTFOUND
READERROR
WRITEERROR
DELETEERROR
VALNOTFOUND
NODRIVERCB
LASTERROR=20
);

# * supports volume control *
use enum qw(
AUXCAPS_VOLUME=1
AUXCAPS_LRVOLUME=2
);

# * audio from internal CD-ROM drive *
use enum qw(
AUXCAPS_CDAUDIO=1
AUXCAPS_AUXIN=2
);

# * wave formats *
use enum qw(
WAVE_INVALIDFORMAT=0
BITMASK:WAVE_
FORMAT_1M08
FORMAT_1S08
FORMAT_1M16
FORMAT_1S16
FORMAT_2M08
FORMAT_2S08
FORMAT_2M16
FORMAT_2S16
FORMAT_4M08
FORMAT_4S08
FORMAT_4M16
FORMAT_4S16
);


use enum qw(
BITMASK:WAVECAPS_=1
PITCH
PLAYBACKRATE
VOLUME
LRVOLUME
SYNC
SAMPLEACCURATE
DIRECTSOUND
);

sub init () {
 %MANUF = (
  1      => 'Microsoft Corporation',
  2      => 'Creative Labs, Inc.',
  3      => 'Media Vision, Inc.',
  4      => 'Fujitsu Corp.',
  5      => 'PRAGMATRAX Software',
  6      => 'Cyrix Corporation',
  7      => 'Philips Speech Processing',
  8      => 'NetXL, Inc.',
  9      => 'ZyXEL Communications, Inc.',
  10     => 'BeCubed Software Inc.',
  11     => 'Aardvark Computer Systems, Inc.',
  12     => 'Bin Tec Communications GmbH',
  13     => 'Hewlett-Packard Company',
  14     => 'Aculab plc',
  15     => 'Faith,Inc.',
  16     => 'Mitel Corporation',
  17     => 'Quantum3D, Inc.',
  18     => 'Siemens-Nixdorf',
  19     => 'E-mu Systems, Inc.',
  20     => 'Artisoft, Inc.',
  21     => 'Turtle Beach, Inc.',
  22     => 'IBM Corporation',
  23     => 'Vocaltec Ltd.',
  24     => 'Roland',
  25     => 'DSP Solutions, Inc.',
  26     => 'NEC',
  27     => 'ATI Technologies Inc.',
  28     => 'Wang Laboratories, Inc.',
  29     => 'Tandy Corporation',
  30     => 'Voyetra',
  31     => 'Antex Electronics Corporation',
  32     => 'ICL Personal Systems',
  33     => 'Intel Corporation',
  34     => 'Advanced Gravis',
  35     => 'Video Associates Labs, Inc.',
  36     => 'InterActive Inc.',
  37     => 'Yamaha Corporation of America',
  38     => 'Everex Systems, Inc.',
  39     => 'Echo Speech Corporation',
  40     => 'Sierra Semiconductor Corp',
  41     => 'Computer Aided Technologies',
  42     => 'APPS Software International',
  43     => 'DSP Group, Inc.',
  44     => 'microEngineering Labs',
  45     => 'Computer Friends, Inc.',
  46     => 'ESS Technology',
  47     => 'Audio, Inc.',
  48     => 'Motorola, Inc.',
  49     => 'Canopus, co., Ltd.',
  50     => 'Seiko Epson Corporation',
  51     => 'Truevision',
  52     => 'Aztech Labs, Inc.',
  53     => 'Videologic',
  54     => 'SCALACS',
  55     => 'Korg Inc.',
  56     => 'Audio Processing Technology',
  57     => 'Integrated Circuit Systems, Inc.',
  58     => 'Iterated Systems, Inc.',
  59     => 'Metheus',
  60     => 'Logitech, Inc.',
  61     => 'Winnov, Inc.',
  62     => 'NCR Corporation',
  63     => 'EXAN',
  64     => 'AST Research Inc.',
  65     => 'Willow Pond Corporation',
  66     => 'Sonic Foundry',
  67     => 'Vitec Multimedia',
  68     => 'MOSCOM Corporation',
  69     => 'Silicon Soft, Inc.',
  70     => 'TerraTec Electronic GmbH',
  71     => 'MediaSonic Ltd.',
  72     => 'SANYO Electric Co., Ltd.',
  73     => 'Supermac',
  74     => 'Audio Processing Technology',
  75     => 'NOGATECH Ltd.',
  76     => 'Speech Compression',
  77     => 'Ahead, Inc.',
  78     => 'Dolby Laboratories',
  79     => 'OKI',
  80     => 'AuraVision Corporation',
  81     => 'Ing C. Olivetti & C., S.p.A.',
  82     => 'I/O Magic Corporation',
  83     => 'Matsushita Electric Industrial Co., Ltd.',
  84     => 'Control Resources Limited',
  85     => 'Xebec Multimedia Solutions Limited',
  86     => 'New Media Corporation',
  87     => 'Natural MicroSystems',
  88     => 'Lyrrus Inc.',
  89     => 'Compusic',
  90     => 'OPTi Computers Inc.',
  91     => 'Adlib Accessories Inc.',
  92     => 'Compaq Computer Corp.',
  93     => 'Dialogic Corporation',
  94     => 'InSoft, Inc.',
  95     => 'M.P. Technologies, Inc.',
  96     => 'Weitek',
  97     => 'Lernout & Hauspie',
  98     => 'Quanta Computer Inc.',
  99     => 'Apple Computer, Inc.',
  100    => 'Digital Equipment Corporation',
  101    => 'Mark of the Unicorn',
  102    => 'Workbit Corporation',
  103    => 'Ositech Communications Inc.',
  104    => 'miro Computer Products AG',
  105    => 'Cirrus Logic',
  106    => 'ISOLUTION  B.V.',
  107    => 'Horizons Technology, Inc.',
  108    => 'Computer Concepts Ltd.',
  109    => 'Voice Technologies Group, Inc.',
  110    => 'Radius',
  111    => 'Rockwell International',
  112    => 'Co. XYZ for testing',
  113    => 'Opcode Systems',
  114    => 'Voxware Inc.',
  115    => 'Northern Telecom Limited',
  116    => 'APICOM',
  117    => 'Grande Software',
  118    => 'ADDX',
  119    => 'Wildcat Canyon Software',
  120    => 'Rhetorex Inc.',
  121    => 'Brooktree Corporation',
  125    => 'ENSONIQ Corporation',
  126    => 'FAST Multimedia AG',
  127    => 'NVidia Corporation',
  128    => 'OKSORI Co., Ltd.',
  129    => 'DiAcoustics, Inc.',
  130    => 'Gulbransen, Inc.',
  131    => 'Kay Elemetrics, Inc.',
  132    => 'Crystal Semiconductor Corporation',
  133    => 'Splash Studios',
  134    => 'Quarterdeck Corporation',
  135    => 'TDK Corporation',
  136    => 'Digital Audio Labs, Inc.',
  137    => 'Seer Systems, Inc.',
  138    => 'PictureTel Corporation',
  139    => 'AT&T Microelectronics',
  140    => 'Osprey Technologies, Inc.',
  141    => 'Mediatrix Peripherals',
  142    => 'SounDesignS M.C.S. Ltd.',
  143    => 'A.L. Digital Ltd.',
  144    => 'Spectrum Signal Processing, Inc.',
  145    => 'Electronic Courseware Systems, Inc.',
  146    => 'AMD',
  147    => 'Core Dynamics',
  148    => 'CANAM Computers',
  149    => 'Softsound, Ltd.',
  150    => 'Norris Communications, Inc.',
  151    => 'Danka Data Devices',
  152    => 'EuPhonics',
  153    => 'Precept Software, Inc.',
  154    => 'Crystal Net Corporation',
  155    => 'Chromatic Research, Inc.',
  156    => 'Voice Information Systems, Inc.',
  157    => 'Vienna Systems',
  158    => 'Connectix Corporation',
  159    => 'Gadget Labs LLC',
  160    => 'Frontier Design Group LLC',
  161    => 'Viona Development GmbH',
  162    => 'Casio Computer Co., LTD',
  163    => 'Diamond Multimedia',
  164    => 'S3',
  165    => 'D-Vision Systems, Inc.',
  166    => 'Netscape Communications',
  167    => 'Soundspace Audio',
  168    => 'VanKoevering Company',
  169    => 'Q-Team',
  170    => 'Zefiro Acoustics',
  171    => 'Studer Professional Audio AG',
  172    => 'Fraunhofer IIS',
  173    => 'Quicknet Technologies',
  174    => 'Alaris, Inc.',
  175    => 'SIC Resource Inc.',
  176    => 'NeoMagic Corporation',
  177    => 'Merging Technologies S.A.',
  178    => 'Xirlink, Inc.',
  179    => 'Colorgraph (UK) Ltd',
  180    => 'Oak Technology, Inc.',
  181    => 'Aureal Semiconductor',
  182    => 'Vivo Software',
  183    => 'Sharp',
  184    => 'Lucent Technologies',
  185    => 'AT&T Labs, Inc.',
  186    => 'Sun Communications, Inc.',
  187    => 'Sorenson Vision',
  188    => 'InVision Interactive',
  189    => 'Deutsche Telekom Berkom GmbH',
  190    => 'Marian GbR Leipzig',
  191    => 'Digital Processing Systems, Inc.',
  192    => 'BCB Holdings Inc.',
  193    => 'Motion Pixels',
  194    => 'QDesign Corporation',
  195    => 'Nokia Mobile Phones',
  196    => 'DataFusion Systems (Pty) (Ltd)',
  197    => 'The Duck Corporation',
  198    => 'Future Technology Resources Pty Ltd',
  199    => 'BERCOS GmbH',
  200    => 'OnLive! Technologies, Inc.',
  201    => 'Siemens Business Communications Systems',
  202    => 'TeraLogic, Inc.',
  203    => 'PhoNet Communications Ltd.',
  204    => 'Winbond Electronics Corp',
  205    => 'Virtual Music, Inc.',
  206    => 'e-Net, Inc.',
  207    => 'Guillemot International',
  208    => 'Emagic Soft- und Hardware GmbH',
  209    => 'MWM Acoustics LLC',
  210    => 'Pacific Research and Engineering Corporation',
  211    => 'Sipro Lab Telecom Inc.',
  212    => 'Lynx Studio Technology, Inc.',
  213    => 'Spectrum Productions',
  214    => 'Dictaphone Corporation',
  215    => 'QUALCOMM, Inc.',
  216    => 'Ring Zero Systems, Inc',
  217    => 'AudioScience Inc.',
  218    => 'Pinnacle Systems, Inc.',
  219    => 'EES Technik fÝr Musik GmbH',
  220    => 'haftmann#software',
  221    => 'Lucid Technology, Symetrix Inc.',
  222    => 'Headspace, Inc',
  223    => 'UNISYS CORPORATION',
  224    => 'Luminositi, Inc.',
  225    => 'ACTIVE VOICE CORPORATION',
  226    => 'Digital Theater Systems, Inc.',
  227    => 'DIGIGRAM',
  228    => 'Softlab-Nsk',
  229    => 'ForteMedia, Inc',
  230    => 'Sonorus, Inc.',
  231    => 'Array Microsystems, Inc.',
  0xffff => 'extensible MID mapping',
  );
}

1;
