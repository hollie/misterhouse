

#include <sys/time.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <strings.h>
#include <signal.h>
#include <string.h>

#define TRUE 1
#define FALSE 0
#define MAX(x,y) ((x) > (y) ? (x) : (y))

static char buffer[256]; // For error messages
static int    mic_state = 0;


/*----------------------------------------------------*/
/* All of the speech-related things (prototypes,      */
/* data types, etc)                                   */
/*----------------------------------------------------*/
#include <smapi.h>

/*----------------------------------------------------*/
/* A macro to check the return code from various Sm   */
/* calls (makes the code below look cleaner)          */
/*----------------------------------------------------*/
#define CheckSmRC(fn)                                  \
{                                                      \
  int rc;                                              \
                                                       \
  SmGetRc ( reply, & rc );                             \
                                                       \
  sprintf ( buffer, "%s: rc = %d", fn, rc );           \
                                                       \
  LogMessage ( buffer );                               \
                                                       \
  if ( rc != SM_RC_OK ) return ( SM_RC_OK );           \
}


void client_write(int sockfd, char *txt)
{
  write(sockfd,txt,strlen(txt)+1);
}

static void LogMessage ( char * cp )
{
  fprintf ( stderr, "%s\n", cp );
}

void SetButtonLabel ( char * str )
{
  printf ("SetButtonLabel - %s\n",str);
}

void outputRcError(int rc, int sockfd = -1)
{
  char buf[1000];
  sprintf(buf,"Error code %d (%s) - %s",rc,SmReturnRcName(rc),
	  SmReturnRcDescription(rc));
  LogMessage(buf);
  if (sockfd >= 0) {
    client_write(sockfd,buf);
  }

}

static int smapi_socket = 0;
static int (*smapi_fn) (void *) = NULL;
static void * smapi_data = NULL;

static int myNotifier(int socket_handle, int (*recv_fn)(void*),
		      void *recv_data, void *client_data)
{
  smapi_socket = socket_handle;
  smapi_fn     = recv_fn;
  smapi_data   = recv_data;

  return ( 0 );
  
}

int checkSocket(int newsockfd, int secs = -1)
{

  fd_set fds;
  FD_ZERO (&fds);
  FD_SET ((int)newsockfd, &fds);
  if (smapi_socket) {
    FD_SET ( smapi_socket, &fds );
  }
  
  timeval tv;
  tv.tv_sec  = secs;
  tv.tv_usec = 0;

  int ans=select ((int)MAX(newsockfd,smapi_socket) + 1, 
		  &fds, 0, 0, tv.tv_sec >= 0 ? &tv : NULL);

  if (ans <= 0)
    return ans;

  if ( FD_ISSET ( smapi_socket, & fds ) ) {
    // printf ( ">> Incoming message\n" );
    int rc = ( smapi_fn ) ( smapi_data );
    if ( rc != 0 ) {
      printf ( ">>  Return code is %d\n", rc );
    }
  }
  
  if (FD_ISSET(newsockfd, &fds)) {
    return 1;
  }
  return 0;
}

char *getCommand(int newsockfd, char *prompt = NULL)
{
  static char buf[20000];
  static char savedData[20000];
  while(1) {
    int s = -1;
    if (!prompt)
      prompt = "ViaVoice Server>\n"; // bbw add the \n so mh will read the record
    write(newsockfd,prompt, strlen(prompt)+1);

    // printf("Currently have strlen(savedData) %d\n",strlen(savedData));
    if (strlen(savedData) == 0) {
      while ((s =  checkSocket(newsockfd)) <= 0) {
	if (s < 0) {
	  perror("select");
	  return NULL;
	}
	continue;
      }
    }
    
    strcpy(buf,"");
    //memset(buf,0,10000);
    int x = 0;
    if (s >= 0) {
      x = read(newsockfd, buf, 10000);
    }
    if (x <= 0) {
      printf ("No data - %d\n", x);
      if (x < 0) {
        perror("read");
        return NULL;
      }
      if (s > 0) {
        printf("Client socket has closed\n");
        return NULL;
      }
      if (strlen(savedData) == 0)
        continue;
    }
    else {
      // Sometimes it's terminated only with \r, and not with \0??
      // Make sure after the read characters end, we put in a NULL
      buf[x+1] = '\0';
    }
    strcat(savedData,buf);
    //printf ("** buf transformed from %s to %s\n",buf, savedData);
    strcpy(buf,savedData);
    strcpy(savedData,"");

    // printf ("Read in %d bytes\n",x);
    int i;
    /*
      printf ("Read bytes: ");
      for (i=0;i<strlen(buf);i++) {
      printf ("0x%02x ",buf[i]);
      }
      printf("\n");
    */

    // Chop off trailing control chars, like \r, \n
    for (i=0;i<strlen(buf);i++) {
      if (buf[i] < 26) {
	// printf ("Found ctrl char at %d of %d\n",i,buf[i]);
	buf[i] = '\0';
	for (int j=i+1;j<strlen(&(buf[i+1]));j++) {
	  //printf ("Looking at character %d\n",buf[j]);
	  if (buf[j] == '0')
	    break;
	  if (buf[j] < 26)
	    continue;
	  // printf ("**Saving data '%s'\n",&(buf[j]));
	  // At this point, there is more data needed to be saved for later
	  strcpy(savedData, &(buf[j]));
	  break;
	}
	break;
      }
    }

    char msg[256];
    // sprintf(msg,"Received command of '%s'",buf);
    sprintf(msg,"> %s",buf);
    LogMessage(msg);

    return buf;
  }
}

