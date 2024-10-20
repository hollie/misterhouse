################################################
#   Package: ISync.pm - 1.1                         
#   Author : Amine Moulay Ramdane              
#   Company: Cyber-NT Communications           
#     Phone: (514)485-6659                    
#     Email: aminer@generation.net              
#      Date: October,5 1998                      
#
# Copyright © 1998 Amine Moulay Ramdane.All rights reserved  
#
# you can get the module at:
# http://www.generation.net/~cybersky/Perl/perlmod.htm or
# http://www.generation.net/~cybersky/Perl/camels.shtml
# but if you have any problem to connect,just contact me 
# at my email above.                   
################################################

package Win32::ISync;
use Win32::API; 
use Win32::IIPC; 
$VERSION = "1.1";
require Exporter;
@ISA = qw(Exporter IIPC);
@EXPORT = # constants 
qw(  
PROCESS_ALL_ACCESS WAIT_OBJECT_0 WAIT_ABANDONED WAIT_TIMEOUT SYNCHRONIZE 
EVENT_ALL_ACCESS MUTEX_ALL_ACCESS TIMER_ALL_ACCESS SEMAPHORE_ALL_ACCESS 
MANUALRESET AUTORESET OWNED NOTOWNED SIGNALED NONSIGNALED INHERITED 
NONINHERITED INFINITE ABSOLUTE RELATIVE CURRENT_DATE _1SEC _1MIN _1HOUR 
_1DAY _1WEEK _1MONTH NULL 
);
my($DLLPath)="sync.dll";
my($DLLPath1)="timer.dll";
my($WaitForObject) = new Win32::API($DLLPath,"WaitForObject",[I,I,P],I);
my($CloseHandle) = new Win32::API($DLLPath,"CloseThisHandle",[I,P],I);

sub WAIT_ABANDONED             ()   {0x00000008}
sub WAIT_OBJECT_0              ()   {0x00000000}  
sub WAIT_TIMEOUT               ()   {0x00000102}
sub SYNCHRONIZE                ()   {0x00100000}
sub STANDARD_RIGHTS_REQUIRED   ()   {0x000F0000}
sub EVENT_MODIFY_STATE         ()   {0x0002}
sub MUTANT_QUERY_STATE         ()   {0x0001}
sub EVENT_ALL_ACCESS           ()   {STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 3}
sub MUTEX_ALL_ACCESS           ()   {STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | MUTANT_QUERY_STATE}
sub TIMER_ALL_ACCESS           ()   {STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 3}
sub SEMAPHORE_ALL_ACCESS       ()   {STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 3}
sub MANUALRESET                ()   {1}
sub AUTORESET                  ()   {0}
sub SIGNALED                   ()   {1}
sub NONSIGNALED                ()   {0}
sub INHERITED                  ()   {1}   
sub NONINHERITED               ()   {0}
sub OWNED                      ()   {1}
sub NOTOWNED                   ()   {0}
sub INFINITE                   ()   {-1}
sub PROCESS_ALL_ACCESS         ()   {STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFF}
sub ABSOLUTE                   ()   {1}
sub RELATIVE                   ()   {0}
sub CURRENT_DATE               ()   {"-1/-1/-1/-1"}  
sub _1SEC                      ()   {1000}
sub _1MIN                      ()   {(60 * _1SEC);}
sub _1HOUR                     ()   {(60 * _1MIN);}
sub _1DAY                      ()   {(24 * _1HOUR);}
sub _1WEEK                     ()   {(7 * _1DAY);}  
sub NULL                       ()   {0} 


sub new  # General constructor
{
my($class)=shift;
my $self = {};
bless $self,$class;
}



package Win32::ISync::Timer; # Class Timer 

use Carp;
require Exporter;
@ISA = qw( Exporter Win32::ISync ); #   Class Timer does inherit from Sync 
@EXPORT = qw(
);

                                          
my($CreateWaitTimer) = new Win32::API($DLLPath1, "CreateWaitTimer", [P,I,P,P],N);
my($SetWaitTimer) = new Win32::API($DLLPath1, "SetWaitTimer", [I,I,I,I,I,I,I,I,I,I,I,I,I,P],N);
my($OpenWaitTimer) = new Win32::API($DLLPath1, "OpenWaitTimer", [I,I,P,P,P],N);
my($CancelWaitTimer) = new Win32::API($DLLPath1,"CancelWaitTimer",[I,P],I);
 
############################################################################
# All  Timer primitives

sub Create
{
my($obj)=shift;
if(scalar(@_) != 2 )
  { croak "\n[Error] Parameters doesn't correspond in TimerObj->Create()\n";}
my $self = {};
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$CreateWaitTimer->Call($Ptr1,$_[0],$_[1],$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);; 
if ($ret) {
	  $obj->{Handle}=unpack("L",$Ptr1);;
	  return $ret}
else {
	return undef;
     }
}

sub Set
{
my($obj)=shift;
if(scalar(@_) != 4 )
  { croak "\n[Error] Parameters doesn't correspond in TimerObj->Set()\n";}
my($Ptr1)=pack("L",0);
my(@Date)=split(/\//,$_[0]);
my(@Time)= split(/:/,$_[1]);
#print "$Date[0] $Date[1] $Date[2] $Date[3] \n";
#print "$Time[0] $Time[1] $Time[2] $Time[3] $Time[4] $Time[5]\n";
my($ret)=$SetWaitTimer->Call($obj->{Handle},$Date[0],$Date[1],$Date[2],$Date[3],$Time[0],$Time[1],
				   $Time[2],$Time[3],$Time[4],$Time[5],$_[2],$_[3],$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);
; 
if ($ret) {return 1}
else {
	return undef;
     }
}

sub Open
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't corespond in TimerObj->Open()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$OpenWaitTimer->Call($_[0],$_[1],$_[2],$Ptr1,$Ptr2);
$Ptr2 = unpack("L",$Ptr2);
$obj->{Error}=unpack("L",$Ptr2); 
if ($ret){
    $obj->{Handle}=unpack("L",$Ptr1);
    return $ret;
	 } 
else {
	return undef;
     }
}

