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
local sign = true
sys.taskInit(function()
    local retryConnectCnt = 0
    -- 打开链路层网络类型
    sys.wait(5000)
    link.openNetwork(link.CH395, date)
    while true do
        if not socket.isReady() then
            retryConnectCnt = 0
            -- 等待网络环境准备就绪，超时时间是5分钟
            sys.waitUntil("IP_READY_IND", 300000)
        end
        if socket.isReady() then
            -- 创建一个socket tcp客户端
            local socketClient = socket.tcp()
            -- 阻塞执行socket connect动作，直至成功
            if socketClient:connect("112.125.89.8", "35648") then
                retryConnectCnt = 0
                ready = true

                socketOutMsg.init()
                -- 循环处理接收和发送的数据
                while true do
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


---测试关闭模块后再开启效果
-- sys.taskInit(function ()
--         sys.wait(30000)
--         link.closeNetWork(true)
--         -- 打开链路层网络类型
--         sys.wait(20000)
--         link.closeNetWork(false)
-- end)

--以太网模式切换4G模式
sys.taskInit(function ( )
    local num=false
    while true do
        sys.wait(120000)
        if num then
            log.info('CH395')
            link.openNetwork(link.CH395, date)
            num=false
        else
            log.info('4G')
            link.openNetwork(link.CELLULAR)
            num=true
        end
    end
end)
