if (time_now '4/9/00 4:00 PM') {
   if (run_voice_cmd q[Hey Mr. Dirty Boy Dudes, remember to take your bath today.  ]) {
      print_log q[Running Outlook command: Hey Mr. Dirty Boy Dudes, remember to take your bath today.  ];
   }
   else {
      speak qq[rooms=all Notice: It is $Time_Now. Hey Mr. Dirty Boy Dudes, remember to take your bath today.  ];
   }
}
                                # Give an early warning of spoken events
if (time_now '4/9/00 4:00 PM - 00:15') {
   unless (run_voice_cmd q[Hey Mr. Dirty Boy Dudes, remember to take your bath today.  ]) {
      speak qq[rooms=all Notice: It is $Time_Now.  In 15 minutes, Hey Mr. Dirty Boy Dudes, remember to take your bath today.  ];
   }
}

if (time_now '4/9/00 6:00 PM') {
   if (run_voice_cmd q[Fiction Reading at Barnes & Noble]) {
      print_log q[Running Outlook command: Fiction Reading at Barnes & Noble];
   }
   else {
      speak qq[rooms=all Notice: It is $Time_Now. Fiction Reading at Barnes & Noble];
   }
}
                                # Give an early warning of spoken events
if (time_now '4/9/00 6:00 PM - 00:15') {
   unless (run_voice_cmd q[Fiction Reading at Barnes & Noble]) {
      speak qq[rooms=all Notice: It is $Time_Now.  In 15 minutes, Fiction Reading at Barnes & Noble];
   }
}

