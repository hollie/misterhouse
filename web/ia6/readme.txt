From Doug Nakakihara on 10/2001

The code for my page wouldn't do you much good since it's for a San
Antonio-only web page. However, I reworked EVERYTHING and came up with a
template of sorts. It will grab similar icons from weatherpoint.com for the
page--if you set it up right. All of my custom graphics are included and
there is a readme file =)  (Note that the spinning green monopoly house is a
PD graphic.)

Picture: http://www.dougworld.com/temp/audrey2.jpg
Files: http://www.dougworld.com/temp/audreyweb.zip

It's a bit different than my original design mostly because the weather
icons needed to be against a white background.

Check it out and lemme know if it works. I put it in a dir that should be
mh\web\ia6, but should work in any dir at that same (path) level.

-----------------

Notes
-----
WEATHERPOINT.PL
-Move weatherpoint.pl to your normal code dir.
-You'll also need to set a param in your MH.ini called "WeatherURL" and point
 it to the proper www.weatherpoint.com URL. Just go to weatherpoint.com, enter
 your city or zip and get the URL of the weather page that ultimately
 appears. Your MH.ini entry will look like:

weatherpointURL=http://www.weatherpoint.com/shared/trb/dcity/0,1780,1451-sat,00.html

-Weatherpoint.pl basically downloads the HTML file and "grabs" the table with
 the weather icons every couple hours.

INDEX.HTML
-This is the parent frames page. You shouldn't need to touch this.

TOP.HTML
-The HTML code for this is admittedly ugly. Did it in Dreamweaver, but tried
 to clean it up in case someone wants to try to edit.

BTNS.SHTML
-Just link the buttons to whatever URL you want. I put an example link to
 yahoo.com
-You can also link MH commands to buttons using the normal rules. Note that I
 put the actual btns.shtml page as the return page and not "referrer". Using
 "referrer" caused the parent frames page to be loaded back into this frame.
-The date.pl include file just enters the date into the page.
-The /data/web/weatherpoint.txt file is created by the weatherpoint.pl code
 file.

OTHER
-I hope you notice that the silver buttons look like the ones on the Audrey =)
 All of the custom buttons and the "Misterhouse" house was were created in
 NewTek's LightWave 3D.
