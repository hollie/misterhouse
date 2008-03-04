// ----- wc_ss_show.js ----- //

//configure and Load the paths of the images, plus corresponding target links
//slideshowimages()
BufferFill("+")
//slideshowlinks()

//configure the speed of the slideshow, in miliseconds
//var slideshowspeed=2000
//var whichlink=0
//var whichimage=0

// Here we set the initial default framereate
// var sspeed=slideshowspeed

//Then show the splash screen for a second or 2
var splashWait=5000
sstimer=setTimeout("slideit()",splashWait)    

//while ( splashWait > 0 ){
    // do nothing
//}

function slideit(){
//if (splashWait=0) {
    // Check where we are
    if ( readPointer  > MaxBuffer -1){
	BufferFill("+")
	readPointer = 0
    }

    if (readPointer < 0 ){
	BufferFill("-")
	readPointer = MaxBuffer
    }    
    
//    if (whichimage < slideimages.length-1) 
    if ( readPointer < MaxBuffer +1 ) {
	if (( funct != 'back')&&(funct != 'pause')){ 
	    readPointer++
	} 
	if ( (funct == 'back') && (readPointer > 0 ) ) {
	    readPointer--
	}	
	if ( funct == '' ){
	    if ( readPointer + elementPosition < elementTotal - 1  ){ 
		sstimer=setTimeout("slideit()",sspeed)    
	    }
	    
	}
    }
    if ( readPointer + elementPosition < elementTotal   ){ 
	document.images.slide.src=slideimages[readPointer].src
//	document.getElementById('ImgLoad').innerHTML = "Reading  : " +  ( readPointer + myPos -1 ) 
//	document.getElementById('ImgName').innerHTML = document.images.slide.src

    }
    //whichlink=readPointer

//}
//splashWait=0

//document.getElementById('BufLoad').innerHTML = "Buffering: " + writePointer
//document.getElementById('BufName').innerHTML = document.images.hidden.src
	
}


//slideit()
