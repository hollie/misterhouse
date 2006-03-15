package Win32::IIPC;
use Win32::API;  
use Carp;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = # constants 
qw(  
LastError
Close
Wait
);
my($DLLPath)="sync.dll";

my($WaitForObject) = new Win32::API($DLLPath,"WaitForObject",[I,I,P],I);
my($CloseHandle) = new Win32::API($DLLPath,"CloseThisHandle",[I,P],I);

sub  LastError {
      $obj = shift;
      print Win32::FormatMessage($obj->{Error});
	#return Win32::FormatMessage($obj->{Error});  
	   }

sub Close
{
my($obj)=shift;
if(scalar(@_) != 0 )
  { croak "\n[Error] Parameters doesn't correspond in Obj->Close()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$CloseHandle->Call($obj->{Handle},$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);;
if ($ret) {return $ret}
else {
     return undef;
     }
}

sub Wait
{
my($obj)=shift;
if(scalar(@_) != 1 )
  { croak "\n[Error] Parameters doesn't correspond in Obj->Wait()\n";}
my($Ptr1)=pack("L",0);
my($ret)=$WaitForObject->Call($obj->{Handle},$_[0],$Ptr1);
$obj->{Error}=unpack("L",$Ptr1);; 
if($ret == WAIT_OBJECT_0) {return 1;}
elsif($ret == WAIT_ABANDONED) {return $ret} 
else { return undef }   
}
