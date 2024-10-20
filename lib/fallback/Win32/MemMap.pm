
################################################
#   Package: MemMap.pm                            
#   Author : Amine Moulay Ramdane              
#   Company: Cyber-NT Communications           
#     Phone: (514)485-6659                    
#     Email: aminer@generation.net              
#      Date: February 7,1999                      
#   version: 2.03        
#                        
# 
# Copyright © 1998 Amine Moulay Ramdane.All rights reserved
#
# you can get the new documentation at:
# http://www.generation.net/~cybersky/Perl/perlmod.htm or
# but if you have any problem to connect,just contact me 
# at my email above.                   
################################################


package Win32::MemMap;
#use Win32;
use Carp;
$VERSION = "2.03";
			  
use Win32::API;
use Config; 
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
);
@EXPORT_OK= qw(
PAGE_NOACCESS 
PAGE_READONLY 
PAGE_READWRITE 
PAGE_WRITECOPY 
PAGE_EXECUTE 
PAGE_EXECUTE_READ 
PAGE_EXECUTE_READWRITE 
PAGE_EXECUTE_WRITECOPY 
PAGE_GUARD 
PAGE_NOCACHE 
ENABLE_MAPPING
DISABLE_MAPPING
);
sub PAGE_NOACCESS              ()   {1}
sub PAGE_READONLY              ()   {2}
sub PAGE_READWRITE             ()   {4}
sub PAGE_WRITECOPY             ()   {8}
sub PAGE_EXECUTE               ()   {16}
sub PAGE_EXECUTE_READ          ()   {32}
sub PAGE_EXECUTE_READWRITE     ()   {64} 
sub PAGE_EXECUTE_WRITECOPY     ()   {128}
sub PAGE_GUARD                 ()   {256}
sub PAGE_NOCACHE               ()   {512}
sub NULL                       ()   {0} 
sub ENABLE_MAPPING             ()   {1}
sub DISABLE_MAPPING            ()   {0}

#my $MemMapDLL=$Config{installsitearch}."\\auto\\Win32\\MemMap\\memmap.dll";
my $MemMapDLL="../lib/site/auto/Win32/MemMap/memmap.dll";

my $shmread=new Win32::API($MemMapDLL, "shmread", [P,P,I,I,I],I);    
my $shmwrite=new Win32::API($MemMapDLL, "shmwrite", [P,P,I,I,I],I); 
my $MapExist=new Win32::API($MemMapDLL, "MapExisting", [P,P,I,I,P,P],I);
my $GetDataSize=new Win32::API($MemMapDLL, "GetDataSize", [P],I);    
my $GetSize=new Win32::API($MemMapDLL, "GetSize", [P],I); 
my $GetName=new Win32::API($MemMapDLL, "GetMapName", [P,P,P],I); 
my $Clear=new Win32::API($MemMapDLL, "ClearMap", [P],I);    
my $UnmapView=new Win32::API($MemMapDLL, "UnmapView", [P,P],I);
my $CleanMap=new Win32::API($MemMapDLL, "CleanMap", [I,P],I);
my $OpenMappedMem=new Win32::API($MemMapDLL, "OpenMappedMem", [P,P,P,I,P],I);
my $OpenFile=new Win32::API($MemMapDLL, "OpenMappedFile", [P,P,P,P,P],I);
my $FreeMem=new Win32::API($MemMapDLL,"FreeMemory",[P],I);
my $GetPageSize=new Win32::API($MemMapDLL,"GetPageSize",[],I);
my $GetGranularitySize=new Win32::API($MemMapDLL,"GetGranularitySize",[],I);
my $QuerySize=new Win32::API($MemMapDLL,"QuerySize",[P],I);
#my $QueryPageInfo=new Win32::API($MemMapDLL,"QueryPageInfo",[P,I,P,P,P,P,P,P,P,P,P,P,P,P,P,P,P],I);
my $Unlock=new Win32::API($MemMapDLL,"UnlockPage",[P,I,I,I,P],I);
my $Lock=new Win32::API($MemMapDLL,"LockPage",[P,I,I,I,P],I);
#my $MapViewProtect=new Win32::API($MemMapDLL,"MapViewProtect",[P,I,I,I,P,P],I);
my $FlushMapView=new Win32::API($MemMapDLL,"FlushMapView",[P,I,I,P],I);
my $CloseHandle=new Win32::API($MemMapDLL,"CloseThisHandle",[I,P],I);
my $ReallocMem=new Win32::API($MemMapDLL,"ReallocMemory",[P,I],I);
my $QueryHiResCounter=new Win32::API($MemMapDLL,"QueryHiResCounter",[P,P],I);
my $QueryHiResFreq=new Win32::API($MemMapDLL,"QueryHiResFreq",[P,P],I);
my $HiResFreq;my $HiResCounter;my $TimerAdjust;

