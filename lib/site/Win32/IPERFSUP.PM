
package Win32::IPerfsup;
#use Win32;

$VERSION = "0.7";
			  
use Win32::API;
use Carp;   
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(BrowseCounters);

if(Win32::IsWin95) {                                            
croak "The IPerfmon module is only compatible with WinNT.\n";
 }                                                                
                                       
                                                               
my($BrowseCounters) = new Win32::API("iperfb.dll", "BrowseDialog", [P,P,I,I],I);
                                                               #

sub BrowseCounters
{
if(scalar(@_) > 3)
  { croak "\n[Error] Parameters doesn't correspond in QueryObj->BrowseCounters()\n";}
my($Buffer)=150000; # Resize this buffer if you have too many counters to return,
                    # it's by default at 150k 
my($Counters)=shift;
my($Detail)=shift;my($Str)=" "x$Buffer;
my($Ptr1) = pack("L",0);
$BrowseCounters->Call($Str,$Ptr1,400,$Buffer);
$Ptr1 = unpack("L",$Ptr1);
$Str=unpack(a.$Ptr1,$Str);
#$Str =~ s/\\/\\\\/g;
#$Str=~s/GENE1/Gene1/ig;
@$Counters=split(/&/,$Str);

#print Win32::NodeName;
}
1;
_END_
