-- ================ Sntp to Digital8 数码管 ================
-- 本文件保存为Ansi而非UTF8的格式，可以在NodeMCU上正常显示中文
-- 使用ESP8266灌NodeMCU定制固件，配合硬件TM1637驱动时钟数码管
-- 显示时间，可通过WiFi联网校时。 20170713    maidoo@163.com
-- 20181026，v2，支持设置3个NTP服务器地址
-- 20181201，v3，支持整点报时，驱动有源蜂鸣器叫两声
-- =========================================================
local SDA_PIN = 7                   -- to TM1637 SDA Pin
local SCL_PIN = 6                   -- to TM1637 SCL Pin
-- NodeMCU GPIO-IO索引对照表 https://www.bigiot.net/talk/37.html
local ioAlarm = 2                   -- 整点报时蜂鸣器在IO4
local TZ = 8                        -- 东8区
-- 哪几个整点需要报时
local TargetHourlyChime = {7,8,9}
local SntpServer1 = 'ntp.aliyun.com'        -- 阿里云
local SntpServer2 = '2.cn.pool.ntp.org'     -- 服务器2
local SntpServer3 = '133.100.11.8'          -- 日本福冈大学
-- 上电自检，立马叫一声，这里打开蜂鸣器
gpio.mode (ioAlarm, gpio.OUTPUT)
gpio.write(ioAlarm, gpio.HIGH)
-- 上电得有直观感觉，立马点亮LED
tm1637 = require('tm1637_clock')
tm1637.init(SCL_PIN, SDA_PIN)
tm1637.write_string("8888")
tm1637.set_brightness(3)            -- 亮度值1～7递增
-- 差不多时间，完成初始化后，关闭蜂鸣器。不够长再加延时
-- tmr.delay(300)
gpio.write(ioAlarm, gpio.LOW)
-- ---------------------------------------------------------
-- 从SNTP服务器获取网络时间
function getTime()
    sntp.sync({SntpServer1, SntpServer2, SntpServer3},
        function(sec,usec,server)
            -- print('Sync', sec, usec, server)
            -- Sntp同步成功后，会自动设置rtctime的计数器，这里只要直接get计数器时间即可
            local tm = rtctime.epoch2cal(rtctime.get() + TZ*3600)
            print(string.format("Sntp sync to %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
        end,
        function()
            print('sntp.sync() failed!', errid, errmsg)
        end
    )
end
-- ---------------------------------------------------------
-- 配合定时器，实现“哔哔”两声的功能
tmrAlm      = 2     -- 利用定时器2
t2cnt       = 1
t2target    = 6     -- 设为6，叫两声；9叫三声；3叫一声
local function loopAlarm()
    if t2cnt <= t2target then
        if 1 == (t2cnt % 3) then
            gpio.write(ioAlarm, gpio.HIGH)
        else
            gpio.write(ioAlarm, gpio.LOW)
        end
        t2cnt = t2cnt + 1
    else
        tmr.stop(tmrAlm)
        gpio.write(ioAlarm, gpio.LOW)  -- IO输出高有效，完事后设为低电平
    end
end
-- ---------------------------------------------------------
-- 检测整点，并触发定时器控制蜂鸣器报时
LastHour        = 25
CurrentHour     = 25
--ChimeTrigged    = 0
-- 判断val是否在表tTable里的函数
function isInArray(tTable, val)
    for _, v in ipairs(tTable) do
        if v == val then  return true  end
    end
    return false
end
function doHourlyChimeCheck (hh, mm)
    LastHour = CurrentHour
    CurrentHour = hh
    if ((CurrentHour ~= LastHour) and (mm==0)) then
        -- 检测到59分到00分的整点跳变
        --ChimeTrigged = 1    -- 设置标志，防止重复触发
        if isInArray(TargetHourlyChime,CurrentHour) then
            -- 触发蜂鸣器报时
            t2cnt = 1
            tmr.alarm(tmrAlm, 300, 1, function() loopAlarm() end)
        end
    end
    --ChimeTrigged = 0
end
-- ---------------------------------------------------------
-- 该函数每0.5秒被执行一次，刷新冒号闪烁，及整个时钟数字显示
local cc = 0
function update_DIGI8()
    if  bit.band(cc, 1) == 0 then
        tm1637.write_byte(0x02,5)           --点亮冒号
        else tm1637.write_byte(0x00,5) end  --熄灭冒号
    cc = cc + 1
    if cc >= 10 then
        cc = 0
        local unixTime = rtctime.get()
        if (unixTime > 169593480) then
            local tm = rtctime.epoch2cal(unixTime + TZ*3600)
            local now1637 = string.format("%2d%02d",  tm["hour"], tm["min"])
            print (now1637, tm["sec"])
            tm1637.write_string(now1637)
            -- 检测整点，并报时
            doHourlyChimeCheck(tm["hour"], tm["min"])
            -- 每小时同步一次时间
            if(unixTime+330 % 3600 < 5) then getTime() end
        end
    end
end
-- ---------------------------------------------------------
print("Initial WIFI client by End-User-Setup....")
enduser_setup.start(
    function()
        tm1637.write_string("----")
        -- 延迟等待IP有效，否则后面的打印语句，访问NIL空指针会引发复位
        while(wifi.sta.getip()==nil)  do tmr.delay(500) end
        print("Connected as IP address: " .. wifi.sta.getip())
        getTime()
    end,
    function(err, str)
        print("End-User-Setup: Err #" .. err .. ": " .. str)
    end
)
-- ================ Main Program ================
-- 每0.5秒钟刷新时钟的冒号显示
-- 每  5秒钟刷新分秒显示
-- tm1637.write_byte(0x02,5) 点亮冒号
tmr.alarm(0, 500, 1, function() update_DIGI8() end)