sub new  
{my($class)=shift;my $self={};%$self=@_;
 bless $self,$class;}

sub FreeMem
{my $Ret=$FreeMem->Call($_[0]);}

sub ReallocMem
{
my($Ret)=$ReallocMem->Call($_[0],$_[1]);
}

sub  LastError {
      $obj = shift;
      print Win32::FormatMessage($obj->{Error});
	#return Win32::FormatMessage($obj->{Error});  
	   }

sub OpenMem 
{my($obj)=shift;
 if(scalar(@_) != 2 ){croak "\n[Error] parameters doesn't correspond in OpenMem()\n";}
 if($_[1] <= 0){croak "The size of the buffer in OpenMem() is too small!\n";} 
 my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
 my($Ret)=$OpenMappedMem->Call($_[0],$Ptr1,$Ptr2,$_[1],$Ptr3);
 $Ptr2=unpack("L",$Ptr2);$obj->{Error}=unpack("L",$Ptr3);
 if($Ret){my $newobj=new Win32::MemMap(Address => $Ptr1,Handle => $Ptr2,
                                       Size=>$_[1],Abs => 0,Mem => 1);
                                       return $newobj;}  
 else{return (undef);}}

sub OpenFile
{my($obj)=shift;
 if(scalar(@_)!=3){croak "\n[Error] parameters doesn't correspond in OpenFile()\n";}
 if (!(-e $_[0])){croak "The ($_[0]) file doesn't exist\n";}
 my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Size)=pack("L",0);
 my($Ret)=$OpenFile->Call($_[0],$Ptr1,$_[1],$Size,$Ptr2);
 $obj->{Error}=unpack("L",$Ptr2);
 if($Ret){
  if($_[2]==ENABLE_MAPPING)
    {my $Size=unpack("L",$Size);$obj->{File}=1;my $newobj=$obj->MapView($_[1],
     $Size,0);$newobj->{Size}=$Size;$newobj->{Abs}=1;
        $newobj->{Handle}=unpack("L",$Ptr1);$newobj->{File}=$_[0];return $newobj;}
  else{my $newobj=new Win32::MemMap(Size   => unpack("L",$Size),
                                    Handle => unpack("L",$Ptr1),
                                    File   => 0,
                                    Abs    => 1);
                                    return $newobj;}} 
else{return undef;}}

sub Read
{my($obj)=shift;
 if(scalar(@_)!=3){croak "\n[Error] parameters doesn't correspond in Read()\n";}
 if($_[1]<0){croak "\n[Error] Wrong value in Read()'s position parameter!\n";}
 if($_[2]<=0){croak "The size of the buffer in Read() is too small\n";}
 my($Scalar)=$_[0];my($sz)=pack("L",0);
 my($Ret)=$shmread->Call($obj->{Address},$sz,$_[1],$_[2],$obj->{Abs});
 $$Scalar=unpack(P.$_[2],$sz);
 if($Ret){return $Ret;}else{return undef;}}  

sub Write
{my($obj)=shift;
 if(scalar(@_)!=2){croak "\n[Error] parameters doesn't correspond in Write()\n";}
 if($_[1]<0){croak "\n[Error] Wrong value in Write()'s position parameter!\n";}
 my($Scalar)=$_[0];my($Ret)=$shmwrite->Call($obj->{Address},$$Scalar,length($$Scalar),$_[1],$obj->{Abs});
 if($Ret){return $Ret;}else{return undef;}}  

