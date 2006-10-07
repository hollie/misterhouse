
These folders contain examples of using the SOAP interface in various 
programming languages.  You will need to install the SOAP::Lite package
from CPAN in order to use the SOAP server with mh.

html folder:
------------
To use the html examples just copy the contents of the html directory to 
your my_mh folder.  Then you can run the examples by going to
           http://misterhouse:8080/my_mh/soapdemo.html
or         http://misterhouse:8080/my_mh/soaptest.html
Substituting the actual name of your misterhouse server for misterhouse.

The soapdemo.html file is a simple page that just displays a select list
with all of the object types.  If you select an object type it will fill 
another select with all of the objects of that type.
The soaptest.html is a page that I have been using to test the soapserver.
You can enter a function to call in the function input and if it requires 
input parameters you can enter them in the parameters box seperated by
semicolons ";".  When you click Run Test button it will show the XML sent 
and the XML received.

The following functions are defined in the WebServices.pm file at the 
time I'm writing this:

	Function                   Inputs
    --------                   --------
    ListObjectTypes
    ListObjectsByType          Any ObjectType i.e. Voice_Cmd
    RunVoiceCommand            Any valid voice command
    GetItemState               Any valid Object listed by ListObjectsByType
    SetItemState               ObjectType;State


perl folder:
------------
These are just some trivial examples of perl programs that use the
SOAP::Lite package as a client.  You will need to make sure that you
enter that correct address for your misterhouse box in the $endpoint
variable.  These are a good way to test that everything is setup correctly
on the misterhouse server machine.

vb.net folder:
--------------
This is a simple vb.net program that will talk to Misterhouse.  You will
need Windows and the .Net 1.1 framework to run the executable.  You can
just copy the WebServiceTest.exe file to any folder and run it.  I have
included the source as well so if you have Visual Studio you can load it
up and play with it.  I think you can load this with the Express version as
well but I have not tried it myself.

To use the example program you must first enter the url for your Misterhouse
server in the URL box, then hit connect to fill the drop down.  If you select
an object type in the drop down it should fill the list box with the objects
of that type.  If you then click on one of those objects it should show the
current state for that object if it can be determined.  You can then try 
changing the state by entering a new value and hitting the Set button.  I've
only tested the GetItemState and SetItemState with X10 items and my ZPR6810 
items so don't be surprised if it throws some errors on other object types.


Hope you find these helpful,

Mike Wiebke 
mw65@yahoo.com
    
