
    if (time_now '12/11 18:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Jaws";
    }
    if (time_now '12/11 18:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,1,4,RECORD');
    }
#   if (time_now '12/11 19:00 - 00:01') {
    if (time_now '12/11 19:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '12/31 19:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Star Trek Generations";
    }
    if (time_now '12/31 19:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,8,RECORD');
    }
#   if (time_now '12/31 21:00 - 00:01') {
    if (time_now '12/31 21:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '1/10 20:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Ally McBeal";
    }
    if (time_now '1/10 20:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,8,RECORD');
    }
#   if (time_now '1/10 21:00 - 00:01') {
    if (time_now '1/10 21:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '2/05 18:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Joe Kidd";
    }
    if (time_now '2/05 18:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,1,4,RECORD');
    }
#   if (time_now '2/05 19:00 - 00:01') {
    if (time_now '2/05 19:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '2/06 18:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Oscar";
    }
    if (time_now '2/06 18:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,7,RECORD');
    }
#   if (time_now '2/06 20:00 - 00:01') {
    if (time_now '2/06 20:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '2/23 20:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Star Trek: Voyager";
    }
    if (time_now '2/23 20:00') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,9,RECORD');
    }
#   if (time_now '2/23 21:00 - 00:01') {
    if (time_now '2/23 21:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '2/22 20:30 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Dilbert";
    }
    if (time_now '2/22 20:30') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,9,RECORD');
    }
#   if (time_now '2/22 21:00 - 00:01') {
    if (time_now '2/22 21:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '2/22 20:30 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Dilbert";
    }
    if (time_now '2/22 20:30') {
        speak "VCR recording started";
        run('min', 'IR_cmd VCR,0,9,RECORD');
    }
#   if (time_now '2/22 21:00 - 00:01') {
    if (time_now '2/22 21:00') {
        speak "VCR recording stopped";
        run('min', 'IR_cmd VCR,STOP');
    }



    if (time_now '3/08 18:21 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Simpsons";
    }
    if (time_now '4/08 18:25') {
        speak "VCR recording started";
        set $VCR "8,RECORD";
#       run('min', 'IR_cmd VCR,8,RECORD');
    }
#   if (time_now '3/09 19:00 - 00:01') {
    if (time_now '4/08 18:26') {
        speak "VCR recording stopped";
        set $VCR "8,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 19:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for First Knight";
    }
    if (time_now '4/08 19:00') {
        speak "VCR recording started";
        set $VCR "5,RECORD";
#       run('min', 'IR_cmd VCR,5,RECORD');
    }
#   if (time_now '4/08 22:00 - 00:01') {
    if (time_now '4/08 22:00') {
        speak "VCR recording stopped";
        set $VCR "5,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 18:30 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Roger Ebert & the Movies";
    }
    if (time_now '4/08 18:30') {
        speak "VCR recording started";
        set $VCR "5,RECORD";
#       run('min', 'IR_cmd VCR,5,RECORD');
    }
#   if (time_now '4/08 19:00 - 00:01') {
    if (time_now '4/08 19:00') {
        speak "VCR recording stopped";
        set $VCR "5,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 19:30 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Cops";
    }
    if (time_now '4/08 19:30') {
        speak "VCR recording started";
        set $VCR "8,RECORD";
#       run('min', 'IR_cmd VCR,8,RECORD');
    }
#   if (time_now '4/08 20:00 - 00:01') {
    if (time_now '4/08 20:00') {
        speak "VCR recording stopped";
        set $VCR "8,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 20:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for America";
    }
    if (time_now '4/08 20:00') {
        speak "VCR recording started";
        set $VCR "8,RECORD";
#       run('min', 'IR_cmd VCR,8,RECORD');
    }
#   if (time_now '4/08 21:00 - 00:01') {
    if (time_now '4/08 21:00') {
        speak "VCR recording stopped";
        set $VCR "8,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 20:30 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Lyricist Lounge";
    }
    if (time_now '4/08 20:30') {
        speak "VCR recording started";
        set $VCR "33,RECORD";
#       run('min', 'IR_cmd VCR,33,RECORD');
    }
#   if (time_now '4/08 21:00 - 00:01') {
    if (time_now '4/08 21:00') {
        speak "VCR recording stopped";
        set $VCR "33,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }


    if (time_now '4/08 21:00 - 00:02') {
        speak "rooms=all $Time_Now. VCR recording will be started in 2 minutes for Falcone";
    }
    if (time_now '4/08 21:00') {
        speak "VCR recording started";
        set $VCR "3,RECORD";
#       run('min', 'IR_cmd VCR,3,RECORD');
    }
#   if (time_now '4/08 22:00 - 00:01') {
    if (time_now '4/08 22:00') {
        speak "VCR recording stopped";
        set $VCR "3,STOP";
#       run('min', 'IR_cmd VCR,STOP');
    }