sub MapView
{my($obj)=shift;
 if(scalar(@_)!=3){croak "\n[Error] Parameters doesn't correspond in MapView()\n";}
 my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);my($Abs);
 my($Ret)=$MapExist->Call($_[0],$Ptr1,$_[1],$_[2],$Ptr2,$Ptr3);
 $obj->{Error}=unpack("L",$Ptr3);
  if($Ret){$Abs=unpack("L",$Ptr2);if($obj->{File}){$Abs=1;}
           $obj=new Win32::MemMap(Address=>$Ptr1,Abs=>$Abs);return $obj;} 
 else{return undef;}}  

sub UnmapView
{my($obj)=shift;
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in UnmapView()\n";}
 my($Ptr1)=pack("L",0);
 my($Ret)=$UnmapView->Call($obj->{Address},$Ptr1);
 $obj->{Error}=unpack("L",$Ptr1);
 if($Ret){return $Ret;}else{return undef;}}  

sub GetDataSize
{my($obj)=shift;
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in GetDataSize()\n";}
 if($obj->{Abs}!=0){croak "\n[Error] GetDataSize() is only supported on a mapview's size (equal) to the shared memory size\n";}
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in GetDataSize()\n";}
 my($Ret)=$GetDataSize->Call($obj->{Address});
 if($Ret>=0){return $Ret;}else{return undef;}}  

sub GetMapInfo
{my($obj)=shift;
 if(scalar(@_)!=2){croak "\n[Error] parameters doesn't correspond in GetMapInfo()\n";}
 my($Name)=shift;my($MapInfo)=shift;
 my $hnd=$obj->MapView($Name,283,0);
 if($hnd){$hnd->{Abs}=0;
          $$MapInfo={Name     => $hnd->GetName,
                     Size     => $hnd->GetSize,
                     DataSize => $hnd->GetDataSize};
          $hnd->UnmapView;}else{return undef;}}

sub GetName
{my($obj)=shift;
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in GetName()\n";}
 if($obj->{Abs}!=0) {croak "\n[Error] GetName() is only supported on a mapview's size (equal) to the shared memory size\n";}
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in GetName()\n";}
 my($sz)=pack("L",0);my($Ptr1)=pack("L",0);my($Str);
 my($Ret)=$GetName->Call($obj->{Address},$sz,$Ptr1);
 $Ptr1=unpack("L",$Ptr1);$Str=unpack(P.$Ptr1,$sz);FreeMem($sz);
 if($Ret){return $Str;}else{return undef;}}  

sub GetSize
{my($obj)=shift;
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in GetSize()\n";}
 if($obj->{Abs}!=0){croak "\n[Error] GetSize() is only supported on a mapview's size (equal) to the shared memory size\n";}
 if(scalar(@_)!=0 ){croak "\n[Error] parameters doesn't correspond in GetSize()\n";}
 my($Ret)=$GetSize->Call($obj->{Address});
 if($Ret>=0){return $Ret;}else{return undef;}}  

sub GetGranularitySize
{my($obj)=shift;my($Ret)=$GetGranularitySize->Call();return $Ret;}

sub GetMaxSeek
{my($obj)=shift;my($bound)=$obj->GetGranularitySize;my($number);
 if (scalar(@_)!=1){croak "\n[Error] Parameters doesn't correspond in GetMaxSeek\n"} 
 elsif($_[0]<0){croak "\n[Error] A negative file size.\n" }
 elsif($_[0]<=$bound){return (0,$_[0])}else{$number=int(($_[0]/$bound)-1);
 my($rest)=($_[0]%$bound);return($number,$rest);}}

sub Lock
{my($obj)=shift;
 if(scalar(@_)!=2){croak "\n[Error] Parameters doesn't correspond in Lock()\n";}
 my($Ptr1)= pack("L",0);
 my($Ret)=$Lock->Call($obj->{Address},$_[0],$_[1],$obj->{Abs},$Ptr1);
 $obj->{Error}=unpack("L",$Ptr1);
 if($Ret){return $Ret}else{return undef;}}