void server_help(int sockfd)
{
  static char *help_str = "Commands must be 1 word at a time, separated by newlines.
  Valid commands are:
       definevocab
       undefinevocab
       addtovocab
       enablevocab
       disablevocab
       micon
       micoff
       quit
";
  write(sockfd,help_str,strlen(help_str)+1);
}

typedef enum {
  VA_Enable,
  VA_Undefine
} VocabActions;



bool vocabAction(int sockfd, VocabActions action = VA_Enable)
{
  char *vocab_name = getCommand(sockfd, "Enter vocabulary name> ");
  if (!vocab_name)
    return FALSE;
  
  SM_MSG reply;
  char *msg = "Unknown action\n";
  switch(action) {
  case VA_Enable:
    SmEnableVocab ( vocab_name, &reply );
    msg = "Vocab is enabled\n";
    break;
  case VA_Undefine:
    SmUndefineVocab ( vocab_name, &reply );
    msg = "Vocab is destroyed\n";
    break;
  }

  int rc;
  SmGetRc(reply,&rc);
  
  if (rc != SM_RC_OK) {
    outputRcError(rc,sockfd);
    return TRUE;
  }
  else {
    client_write(sockfd,msg);
    return TRUE;
  }
}

bool enablevocab(int sockfd)
{
  return vocabAction(sockfd,VA_Enable);
}


bool undefinevocab(int sockfd)
{
  return vocabAction(sockfd,VA_Undefine);
}

bool disablevocab(int sockfd)
{
  char *vocab_name = getCommand(sockfd, "Enter vocabulary name to disable> ");
  if (!vocab_name)
    return FALSE;
  
  SM_MSG reply;
  SmDisableVocab ( vocab_name, &reply );

  int rc;
  SmGetRc(reply,&rc);
  
  if (rc != SM_RC_OK) {
    outputRcError(rc,sockfd);
    return TRUE;
  }
  else {
    client_write(sockfd, "Vocab is disabled\n");
    return TRUE;
  }
}

bool micoff(int sockfd)
{
  SM_MSG reply;
  int rc = SmMicOff ( &reply );
  if (rc != SM_RC_OK) {
    outputRcError(rc,sockfd);
    return TRUE;
  }
  else {
    client_write(sockfd, "Mic is off\n");
  }
  return TRUE;
}

bool micon(int sockfd)
{
  SM_MSG reply;
  int rc = SmMicOn ( &reply );
  if (rc != SM_RC_OK) {
    outputRcError(rc,sockfd);
    return TRUE;
  }
  else {
    client_write(sockfd, "Mic is on\n");
  }

  rc = SmRecognizeNextWord ( /*&reply*/ SmAsynchronous );
  if (rc != SM_RC_OK) {
    outputRcError(rc,sockfd);
    return TRUE;
  }

  return TRUE;
}


