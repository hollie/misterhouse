<?
   $conn = mysql_connect("localhost","USER","PASS");

   $query = "SELECT name, number, local_datetime as timestamp
             FROM calls
             ORDER BY timestamp desc
             LIMIT 15;";

   $result = mysql_db_query("callerid", $query, $conn);

   echo mysql_error();

   $playlist = "false";

   if (mysql_num_rows($result) > 0)
   {
      echo "<center>\n";

      echo "<table width=\"100%\" border=0 cellpadding=3>\n";

      while ($row = mysql_fetch_object($result))
      {

         if (date("d.m.Y", $row->timestamp) == date("d.m.Y", time()))
         {
            $today = "<strong>";
            $todayend = "</strong>";
         }
         else
         {
            $today = "";
            $todayend = "";
         }

         echo "\t<tr valign=top >\n";

         echo "\t\t\t<td align=\"LEFT\">$today$row->name$todayend</td>\n";

         if (strlen($row->number) > 1)
         {
            echo "\t\t\t<td align=\"CENTER\">$today(".$row->number[0].$row->number[1].$row->number[2].")";
            echo " ".$row->number[3].$row->number[4].$row->number[5]."-";
            echo $row->number[6].$row->number[7].$row->number[8].$row->number[9]."$todayend</td>\n";
         }
         else
         {
            echo "\t\t\t<td align=\"CENTER\">Not Available</td>\n";
         }

         echo "\t\t\t<td align=\"CENTER\">$today".date("h:i a", $row->timestamp)."$todayend</td>\n";

         echo "\t\t\t<td align=\"RIGHT\">$today".date("D M j, Y", $row->timestamp)."$todayend</td>\n";

         echo "\t</tr>\n";
      }
      echo "</table>\n";

      echo "</center>\n";
   }
?>
