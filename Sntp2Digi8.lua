-- ================ Sntp to Digital8 ����� ================
-- ���ļ�����ΪAnsi����UTF8�ĸ�ʽ��������NodeMCU��������ʾ����
-- ʹ��ESP8266��NodeMCU���ƹ̼������Ӳ��TM1637����ʱ�������
-- ��ʾʱ�䣬��ͨ��WiFi����Уʱ�� 20170713    maidoo@163.com
-- 20181026��v2��֧������3��NTP��������ַ
-- 20181201��v3��֧�����㱨ʱ��������Դ������������
-- =========================================================
local SDA_PIN = 7                   -- to TM1637 SDA Pin
local SCL_PIN = 6                   -- to TM1637 SCL Pin
-- NodeMCU GPIO-IO�������ձ� https://www.bigiot.net/talk/37.html
local ioAlarm = 2                   -- ���㱨ʱ��������IO4
local TZ = 8                        -- ��8��
-- �ļ���������Ҫ��ʱ
local TargetHourlyChime = {7,8,9}
local SntpServer1 = 'ntp.aliyun.com'        -- ������
local SntpServer2 = '2.cn.pool.ntp.org'     -- ������2
local SntpServer3 = '133.100.11.8'          -- �ձ����Դ�ѧ
-- �ϵ��Լ죬�����һ��������򿪷�����
gpio.mode (ioAlarm, gpio.OUTPUT)
gpio.write(ioAlarm, gpio.HIGH)
-- �ϵ����ֱ�۸о����������LED
tm1637 = require('tm1637_clock')
tm1637.init(SCL_PIN, SDA_PIN)
tm1637.write_string("8888")
tm1637.set_brightness(3)            -- ����ֵ1��7����
-- ���ʱ�䣬��ɳ�ʼ���󣬹رշ��������������ټ���ʱ
-- tmr.delay(300)
gpio.write(ioAlarm, gpio.LOW)
-- ---------------------------------------------------------
-- ��SNTP��������ȡ����ʱ��
function getTime()
    sntp.sync({SntpServer1, SntpServer2, SntpServer3},
        function(sec,usec,server)
            -- print('Sync', sec, usec, server)
            -- Sntpͬ���ɹ��󣬻��Զ�����rtctime�ļ�����������ֻҪֱ��get������ʱ�伴��
            local tm = rtctime.epoch2cal(rtctime.get() + TZ*3600)
            print(string.format("Sntp sync to %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
        end,
        function()
            print('sntp.sync() failed!', errid, errmsg)
        end
    )
end
-- ---------------------------------------------------------
-- ��϶�ʱ����ʵ�֡����١������Ĺ���
tmrAlm      = 2     -- ���ö�ʱ��2
t2cnt       = 1
t2target    = 6     -- ��Ϊ6����������9��������3��һ��
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
        gpio.write(ioAlarm, gpio.LOW)  -- IO�������Ч�����º���Ϊ�͵�ƽ
    end
end
-- ---------------------------------------------------------
-- ������㣬��������ʱ�����Ʒ�������ʱ
LastHour        = 25
CurrentHour     = 25
--ChimeTrigged    = 0
-- �ж�val�Ƿ��ڱ�tTable��ĺ���
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
        -- ��⵽59�ֵ�00�ֵ���������
        --ChimeTrigged = 1    -- ���ñ�־����ֹ�ظ�����
        if isInArray(TargetHourlyChime,CurrentHour) then
            -- ������������ʱ
            t2cnt = 1
            tmr.alarm(tmrAlm, 300, 1, function() loopAlarm() end)
        end
    end
    --ChimeTrigged = 0
end
-- ---------------------------------------------------------
-- �ú���ÿ0.5�뱻ִ��һ�Σ�ˢ��ð����˸��������ʱ��������ʾ
local cc = 0
function update_DIGI8()
    if  bit.band(cc, 1) == 0 then
        tm1637.write_byte(0x02,5)           --����ð��
        else tm1637.write_byte(0x00,5) end  --Ϩ��ð��
    cc = cc + 1
    if cc >= 10 then
        cc = 0
        local unixTime = rtctime.get()
        if (unixTime > 169593480) then
            local tm = rtctime.epoch2cal(unixTime + TZ*3600)
            local now1637 = string.format("%2d%02d",  tm["hour"], tm["min"])
            print (now1637, tm["sec"])
            tm1637.write_string(now1637)
            -- ������㣬����ʱ
            doHourlyChimeCheck(tm["hour"], tm["min"])
            -- ÿСʱͬ��һ��ʱ��
            if(unixTime+330 % 3600 < 5) then getTime() end
        end
    end
end
-- ---------------------------------------------------------
print("Initial WIFI client by End-User-Setup....")
enduser_setup.start(
    function()
        tm1637.write_string("----")
        -- �ӳٵȴ�IP��Ч���������Ĵ�ӡ��䣬����NIL��ָ���������λ
        while(wifi.sta.getip()==nil)  do tmr.delay(500) end
        print("Connected as IP address: " .. wifi.sta.getip())
        getTime()
    end,
    function(err, str)
        print("End-User-Setup: Err #" .. err .. ": " .. str)
    end
)
-- ================ Main Program ================
-- ÿ0.5����ˢ��ʱ�ӵ�ð����ʾ
-- ÿ  5����ˢ�·�����ʾ
-- tm1637.write_byte(0x02,5) ����ð��
tmr.alarm(0, 500, 1, function() update_DIGI8() end)
