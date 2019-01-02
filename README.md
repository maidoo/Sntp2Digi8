# Sntp2Digi8
Make SNTP sync by NodeMCU(ESP8266) to TM1637-drived digital 8 display.

-- 本文件保存为Ansi而非UTF8的格式，可以在NodeMCU上正常显示中文
把Sntp2Digi8.lua改名为init.lua，和tm1637.lua这两个文件一起下载到NodeMCU里，就可以运行里。

-- 使用ESP8266灌NodeMCU定制固件，配合硬件TM1637驱动时钟数码管
-- 显示时间，可通过WiFi联网校时。 20170713    maidoo@163.com
-- 20181026，v2，支持设置3个NTP服务器地址
-- 20181201，v3，支持整点报时，驱动有源蜂鸣器叫两声


参见 金叔制作的3面全显示电子钟
http://bbs.mydigit.cn/read.php?tid=2627177&page=1
 
NodeMCU 需要支持的Module，定制固件：
https://nodemcu-build.com/faq.php
 
