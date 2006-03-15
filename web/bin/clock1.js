
<SCRIPT LANGUAGE="JavaScript">

<!-- Begin
function showTheHours(theHour) {
 if ((theHour > 0 && theHour < 13)) {
  if (theHour == "0") theHour = 12;
  return (theHour);
 }
 if (theHour == 0) {
  return (12);
 }
 return (theHour-12);
}

function showZeroFilled(inValue) {
 if (inValue > 9) {
  return "" + inValue;
 }
 return "0" + inValue;
}

function showAmPm() {
 if (now.getHours() < 12) {
  return (" am");
 }
 return (" pm");
}

function clock() {
 now = new Date
 document.form.jclock.value = showTheHours(now.getHours()) + ":" +
   showZeroFilled(now.getMinutes()) + ":" + showZeroFilled(now.getSeconds()) + showAmPm()
 setTimeout("clock()",1000)
}
// End -->
</script>
