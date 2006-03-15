################################################
#   Package: IPerfmon.pm                           
#   Author : Amine Moulay Ramdane                
#   Company: Cyber-NT Communications           
#     Phone: (514)485-6659                    
#     Email: aminer@generation.net              
#      Date: October 5,1998                      
#   version: 1.01         
#   Started: September 24,1998
#
# Copyright © 1998 Amine Moulay Ramdane.All rights reserved
#
# you can get the module at:
# http://www.generation.net/~cybersky/Perl/perlmod.htm or
# http://www.generation.net/~cybersky/Perl/camels.shtml
# but if you have any problem to connect,just contact me 
# at my email above.                   
################################################

package Win32::IPerfmon;
use Win32::API; 
use Carp;
$VERSION = "1.01";
require Exporter;
@ISA = qw(Exporter);
@EXPORT =  
qw(  
);
@EXPORT_OK =
qw(
PERF_DETAIL_NOVICE
PERF_DETAIL_ADVANCED
PERF_DETAIL_EXPERT
PERF_DETAIL_WIZARD
PDH_FMT_RAW
PDH_FMT_ANSI
PDH_FMT_UNICODE
PDH_FMT_LONG
PDH_FMT_DOUBLE
PDH_FMT_LARGE
PDH_FMT_NOSCALE  
PDH_FMT_1000                        
PDH_FMT_NODATA
PERF_DETAIL_NOVICE
PERF_DETAIL_ADVANCED
PERF_DETAIL_EXPERT
PERF_DETAIL_WIZARD
INCLUDE_INSTANCE_INDEX
SINGLE_COUNTER_PER_ADD
SINGLE_COUNTER_PER_DIALOG 
LOCAL_COUNTER_ONLY
WILD_CARD_INSTANCES
HIDE_DETAIL_BOX
INITIALIZE_PATH
DISABLE_MACHINE_SELECTION
RESERVED                         
);

my($DLLPath)="IPerfmon.dll"; # you can use a path like 'c:\perl...\auto\IMonitor\IMonitor.dll'
                             # or use double quotes like "c:\\perl...\\auto\\IMonitor\\IMonitor.dll"     
my($EnumObjects) = new Win32::API($DLLPath,"EnumObjects",[P,I,P,P,P],I);
my($EnumObjectItems) = new Win32::API($DLLPath,"EnumObjectItems",[P,P,I,P,P,P,P,P],I);
my($BrowseCounters) = new Win32::API($DLLPath,"BrowseCounters",[I,I,P,P,P],I);
my($ValidatePath)= new Win32::API($DLLPath,"ValidatePath",[P,P],I);
my($ReallocMem)= new Win32::API($DLLPath,"ReallocMemory",[P,I],I);
my($FreeMem)= new Win32::API($DLLPath,"FreeMemory",[P],I);

sub PDH_FMT_RAW               ()   {0x00000010}
sub PDH_FMT_ANSI              ()   {0x00000020}
sub PDH_FMT_UNICODE           ()   {0x00000040}
sub PDH_FMT_LONG              ()   {0x00000100}
sub PDH_FMT_DOUBLE            ()   {0x00000200}
sub PDH_FMT_LARGE             ()   {0x00000400}
sub PDH_FMT_NOSCALE           ()   {0x00001000}  
sub PDH_FMT_1000              ()   {0x00002000}                        
sub PDH_FMT_NODATA            ()   {0x00004000}
sub PERF_DETAIL_NOVICE        ()   {100}
sub PERF_DETAIL_ADVANCED      ()   {200}
sub PERF_DETAIL_EXPERT        ()   {300}
sub PERF_DETAIL_WIZARD        ()   {400}
sub INCLUDE_INSTANCE_INDEX    ()   {1}
sub SINGLE_COUNTER_PER_ADD    ()   {2}
sub SINGLE_COUNTER_PER_DIALOG ()   {4}
sub LOCAL_COUNTER_ONLY        ()   {8}
sub WILD_CARD_INSTANCES       ()   {16}
sub HIDE_DETAIL_BOX           ()   {32}
sub INITIALIZE_PATH           ()   {64}
sub DISABLE_MACHINE_SELECTION ()   {128}
sub RESERVED                  ()   {0xFFFFFF00}

   
sub new  # Constructor
{
my($class)=shift;
my $self = {};
bless $self,$class;
}

sub ReallocMem
{
my($obj)=shift;
my($ret) = $ReallocMem->Call($_[0],$_[1]);
}

############################################################################
# IPerfmon interface 

sub EnumObjects
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in Obj->EnumObjects()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
my($Str);my($Machine)=shift;my($Detail)=shift;my($Info)=shift;
my($ret)=$EnumObjects->Call($Machine,$Detail,$Ptr1,$Ptr2,$Ptr3);
$obj->{Error}=unpack("L",$Ptr3);; 
$Ptr2 = unpack("L",$Ptr2);
$Str=unpack(P.$Ptr2,$Ptr1);
$obj->ReallocMem($Ptr1,0);
@$Info=();
if ($ret) {@$Info = split(/&/,$Str);
           return $ret}
else {return undef;}
}

