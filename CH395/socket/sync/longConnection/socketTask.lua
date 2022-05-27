--- 模块功能：socket长连接功能测试.
-- 与服务器连接成功后
--
-- 每隔10秒钟发送一次"heart data\r\n"字符串到服务器
--
-- 每隔20秒钟发送一次"location data\r\n"字符串到服务器
--
-- 与服务器断开连接后，会自动重连
-- @author openLuat
-- @module socketLongConnection.testSocket1
-- @license MIT
-- @copyright openLuat
-- @release 2018.03.27
module(..., package.seeall)
require "link"
require "socket"
require "socketOutMsg"
require "socketInMsg"
require "http"
local ready = false

--- socket连接是否处于激活状态
-- @return 激活状态返回true，非激活状态返回false
-- @usage socketTask.isReady()
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

-- 启动socket客户端任务
sys.taskInit(function()
    local retryConnectCnt = 0

    sys.wait(6000)
    link.openNetwork(link.CH395, date)
    while true do
        if not socket.isReady() then
            retryConnectCnt = 0
            -- 等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND", 300000)
        end
        if socket.isReady() then
            -- 创建一个socket tcp客户端
            local socketClient = socket.udp()
            -- 阻塞执行socket connect动作，直至成功
            if socketClient:connect("112.125.89.8", "34467") then
                retryConnectCnt = 0
                ready = true

                socketOutMsg.init()
                -- 循环处理接收和发送的数据
                while true   do
                    if not socketInMsg.proc(socketClient) then
                        log.error("socketTask.socketInMsg.proc error")
                        break
                    end
                    if not socketOutMsg.proc(socketClient) then
                        log.error("socketTask.socketOutMsg proc error")
                        break
                    end
                end
                socketOutMsg.unInit()

                ready = false
            else
                retryConnectCnt = retryConnectCnt + 1
            end
            -- 断开socket连接
            log.info('socket close')
            socketClient:close()
            if retryConnectCnt >= 5 then
                link.shut()
                retryConnectCnt = 0
            end
            sys.wait(5000)
        else
            link.closeNetWork()
            sys.wait(20000)
            link.openNetwork(link.CH395, date)
        end
    end
end)



-- sys.taskInit(function (  )
--     while true do
--         sys.wait(30000)
--         log.info('开始下载')
--         http.request("GET","http://cdn.openluat-luatcommunity.openluat.com/attachment/20211208190511374_1.zip",nil,nil,nil,30000,cbFncFile,"123.zip")
--         sys.wait(60000)
--     end
-- end)

sys.timerLoopStart(function ()
    log.info("打印占用的内存:", _G.collectgarbage("count"))
end,5000)