sub Cancel
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in TimerObj->Cancel()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$CancelWaitTimer->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1); 
if ($ret) {return $ret}
else {return undef;} 
}

package Win32::ISync::Mutex; # Class Mutex 

use Carp;
require Exporter;
@ISA = qw( Exporter Win32::ISync );  

my($CreateMutex) = new Win32::API($DLLPath, "Create_Mutex", [P,I,P,P],N);
my($OpenMutex) = new Win32::API($DLLPath, "Open_Mutex", [I,I,P,P,P],N);
my($ReleaseMutex) = new Win32::API($DLLPath, "Release_Mutex", [I,P],I);

############################################################################
# All Mutex primitives
  
sub Create
{
my($obj)=shift;
if(scalar(@_) != 2 )
  { croak "\n[Error] Parameters doesn't correspond in MutexObj->Create()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$CreateMutex->Call($Ptr1,$_[0],$_[1],$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);; 
if ($ret) {$obj->{Handle}=unpack("L",$Ptr1);
	  return $ret}
else {
	return undef;
     }
}

sub Open
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in MutexObj->Open()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$OpenMutex->Call($_[0],$_[1],$_[2],$Ptr1,$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);
if ($ret) {$obj->{Handle}=unpack("L",$Ptr1);
	   return $ret}
else {
	return undef;
     }
}

sub Release
{
my($obj)=shift;
if(scalar(@_) != 0 )
  {croak "\n[Error] Parameters doesn't correspond in MutexObj->Release()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$ReleaseMutex->Call($obj->{Handle},$Ptr1);
my($Error)=unpack("L",$Ptr1); 
$obj->{Error}=$Error; 
if ($ret) {return $ret}
else {
	return undef;
     }
}

package Win32::ISync::Semaphore; # Class Semaphore 

use Carp;
require Exporter;
@ISA = qw( Exporter Win32::ISync );  

my($CreateSemaphore) = new Win32::API($DLLPath, "Create_Semaphore", [P,I,I,P,P],N);
my($OpenSemaphore) = new Win32::API($DLLPath, "Open_Semaphore", [I,I,P,P,P],N);
my($ReleaseSemaphore) = new Win32::API($DLLPath, "Release_Semaphore", [I,I,P,P],I);

############################################################################
# All Semaphore primitives
  
sub Create
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in SemObj->Create()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$CreateSemaphore->Call($Ptr1,$_[0],$_[1],$_[2],$Ptr2);
$obj->{Error}=unpack("L",$Ptr2); 
if ($ret) {$obj->{Handle}=unpack("L",$Ptr1);
	  return $ret}
else {
	return undef;
     }
}

sub Open
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in SemObj->Open()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$OpenSemaphore->Call($_[0],$_[1],$_[2],$Ptr1,$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);;
if ($ret) {$obj->{Handle}=unpack("L",$Ptr1);
	   return $ret}
else {
	return undef;
     }
}

sub Release
{
my($obj)=shift;
if(scalar(@_) != 1 )
  { croak "\n[Error] Parameters doesn't correspond in SemObj->Release()\n";}
if($_[0] == 0) {croak "\n[Error] SemObj->Release(\$count),\$count must be > 0\n";} 
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$ReleaseSemaphore->Call($obj->{Handle},$_[0],$Ptr1,$Ptr2);
$obj->{LastCount}=unpack("L",$Ptr1);
$obj->{Error}=unpack("L",$Ptr2); 
if ($ret) {return $ret}
else {
	return undef;
     }
}

package Win32::ISync::Event; # Class Mutex 

use Carp;
require Exporter;
@ISA = qw( Exporter Win32::ISync );  

my($CreateEvent) = new Win32::API($DLLPath, "Create_Event", [P,I,I,P,P],I);
my($OpenEvent) = new Win32::API($DLLPath, "Open_Event", [I,I,P,P,P],I);
my($SetEvent) = new Win32::API($DLLPath,"Set_Event",[I,P],I);
my($ResetEvent) = new Win32::API($DLLPath,"Reset_Event",[I,P],I);
my($PulseEvent) = new Win32::API($DLLPath,"Pulse_Event",[I,P],I); 

############################################################################
# All Event primitives

sub Create
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in EventObj->Create()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$CreateEvent->Call($Ptr1,$_[0],$_[1],$_[2],$Ptr2);
$obj->{Error}=unpack("L",$Ptr2); 
if ($ret) 
    {$obj->{Handle}=unpack("L",$Ptr1);
     return $ret}
else {
	return undef;
     }
}

sub Open
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in EventObj->Open()\n";}
my($Ptr1)=pack("L",0);
my($Ptr2)=pack("L",0);
my($ret)=$OpenEvent->Call($_[0],$_[1],$_[2],$Ptr1,$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);
if ($ret) 
     {$obj->{Handle}=unpack("L",$Ptr1);
      return $ret}
else {
	return undef;
     }
}

sub Reset
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in EventObj->Reset()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$ResetEvent->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1); 
if ($ret) {return $ret}
else {return undef;} 
}

sub Set
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in EventObj->Set()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$SetEvent->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1); 
if ($ret) {return $ret}
else {return undef;} 
}

sub Pulse
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in EventObj->Pulse()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$PulseEvent->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1); 
if ($ret) {return $ret}
else {return undef;} 
}
