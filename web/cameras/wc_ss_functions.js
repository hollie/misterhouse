//  --- wc_ss_functions.js --- 

var slideimages=new Array()
var slidelinks=new Array()
var sspeed = slideshowspeed
//var funct = ''			// function placeholder, set on function select

function slideshowimages(){
//    for (i=0;i<ssimages.length;i++) {
//        document.write("ssimages >> " + i + ssimages[i] +"<br>")
//    }
    
    //slideimages[0]=new Image()
    //slideimages[0].src="/cam/cams-bg.jpg"
//    ssPause()
    for (i=0;i<ssimages.length;i++){
	slideimages[i]=new Image()
        slideimages[i].src=ssimages[i]
	// document.getElementByID("PicLoad").innerHTML = i
    }
//    ssPlay()
}

function slideshowlinks(){
    for (i=0;i<sslinks.length;i++){
	slidelinks[i]=sslinks[i]
    }
}

function gotoshow(){
    if (!window.winslide||winslide.closed)
	winslide=window.open(slidelinks[readPointer])
    else
	winslide.location=slidelinks[readPointer]
    
    winslide.focus()
}

// ----- Player Functions ----- //

function ssPause(){
    funct = 'pause'
    clearTimeout(sstimer)
    clearTimeout(sstimer)
    //ssUpdate()
}

function ssPlay(){
    ssPause()		//because the timers can get tooo fast
    funct = ''
    if (readPointer > 0)
        readPointer--

    //ssUpdate()
    // Reset the speed back to default
    sspeed=slideshowspeed
    sstimer=setTimeout("slideit()",sspeed)    
    //bufferCheck(readPointer,"")
}

function ssBack(){
    ssPause()
    funct = 'back'
//    if (readPointer > 1 ){
//        readPointer--
//    }
    //BufferCheck("-")
    slideit()
    //ssUpdate()    
}

function ssSkBack(){
    funct=''
    readPointer=0
    elementPosition = elementPosition - MaxBuffer
    if (elementPosition < 0){
	elementPosition = 0  // coule be MaxBuffer
    }
    BufferFill("+")
    slideit()
}

function ssSkBk2(){
    ssPause()
    funct=''
    readPointer=0
    elementPosition = elementPosition - ( 2* MaxBuffer )
    if (elementPosition < 0){
	elementPosition = 0  // coule be MaxBuffer
    }
    BufferFill("+")
    ssPlay()
    //ssSkBack()    
}

function ssRewind(){
    ssPause()
    funct = 'rew'
    readPointer=0
    elementPosition = 0
    BufferFill("+")
    //bufferCheck(readPointer,"")
    ssPlay()    
}

function ssUpdate(){
//    document.images.slide.src=slideimages[readPointer].src
//    whichlink=readPointer
    slideit()
}

function ssEnd(){
    funct = ''
    readPointer = 0
    writePointer = 0
    elementPosition = ( elementTotal -  MaxBuffer )
    if ( elementPosition < elementTotal ){
	BufferFill("+")
    }
    //ssUpdate()
    ssPlay()
    //sspeed=slideshowspeed
    //sstimer=setTimeout("slideit()",slideshowspeed)    
    //bufferCheck(readPointer,"-")
    //ssUpdate()
}

function ssFast(){
    ssPause()
    funct = ''
    sspeed=slideshowspeed / 1.5
    sstimer=setTimeout("slideit()",sspeed)    
    slideit()
}

function ssSkFwd(){
    funct = ''
    elementPosition = elementPosition + MaxBuffer
    if ( elementPosition < elementTotal ){
	BufferFill("+")
    }
    readPointer = 0
    writePointer = 0
//    BufferFill("+")
    //ssUpdate()
    ssPlay()
}

function ssFrame(){
    ssPause()
    funct = 'frame'
//    readPointer++
//    if (readPointer >= ssimages.length) {
//	readPointer=ssimages.length - 1
//    }
//    BufferCheck("+")
//    ssUpdate()    
    slideit()
}

function ssClose(){
    ssPause()
    // try releasing the arrays, thus memory
    slideimages=null
    slidelinks=null
    ssimages=null
    sslinks=null
    //window.opener='x'
    window.close()
}