sub Unlock
{my($obj)=shift;
 if(scalar(@_)!=2){croak "\n[Error] Parameters doesn't correspond in Unlock()\n";}
 my($Ptr1)=pack("L",0);
 my($Ret)=$Unlock->Call($obj->{Address},$_[0],$_[1],$obj->{Abs},$Ptr1);
 $obj->{Error}=unpack("L",$Ptr1);
 if($Ret){return $Ret}else{return undef;}}

sub FlushMapView
{my($obj)=shift;
if($_[0]<0 ){croak "\n[Error] Wrong value in FlushMapView() (Position) parameter!\n";}
if($_[1]<=0){croak "\n[Error] Wrong value in FlushMapView() (Size) parameter!\n";}
if(scalar(@_)!= 2){croak "\n[Error] Parameters doesn't correspond in Flush()\n";}
my($Ptr1)=pack("L",0);
my($Ret)=$FlushMapView->Call($obj->{Address},$_[0],$_[1],$Ptr1);
$Ptr1=unpack("L",$Ptr1);
if($Ret){return $Ret}else{$LastError=$Ptr1;return undef;}}

sub Flush
{my($obj)=shift;
if(scalar(@_)!= 0){croak "\n[Error] Parameters doesn't correspond in Flush()\n";}
if((!$obj->{File})||$obj->{Mem}){croak "\n[Error] Flush() does apply only to File Mapping objects\n"};
my($Ptr1)=pack("L",0);
my($Ret)=$FlushMapView->Call($obj->{Address},0,$obj->{Size},$Ptr1);
$Ptr1=unpack("L",$Ptr1);
if($Ret){return $Ret}else{$LastError=$Ptr1;return undef;}}

sub Clear
{my($obj)=shift;
 if(scalar(@_)!=0){croak "\n[Error] parameters doesn't correspond in Clear()\n";}
 if($obj->{Abs}!=0) {croak "\n[Error] Clear() is only supported on a mapview's size (equal) to the shared memory size\n";}
 if(scalar(@_)!=0 ){croak "\n[Error] parameters doesn't correspond in Clear()\n";}
 my($Ret)=$Clear->Call($obj->{Address});
 if($Ret){return $Ret;}else{return undef;}}  

sub Close
{my($obj)=shift;
 if(scalar(@_)!=0 ){croak "\n[Error] parameters doesn't correspond in Close()\n";}
 my($Ret);my($Ptr1)=pack("L",0);
 if($obj->{Mem}||$obj->{File}){$obj->UnmapView;}
 $Ret=$CleanMap->Call($obj->{Handle},$Ptr1);
 $obj->{Error}=unpack("L",$Ptr1);
 if($Ret){return $Ret;}else{return undef;}}  

sub QueryHiResFreq
{my $obj=shift;my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);
 my($Ret)=$QueryHiResFreq->Call($Ptr1,$Ptr2);
 $Ptr2=unpack("L",$Ptr2);my($Freq)=unpack(P.$Ptr2,$Ptr1);return $Freq;}

sub QueryHiResCounter
{my $obj=shift;my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);
 my($Ret)=$QueryHiResCounter->Call($Ptr1,$Ptr2);
 $Ptr2=unpack("L",$Ptr2);
 my($Counter)=unpack(P.$Ptr2,$Ptr1);
 return $Counter;}

sub StartTimer
{my $obj=shift;
 $HiResFreq=$obj->QueryHiResFreq();
 $HiResCounter=$obj->QueryHiResCounter();}

sub StopTimer
{my $obj=shift;
 my($End)=$obj->QueryHiResCounter(); 
 my($Timing) = ($End - $HiResCounter) * (1 / $HiResFreq);
 if (defined($TimerAdjust))
 {if (($TimerAdjust-$Timing)>0)
   {printf "[%9.9f] second(s)\n",$Timing;}  
  else{$Timing=($Timing-$TimerAdjust); 
      printf "[%9.9f] second(s)\n",$Timing ; }
 }
  return  $Timing;
}

sub InitTimer
{my $obj=shift;$obj->StartTimer();$TimerAdjust=$obj->StopTimer();}
1;