bool definevocab(int sockfd, bool defining = TRUE)
{
  char *vocab_static = getCommand(sockfd,"Enter vocabulary name> ");
  if (!vocab_static) {
    return FALSE;
  }
  char vocab[256];
  strcpy(vocab,vocab_static);

  int numWords = 0;
  const int MAX_PHRASES = 5000;
  SM_VOCWORD   voc_words [ MAX_PHRASES ];

  while (1) {
    char *phrase = getCommand(sockfd, "");
    //   char *phrase = getCommand(sockfd, "Enter a phrase to recognize (hit return when done) >");
    if (!phrase)
      return FALSE;
    
    if (strlen(phrase) == 0) {
      break;
    }

    voc_words [ numWords ].spelling      = strdup(phrase);
    voc_words[numWords].spelling_size = strlen(voc_words[numWords].spelling);
    voc_words [ numWords ].flags         = 0;
    numWords++;
    if (numWords >= MAX_PHRASES) {
      client_write(sockfd,"Vocabulary too big\n");
      return FALSE;
    }
  }


  SM_VOCWORD * voc_ptrs [ numWords ];
  for (int i=0;i<numWords;i++) {
    voc_ptrs[i] = &(voc_words[i]);
  }

  int rc;
  if (defining)
    rc = SmDefineVocab ( vocab, numWords, voc_ptrs, SmAsynchronous );
  else 
    rc = SmAddToVocab ( vocab, numWords, voc_ptrs, SmAsynchronous );

  char buffer[256];
  sprintf ( buffer, "DoSimpleVocab: %s() rc = %d\n", 
	    defining ? "SmDefineVocab" : "SmAddToVocab", rc );
  LogMessage ( buffer );

  if (rc != SM_RC_OK) {
    client_write(sockfd,buffer);
    return FALSE;
  }
  else {
    return TRUE;
  }
}

bool addtovocab(int sockfd)
{
  return definevocab(sockfd,FALSE);
}




