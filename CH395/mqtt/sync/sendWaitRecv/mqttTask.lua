--- 模块功能：MQTT客户端处理框架
-- @author openLuat
-- @module mqtt.mqttTask
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.28

module(...,package.seeall)

require"misc"
require"mqtt"
require"mqttOutMsg"
require"mqttInMsg"
require"http"
require 'pins'
local ready = false

--- MQTT连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage mqttTask.isReady()
function isReady()
    return ready
end
local date = {
    mode = 1, -- 1表示客户端；2表示服务器；默认为1
    intPin = pio.P0_22, -- 以太网芯片中断通知引脚
    rstPin = pio.P0_21, -- 复位以太网芯片引脚
    powerFunc=function ( state )
        if state then
            local setGpioFnc_TX = pins.setup(pio.P0_7, 0)
            pmd.ldoset(15, pmd.LDO_VMMC)
        else
            pmd.ldoset(0, pmd.LDO_VMMC)
            local setGpioFnc_TX = pins.setup(pio.P0_7, 1)
        end
    end,
    spi = {spi.SPI_1, 0, 0, 8, 800000} -- SPI通道参数，id,cpha,cpol,dataBits,clock，默认spi.SPI_1,0,0,8,800000
}

--启动MQTT客户端任务
sys.taskInit(
    function()
        local retryConnectCnt = 0
        link.openNetwork(link.CH395, date)
        while true do
            if not socket.isReady() then
                retryConnectCnt = 0
                --等待网络环境准备就绪，超时时间是5分钟
                sys.waitUntil("IP_READY_IND",300000)
            end
            
            if socket.isReady() then
                local imei = misc.getImei()
                --创建一个MQTT客户端
                local mqttClient = mqtt.client(imei,600,"user","password")
                --阻塞执行MQTT CONNECT动作，直至成功
                --如果使用ssl连接，打开mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})，根据自己的需求配置
                --mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp_ssl",{caCert="ca.crt"})
                if mqttClient:connect("lbsmqtt.airm2m.com",1884,"tcp") then
                    log.info('mqtt连接')
                    retryConnectCnt = 0
                    ready = true
                    --订阅主题
                    if mqttClient:subscribe({["/event0"]=0, ["/中文event1"]=1}) then
                        mqttOutMsg.init()
                        --循环处理接收和发送的数据
                        while true do
                            if not mqttInMsg.proc(mqttClient) then log.error("mqttTask.mqttInMsg.proc error") break end
                            if not mqttOutMsg.proc(mqttClient) then log.error("mqttTask.mqttOutMsg proc error") break end
                        end
                        mqttOutMsg.unInit()
                    end
                    ready = false
                else
                    retryConnectCnt = retryConnectCnt+1
                end
                --断开MQTT连接
                log.info('mqtt关闭')
                mqttClient:disconnect()
                if retryConnectCnt>=5 then link.shut() retryConnectCnt=0 end
                sys.wait(5000)
            else
                link.closeNetWork()
                sys.wait(20000)
                link.openNetwork(link.CH395, date)

            end
        end
    end
)



local function cbFncFile(result,prompt,head,filePath)
    log.info("testHttp.cbFncFile",result,prompt,filePath)
    if result and head then
        for k,v in pairs(head) do
            log.info("testHttp.cbFncFile",k..": "..v)
        end
    end
    if result and filePath then
        local size = io.fileSize(filePath)
        log.info("testHttp.cbFncFile","fileSize="..size)
        
        --输出文件内容，如果文件太大，一次性读出文件内容可能会造成内存不足，分次读出可以避免此问题
        if size<=4096 then
            log.info("testHttp.cbFncFile",io.readFile(filePath))
        else
			
        end
    end
    --文件使用完之后，如果以后不再用到，需要自行删除
    if filePath then os.remove(filePath) end
end

-- sys.taskInit(function (  )
--     while true do
--         sys.wait(30000)
--         log.info('开始下载')
--         http.request("GET","http://cdn.openluat-luatcommunity.openluat.com/attachment/20211208190511374_1.zip",nil,nil,nil,30000,cbFncFile,"123.zip")
--         sys.wait(30000)
--     end
-- end)
sys.timerLoopStart(function ()
    log.info("打印占用的内存:", _G.collectgarbage("count"))
end,5000)