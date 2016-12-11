#Category=Weather

$weather_monitor = new Ultimeter;

if ($New_Hour) {
    $weather_monitor->set_time;
}

$v_set_weather_time = new Voice_Cmd("Set the time on the weather monitor");

if ( said $v_set_weather_time) {
    $weather_monitor->set_time;
}

$CurrentWindSpeed            = new Weather_Item("CurrentWindSpeed");
$CurrentWindDirection        = new Weather_Item("CurrentWindDirection");
$FiveMinPeakWindSpeed        = new Weather_Item("FiveMinPeakWindSpeed");
$FiveMinPeakWindDirection    = new Weather_Item("FiveMinPeakWindDirection");
$CurrentWindChill            = new Weather_Item("CurrentWindChill");
$CurrentOutdoorTemp          = new Weather_Item("CurrentOutdoorTemp");
$CurrentRain                 = new Weather_Item("CurrentRain");
$CurrentBarometer            = new Weather_Item("CurrentBarometer");
$ThreeHourBarometerChange    = new Weather_Item("ThreeHourBarometerChange");
$CurrentIndoorTemp           = new Weather_Item("CurrentIndoorTemp");
$CurrentOutdoorHumidity      = new Weather_Item("CurrentOutdoorHumidity");
$CurrentIndoorHumidity       = new Weather_Item("CurrentIndoorHumidity");
$CurrentDewPoint             = new Weather_Item("CurrentDewPoint");
$TodayLowWindChill           = new Weather_Item("TodayLowWindChill");
$TodayLowWindChillTime       = new Weather_Item("TodayLowWindChillTime");
$YesterdayLowWindChill       = new Weather_Item("YesterdayLowWindChill");
$YesterdayLowWindChillTime   = new Weather_Item("YesterdayLowWindChillTime");
$LongtermLowWindChillDate    = new Weather_Item("LongtermLowWindChillDate");
$LongtermLowWindChill        = new Weather_Item("LongtermLowWindChill");
$LongtermLowWindChillTime    = new Weather_Item("LongtermLowWindChillTime");
$TodayOutdoorLow             = new Weather_Item("TodayOutdoorLow");
$TodayOutdoorLowTime         = new Weather_Item("TodayOutdoorLowTime");
$YesterdayOutdoorLow         = new Weather_Item("YesterdayOutdoorLow");
$YesterdayOutdoorLowTime     = new Weather_Item("YesterdayOutdoorLowTime");
$LongtermOutdoorLowDate      = new Weather_Item("LongtermOutdoorLowDate");
$LongtermOutdoorLow          = new Weather_Item("LongtermOutdoorLow");
$LongtermOutdoorLowTime      = new Weather_Item("LongtermOutdoorLowTime");
$TodayLowBarometer           = new Weather_Item("TodayLowBarometer");
$TodayLowBarometerTime       = new Weather_Item("TodayLowBarometerTime");
$YesterdayBarometerLow       = new Weather_Item("YesterdayBarometerLow");
$YesterdayBarometerLowTime   = new Weather_Item("YesterdayBarometerLowTime");
$LongtermBarometerLowDate    = new Weather_Item("LongtermBarometerLowDate");
$LongtermBarometerLow        = new Weather_Item("LongtermBarometerLow");
$LongtermBarometerLowTime    = new Weather_Item("LongtermBarometerLowTime");
$TodayIndoorLow              = new Weather_Item("TodayIndoorLow");
$TodayIndoorLowTime          = new Weather_Item("TodayIndoorLowTime");
$YesterdayIndoorLow          = new Weather_Item("YesterdayIndoorLow");
$YesterdayIndoorLowTime      = new Weather_Item("YesterdayIndoorLowTime");
$LongtermIndoorLowDate       = new Weather_Item("LongtermIndoorLowDate");
$LongtermIndoorLow           = new Weather_Item("LongtermIndoorLow");
$LongtermIndoorLowTime       = new Weather_Item("LongtermIndoorLowTime");
$TodayOutdoorLowHumidity     = new Weather_Item("TodayOutdoorLowHumidity");
$TodayOutdoorLowHumidityTime = new Weather_Item("TodayOutdoorLowHumidityTime");
$YesterdayOutdoorLowHumidity = new Weather_Item("YesterdayOutdoorLowHumidity");
$YesterdayOutdoorLowHumidityTime =
  new Weather_Item("YesterdayOutdoorLowHumidityTime");