bool processClient(int sockfd)
{
  while (1) {
    char *command = getCommand(sockfd);
    
    if (!command) {
      return FALSE;
    }


#define COMMAND(foo)    \
else if (!strcasecmp(command,#foo)) { \
	if (!foo(sockfd)) \
          return FALSE; \
    }

    if (!strcasecmp(command,"help")) {
      server_help(sockfd);
    }
    COMMAND(definevocab)
    COMMAND(addtovocab)
    COMMAND(undefinevocab)
    COMMAND(micon)
    COMMAND(micoff)
    COMMAND(enablevocab)
    COMMAND(disablevocab)
    else if (!strcasecmp(command,"quit") ||
	     !strcasecmp(command,"exit")) {
      return TRUE;
    }
    else {
      char buf[1000];
      sprintf(buf,"Unrecognized one-word command: '%s'\n",command);
      write(sockfd,buf,strlen(buf)+1);
      server_help(sockfd);
    }
  }

  return TRUE;
}

static void ConnectStuff ( )
{
  static int first = TRUE;
  int        rc;
  int        smc;
  SmArg      smargs [ 30 ];
  char       * cp;
  char buffer[256];

  /*-------------------------------------------------------------------*/
  /* These callbacks handle the various messages that the speech       */
  /* engine might be sending back                                      */
  /*-------------------------------------------------------------------*/
  SmHandler ConnectCB     ( SM_MSG reply, void * client, void * call_data );
  SmHandler DisconnectCB  ( SM_MSG reply, void * client, void * call_data );
  SmHandler SetCB         ( SM_MSG reply, void * client, void * call_data );
  SmHandler MicOnCB       ( SM_MSG reply, void * client, void * call_data );
  SmHandler MicOffCB      ( SM_MSG reply, void * client, void * call_data );
  SmHandler DefineVocabCB ( SM_MSG reply, void * client, void * call_data );
  SmHandler EnableVocabCB ( SM_MSG reply, void * client, void * call_data );
  SmHandler GetNextWordCB ( SM_MSG reply, void * client, void * call_data );
  SmHandler RecoWordCB    ( SM_MSG reply, void * client, void * call_data );
  SmHandler UtteranceCB   ( SM_MSG reply, void * client, void * call_data );

  LogMessage ( "ConnectStuff invoked" );

  if ( first )
  {
    smc = 0;
    SmSetArg ( smargs [ smc ], SmNapplicationName,    "Server" ); smc++;
    SmSetArg ( smargs [ smc ], SmNexternalNotifier,  myNotifier); smc++;
    //SmSetArg ( smargs [ smc ], SmNexternalNotifierData,  sockfd); smc++;

    /*-----------------------------------------------------------------*/
    /* The call to SmOpen initializes any data that's inside of libSm  */
    /*-----------------------------------------------------------------*/
    rc = SmOpen ( smc, smargs );

    if ( rc != SM_RC_OK )
    {
      sprintf ( buffer, "SmOpen() failed, rc = %d", rc );

      LogMessage ( buffer );

      return;
    }

    /*-----------------------------------------------------------------*/
    /* Add the callbacks to catch the messages coming back from the    */
    /* reco engine                                                     */
    /*-----------------------------------------------------------------*/
    SmAddCallback ( SmNconnectCallback,             ConnectCB,       NULL );
    SmAddCallback ( SmNdisconnectCallback,          DisconnectCB,    NULL );
    SmAddCallback ( SmNsetCallback,                 SetCB,           NULL );
    SmAddCallback ( SmNmicOnCallback,               MicOnCB,         NULL );
    SmAddCallback ( SmNmicOffCallback,              MicOffCB,        NULL );
    SmAddCallback ( SmNenableVocabCallback,         EnableVocabCB,   NULL );
    SmAddCallback ( SmNdefineVocabCallback,         DefineVocabCB,   NULL );
    SmAddCallback ( SmNrecognizeNextWordCallback,   GetNextWordCB,   NULL );
    SmAddCallback ( SmNrecognizedWordCallback,      RecoWordCB,      NULL );
    SmAddCallback ( SmNutteranceCompletedCallback,  UtteranceCB,     NULL );

    first = FALSE;
  }

  /*-----------------------------------------------------------------*/
  /* Now connect to the engine (asynchronously, which means that     */
  /* the ConnectCB will get the results)                             */
  /*-----------------------------------------------------------------*/
  smc = 0;
  SmSetArg ( smargs [ smc ], SmNuserId,       SM_USE_CURRENT    );  smc++;
  SmSetArg ( smargs [ smc ], SmNenrollId,     SM_USE_CURRENT  );  smc++;
  SmSetArg ( smargs [ smc ], SmNtask,         SM_USE_CURRENT    );  smc++;
  SmSetArg ( smargs [ smc ], SmNrecognize,    TRUE      );  smc++;
  SmSetArg ( smargs [ smc ], SmNoverrideLock, TRUE      );  smc++;

  SM_MSG repl;

  rc = SmConnect ( smc, smargs, &repl );

  sprintf ( buffer, "ConnectStuff: SmConnect() rc = %d, reply %d", rc, repl);

  LogMessage ( buffer );
}


static int theClient = 0;

main()
{
  int sockfd;



  ConnectStuff();

  signal(SIGPIPE,SIG_IGN);
  if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    perror("server socket");

  int val = 1;
  if (setsockopt (sockfd, SOL_SOCKET, SO_REUSEADDR, (char *) &val,
		  sizeof (val)) < 0)
    perror("Server 1 setsockopt");


  struct sockaddr_in serv_addr;

  bzero((char *)&serv_addr, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
  serv_addr.sin_port = htons(3234);
	
  if (bind(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0)
    perror("bind");

  listen(sockfd, 5);

  while (1) {
    struct sockaddr_in cli_addr;

    printf ("Ready to accept connections...\n");
    unsigned int clilen = sizeof(cli_addr);
    int newsockfd = accept(sockfd, (struct sockaddr *)&cli_addr, &clilen);
    if (newsockfd < 0)
      perror("accept");

    printf ("Accepted connection\n");

    theClient = newsockfd;

    processClient(newsockfd);

    printf ("Closing client\n");

    close (newsockfd);
  }
	
}


/*---------------------------------------------------------------------*/
/*        Stolen Callbacks                                             */
/*---------------------------------------------------------------------*/
SmHandler ConnectCB ( SM_MSG reply, void * client, void * call_data )
{
  int    rc;
  char * cp;

  CheckSmRC("ConnectCB");

  /*-------------------------------------------------------------------*/
  /* We got here, so the connect completed, so let's define a vocab    */
  /* and enable the mic button                                         */
  /*-------------------------------------------------------------------*/
  // DoSimpleVocab ( );

  // XtVaSetValues ( hello_button, XmNsensitive, TRUE, NULL );

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler DisconnectCB  ( SM_MSG reply, void * client, void * call_data )
{
  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler SetCB ( SM_MSG reply, void * client, void * call_data )
{
  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler MicOnCB ( SM_MSG reply, void * client, void * call_data )
{
  CheckSmRC("MicOnCB");

  /*-------------------------------------------------------------------*/
  /* The mic got turned on, sp change its label accordingly            */
  /*-------------------------------------------------------------------*/
  SetButtonLabel ( "Mic is On" );

  mic_state = 1;

  /*-------------------------------------------------------------------*/
  /* VERY IMPORTANT - this tells the recognizer to 'go' (ie. start     */
  /* capturing the audio and processing it)                            */
  /*-------------------------------------------------------------------*/
  SM_MSG rep;
  int ans = SmRecognizeNextWord ( &rep );

  printf ("Ans is %d, reply is %d\n",ans, rep);

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler MicOffCB ( SM_MSG reply, void * client, void * call_data )
{
  CheckSmRC("MicOffCB");

  /*-------------------------------------------------------------------*/
  /* Mic's off, just change the button label..                         */
  /*-------------------------------------------------------------------*/
  SetButtonLabel ( "Mic is Off" );

  mic_state = 0;

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler EnableVocabCB ( SM_MSG reply, void * client, void * call_data )
{
  CheckSmRC("EnableVocabCB");

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler DefineVocabCB ( SM_MSG reply, void * client, void * call_data )
{
  char          * vocab;
  int             rc;
  int             i;
  SM_VOCWORD    * missing;
  unsigned long   num_missing;

  CheckSmRC("DefineVocabCB");

  SmGetVocabName ( reply, & vocab );

  sprintf ( buffer, "DefineVocabCB: vocab = %s", vocab );

  LogMessage ( buffer );

  /*-------------------------------------------------------------------*/
  /* Check to see if any of the words from the vocabulary are missing  */
  /* from the recognizers pool(s)                                      */
  /*-------------------------------------------------------------------*/
  rc = SmGetVocWords ( reply, & num_missing, & missing );

  sprintf ( buffer, "DefineVocabCB: There are %d words missing", num_missing );
  LogMessage ( buffer );

  for ( i = 0 ; i < ( int ) num_missing; i++ )
  {
    sprintf ( buffer, "DefineVocabCB: word [ %d ] = '%s'",
              i, missing [ i ].spelling );
    LogMessage ( buffer );
  }

  /*-------------------------------------------------------------------*/
  /* Enable the vocabulary (tells the recognizer to listen for words   */
  /* from it)                                                          */
  /*-------------------------------------------------------------------*/
  SmEnableVocab ( vocab, SmAsynchronous );

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler GetNextWordCB ( SM_MSG reply, void * client, void * call_data )
{
  CheckSmRC("GetNextWordCB");

  /*-------------------------------------------------------------------*/
  /* This gets called whenever SmRecognizeNextWord() is called         */
  /*-------------------------------------------------------------------*/
  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler RecoWordCB ( SM_MSG reply, void * client, void * call_data )
{
  int             rc;
  int             i;
  unsigned long   num_firm;
  SM_WORD       * firm;

  CheckSmRC("NextWordCB");

  /*-------------------------------------------------------------------*/
  /* Get the list of recognized words from the reply message (there    */
  /* should only be one) and 'process' it..                            */
  /*-------------------------------------------------------------------*/

  rc = SmGetFirmWords ( reply, & num_firm, & firm );

  for ( i = 0 ; i < ( int ) num_firm; i++ )
  {
    if (strlen(firm[i].spelling)) {
      //sprintf ( buffer, "RecoWordCB: firm[%d] = '%s' ('%s')\n",
      //i, firm [ i ].spelling, firm [ i ].vocab );
      sprintf ( buffer, "Said: %s\n", firm [ i ].spelling);
      LogMessage ( buffer );
      client_write(theClient, buffer);
    }
    else {
      sprintf ( buffer, "Noise\n");
      LogMessage ( buffer );
      client_write(theClient, buffer);
      sprintf(buffer,"Noise\n");
      // sprintf(buffer,"RecoWordCB: Unrecognized utterance\n");
    }
  }

  /*-------------------------------------------------------------------*/
  /* Tell the recognizer to 'go' again.  It stops so that if we wanted */
  /* to, we could change vocabs...                                     */
  /*-------------------------------------------------------------------*/
  rc = SmRecognizeNextWord ( SmAsynchronous );

  return ( SM_RC_OK );
}


/*---------------------------------------------------------------------*/
/*                                                                     */
/*---------------------------------------------------------------------*/
SmHandler UtteranceCB ( SM_MSG reply, void * client, void * call_data )
{
  LogMessage ( "UtteranceCB\n" );

  /*-------------------------------------------------------------------*/
  /* The engine has turned the mic off and processed all of the audio  */
  /*-------------------------------------------------------------------*/

  return ( SM_RC_OK );
}

