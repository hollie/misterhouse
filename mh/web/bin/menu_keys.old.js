var midfraction = 0.2;

var dest; 
var speedDefault = 10;
var speed;

var keyactive = true;
function keyon()  { keyactive = true; }
function keyoff() { keyactive = false; }

var current = -1;
var currentid = "INVALID"; 

function setcookie(i) {
  document.cookie = "kb=" + i;
}

function load() {
  cookie = document.cookie;
  if (cookie == '') {
     current = 1;
  }
  else {
     current = parseInt(cookie.substring(3));
  }
  if (current > last_key) {
     current = last_key;
  }
  moveto("i" + current, true);
}

function moveto(id, animate) {
  e = document.getElementById(id);
  if (e != null) {
    c = document.getElementById(currentid);
    if (c != null) {
      c.style.display = "none";
    }
    e.style.display = "inline";
    if (id != "inext" && id != "prev") {
      scrollToMidpage(id, 100, animate);
    }
    currentid = id;
    return true;
  } else {
    // id doesn't exist; cancel move
    return false;
  }
}

function scrollpos() {
  return document.all ? document.body.scrollTop : window.pageYOffset;
}
function winheight() {
  return document.all ? document.body.clientHeight : window.innerHeight;
}

// scrolls object to middle of screen if it's not in view
// margin is the number of pixels at the bottom of the screen
// in which to consider the object "below the screen" and in need of scrolling
function scrollToMidpage(id, margin, animate) {
  windowHeight = winheight();
  scrollPosition = scrollpos();
  objectPosition = document.getElementById(id).offsetTop;
  if ((objectPosition > scrollPosition + windowHeight - margin) || (objectPosition < scrollPosition)) {
    dest = objectPosition - (windowHeight * midfraction);
    if (animate) {
      speed = speedDefault;
      animateScrollToDest();
    } else {
      window.scrollTo(0, dest);
    }
  }
}

function animateScrollToDest() {
  scrollPosition = scrollpos();
  dist = Math.abs(scrollPosition - dest)
  if ((dist <= 1) || (speed <= 1) || (dist < speed)) {
    // turns out that the screwy algorithm below doesn't
    // scroll quite to dest. but it's close enough for now.
    return;
  } else if (scrollPosition < dest) {
    delta = speed;
  } else {
    delta = -speed;
  }
  if (dist < 300) {
    speed = speedDefault - (speedDefault * (300 - dist) / 300.0);
  }
  window.scrollBy(0, delta);
  if (scrollpos() - scrollPosition == 0) {
    // haven't necessarily reached destination, but can't scroll anymore
    // ie, reached top or bottom of page
    return;
  }
  setTimeout("animateScrollToDest()", 10);
}

function inc() {
  newid = "i" + (current + 1);
  success = moveto(newid, true)
  if (success) {
    current += 1;
    setcookie(current);
  } else {
    gonext();
  }
}


function dec() {
  newid = "i" + (current - 1);
  success = moveto(newid, true)
  if (success) {
    current -= 1;
    setcookie(current);
  } else {
    goprev();
  }
}


function followlink(id) {
  e = document.getElementById(id);
  if ((e != null) && (e.href != null)) {
    if (e.href.indexOf("menu_run") != -1) {
      parent.speech.location.href   = e.href;
    }
    else {
      location.href = e.href;
    }
  }
}

function visit(n) {
  m = (parseInt(n) + 1)
  newid = "i" + m;
  success = moveto(newid, true);
  if (success) {
    followlink("a"+m);
  }
}
function go() {
  followlink("a"+current);
}


var allowkeys = "anb/?1234567890";

function getkey(e) {
  if (!keyactive) return true;
  if (e == null) { // ie

    kcode = event.keyCode;
  } else { // mozilla
    if (e.altKey || e.ctrlKey) {
      // moz doesn't override ctrl keys,
      // eg, Ctrl-N won't bypass this function to open new window
      return true;
    }
    kcode = e.which;
  }

  key = String.fromCharCode(kcode).toLowerCase();

// Note: arrow keys do not work here :(
// alert(key + kcode); 

  switch(key) {
    case "l": history.go(-1); return false;
    case ";": dec(); return false;
    case "'": inc(); return false;
    case "\r": go(); return false;  // Enter

    case "1": visit(0); return false;
    case "2": visit(1); return false;
    case "3": visit(2); return false;
    case "4": visit(3); return false;
    case "5": visit(4); return false;
    case "6": visit(5); return false;
    case "7": visit(6); return false;
    case "8": visit(7); return false;
    case "9": visit(8); return false;
    case "0": visit(9); return false;
    case "/": // / = ?
  }
  return true;
}

document.onkeypress = getkey;