$LongtermOutdoorLowHumidityDate =
  new Weather_Item("LongtermOutdoorLowHumidityDate");
$LongtermOutdoorLowHumidity = new Weather_Item("LongtermOutdoorLowHumidity");
$LongtermOutdoorLowHumidityTime =
  new Weather_Item("LongtermOutdoorLowHumidityTime");
$TodayWindSpeedPeak         = new Weather_Item("TodayWindSpeedPeak");
$TodayWindSpeedPeakTime     = new Weather_Item("TodayWindSpeedPeakTime");
$YesterdayWindSpeedPeak     = new Weather_Item("YesterdayWindSpeedPeak");
$YesterdayWindSpeedPeakTime = new Weather_Item("YesterdayWindSpeedPeakTime");
$LongtermWindSpeedDate      = new Weather_Item("LongtermWindSpeedPeakDate");
$LongtermWindSpeed          = new Weather_Item("LongtermWindSpeedPeak");
$LongtermWindSpeedTime      = new Weather_Item("LongtermWindSpeedPeakTime");
$TodayOutdoorHigh           = new Weather_Item("TodayOutdoorHigh");
$TodayOutdoorHighTime       = new Weather_Item("TodayOutdoorHighTime");
$YesterdayOutdoorHigh       = new Weather_Item("YesterdayOutdoorHigh");
$YesterdayOutdoorHighTime   = new Weather_Item("YesterdayOutdoorHighTime");
$LongtermOutdoorHighDate    = new Weather_Item("LongtermOutdoorHighDate");
$LongtermOutdoorHigh        = new Weather_Item("LongtermOutdoorHigh");
$LongtermOutdoorHighTime    = new Weather_Item("LongtermOutdoorHighTime");
$TodayBarometerHigh         = new Weather_Item("TodayBarometerHigh");
$TodayBarometerHighTime     = new Weather_Item("TodayBarometerHighTime");
$YesterdayBarometerHigh     = new Weather_Item("YesterdayBarometerHigh");
$YesterdayBarometerHighTime = new Weather_Item("YesterdayBarometerHighTime");
$LongtermBarometerHighDate  = new Weather_Item("LongtermBarometerHighDate");
$LongtermBarometerHigh      = new Weather_Item("LongtermBarometerHigh");
$LongtermBarometerHighTime  = new Weather_Item("LongtermBarometerHighTime");
$TodayIndoorHighTemp        = new Weather_Item("TodayIndoorHighTemp");
$TodayIndoorHighTempTime    = new Weather_Item("TodayIndoorHighTempTime");
$YesterdayIndoorHighTemp    = new Weather_Item("YesterdayIndoorHighTemp");
$YesterdayIndoorHighTime    = new Weather_Item("YesterdayIndoorHighTime");
$LongtermIndoorHighDate     = new Weather_Item("LongtermIndoorHighDate");
$LongtermIndoorHigh         = new Weather_Item("LongtermIndoorHigh");
$LongtermIndoorHighTime     = new Weather_Item("LongtermIndoorHighTime");
$TodayOutdoorHighHumidity   = new Weather_Item("TodayOutdoorHighHumidity");
$TodayOutdoorHighHumidityTime =
  new Weather_Item("TodayOutdoorHighHumidityTime");
$YesterdayOutdoorHighHumidity =
  new Weather_Item("YesterdayOutdoorHighHumidity");
$YesterdayOutdoorHighHumidityTime =
  new Weather_Item("YesterdayOutdoorHighHumidityTime");
$LongtermOutdoorHighHumidityDate =
  new Weather_Item("LongtermOutdoorHighHumidityDate");
$LongtermOutdoorHighHumidity = new Weather_Item("LongtermOutdoorHighHumidity");
$LongtermOutdoorHighHumidityTime =
  new Weather_Item("LongtermOutdoorHighHumidityTime");
$YesterdayRain              = new Weather_Item("YesterdayRain");
$LongtermRainDate           = new Weather_Item("LongtermRainDate");
$LongtermRainTotal          = new Weather_Item("LongtermRainTotal");
$YesterdayHighWindDirection = new Weather_Item("YesterdayHighWindDirection");
$TodayHighWindDirection     = new Weather_Item("TodayHighWindDirection");
$LongtermHighWindDirection  = new Weather_Item("LongtermHighWindDirection");
$OneMinWindSpeedAverage     = new Weather_Item("OneMinWindSpeedAverage");
$TodayAirQualityIndex       = new Weather_Item("TodayAirQualityIndex");
