
var current = -1;
var currentid = "INVALID"; 

function setcookie(i) {
  document.cookie = "kb=" + i;
}

function load() {
  cookie = document.cookie;
//alert(cookie);
  i = cookie.indexOf("kb=")
  if (i  == -1) {
     current = 1;
  }
  else {
     current = parseInt(cookie.substring(i + 3));
  }
  if (current > last_key) {
     current = last_key;
  }
//alert(current);
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
    currentid = id;
    return true;
  } else {
    // id doesn't exist; cancel move
    return false;
  }
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
// If we are doing menu_run AND it is not a hr (html response) request, put into speech frame
    if (e.href.indexOf("menu_run") != -1 &&
        e.href.indexOf(",hr") == -1) {
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

function getkey(e) {
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