sub EnumObjectItems
{
my($obj)=shift;
if(scalar(@_) != 5 )
  { croak "\n[Error] Parameters doesn't correspond in Obj->EnumObjectItems()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
my($Ptr4)=pack("L",0);my($Ptr5)=pack("L",0);my($Str1);my($Str2);
my($Machine)=shift;my($Object)=shift;my($Detail)=shift;my($Instances)=shift;my($Counters)=shift;
my($ret)=$EnumObjectItems->Call($Machine,$Object,$Detail,$Ptr1,$Ptr2,$Ptr3,$Ptr4,$Ptr5);
$obj->{Error}=unpack("L",$Ptr5);; 
$Ptr2 = unpack("L",$Ptr2);
$Str2 = unpack(P.$Ptr2,$Ptr1);
$obj->ReallocMem($Ptr1,0);
$Ptr4 = unpack("L",$Ptr4);
$Str1 = unpack(P.$Ptr4,$Ptr3);
$obj->ReallocMem($Ptr3,0);
@$Instances=();@$Counters=();
if ($ret) {@$Instances=split(/&/,$Str1);
           @$Counters=split(/&/,$Str2);
           return $ret}
else {return undef;}
}

sub BrowseCounters
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->BrowseCounters()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
my($Flag)=shift;my($Detail)=shift;my($Value)=shift;
my($ret)=$BrowseCounters->Call($Flag,$Detail,$Ptr1,$Ptr2,$Ptr3);
$obj->{Error}=unpack("L",$Ptr3);
$Ptr2 = unpack("L",$Ptr2);
$Str = unpack(P.$Ptr2,$Ptr1);
$obj->ReallocMem($Ptr1,0);
if ($ret) {$$Value=$Str;
           return $ret}
else {return undef;}
}

sub ValidatePath
{
my($obj)=shift;
if(scalar(@_) != 1 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->ValidatePath()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$ValidatePath->Call($_[0],$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);
if ($ret) {return $ret}
else {return undef;}
}

###################################################
# IPerfmon::Query subinterface 
#

package Win32::IPerfmon::Query;  

use Carp;
require Exporter;
@ISA = qw(Exporter);     
@EXPORT = qw(
);

my($OpenQuery) = new Win32::API($DLLPath,"OpenQuery",[P,P],I);
my($AddCounter) = new Win32::API($DLLPath,"AddCounter",[I,P,P,P],I);
my($RemoveCounter) = new Win32::API($DLLPath,"RemoveCounter",[I,P],I);
my($CloseQuery) = new Win32::API($DLLPath,"CloseQuery",[I,P],I);
my($CollectData) = new Win32::API($DLLPath,"CollectData",[I,P],I);
my($SetCounterScaleFactor) = new Win32::API($DLLPath,"SetCounterScaleFactor",[I,I,P],I);
my($GetCounterHelpText) = new Win32::API($DLLPath,"GetCounterHelpText",[I,P,P,P],I);
my($GetFormattedValue) = new Win32::API($DLLPath,"GetFormattedValue",[I,I,P,P,P],I);
#$ReallocMem= new Win32::API($DLLPath,"ReallocMemory",[P,I],I);

sub new  
{
my($class)=shift;
my $self = {};
bless $self,$class;
}

sub ReallocMem
{
my($obj)=shift;
my($ret) = $ReallocMem->Call($_[0],$_[1]);
}

sub Open
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->Open()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);
my($ret)=$OpenQuery->Call($Ptr1,$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);
if ($ret) {$obj->{Handle}=unpack("L",$Ptr1);
           return $ret}
else {return undef;}
}

sub AddCounter
{
my($obj)=shift;
if(scalar(@_) != 2 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->AddCounter()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Path)=shift;my($Handle)=shift;
my($ret)=$AddCounter->Call($obj->{Handle},$Path,$Ptr1,$Ptr2);
$obj->{Error}=unpack("L",$Ptr2);
if ($ret) {$$Handle=unpack("L",$Ptr1);
           return $ret}
else {return undef;}
}

sub RemoveCounter
{
my($obj)=shift;
if(scalar(@_) != 1 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->RemoveCounter()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$RemoveCounter->Call($_[0],$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);
if ($ret) {return $ret}
else {return undef;}
}

sub SetCounterScaleFactor
{
my($obj)=shift;
if(scalar(@_) != 2 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->SetCounterScaleFactor()\n";}
if(($_[1] < -7) || ($_[1] > 7)) 
{ croak "\n[Error] Parameters doesn't correspond in QueryObj->SetCounterScaleFactor(),the scale factor must be in [-7..7].\n";}  
my($Ptr1)=pack("L",0);
my($ret)=$SetCounterScaleFactor->Call($_[0],$_[1],$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);; 
if ($ret) {return $ret}
else {return undef;}
}

sub CollectData
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->CollectData()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$CollectData->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);; 
if ($ret) {return $ret}
else {return undef;}
}

sub GetFormattedValue
{
my($obj)=shift;
if(scalar(@_) != 3 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->GetFormattedValue()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
my($Handle)=shift;my($Format)=shift;my($Value)=shift;
my($ret)=$GetFormattedValue->Call($Handle,$Format,$Ptr1,$Ptr2,$Ptr3);
$obj->{Error}=unpack("L",$Ptr3);
$Ptr2 = unpack("L",$Ptr2);
$Str = unpack(P.$Ptr2,$Ptr1);
$obj->ReallocMem($Ptr1,0);
if ($ret) {$$Value=$Str;
           return $ret}
else {return undef;}
}

sub GetCounterHelpText
{
my($obj)=shift;
if(scalar(@_) != 2 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->GetCounterHelpText()\n";}
my($Ptr1)=pack("L",0);my($Ptr2)=pack("L",0);my($Ptr3)=pack("L",0);
my($Counter)=shift;my($HelpText)=shift;
my($ret)=$GetCounterHelpText->Call($Counter,$Ptr1,$Ptr2,$Ptr3);
$obj->{Error}=unpack("L",$Ptr3);
$Ptr2 = unpack("L",$Ptr2);
$Str = unpack(P.$Ptr2,$Ptr1);
$obj->ReallocMem($Ptr1,0);
if ($ret) {$$HelpText=$Str;
           return $ret}
else {return undef;}
}

sub Close
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->Close()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$CloseQuery->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);; 
if ($ret) {return $ret}
else {return undef;}
}
;

