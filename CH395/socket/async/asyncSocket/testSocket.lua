--- testSocket
-- @module asyncSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)
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

-- 此处的IP和端口请填上你自己的socket服务器和端口
local ip, port, c = "112.125.89.8", "37743"

-- 异步接口演示代码
local asyncClient
sys.taskInit(function()
    sys.wait(3000)
    link.openNetwork(link.CH395, date)
    while true do
        while not socket.isReady() do sys.wait(1000) end
        asyncClient = socket.tcp()
        while not asyncClient:connect(ip, port) do sys.wait(2000) end
        while asyncClient:asyncSelect() do end
        asyncClient:close()
    end
end)

-- 测试代码,用于发送消息给socket
sys.taskInit(function()
    while not socket.isReady() do sys.wait(2000) end
    sys.wait(10000)
    -- 这是演示用异步接口发送数据
    for i = 1, 10 do
        asyncClient:asyncSend(string.rep("0123456789", 1024))
        sys.wait(500)
    end
end)

-- 测试代码,用于从socket接收消息
sys.taskInit(function()
    local cnt = 0
    while not socket.isReady() do sys.wait(2000) end
    sys.wait(10000)
    -- 这是演示用异步接口直接读取服务器数据
    while true do
        local data = asyncClient:asyncRecv()
        cnt = cnt + #data
        log.info("这是服务器下发数据:", cnt, data:sub(1, 30))
        sys.wait(1000)
    end
end)

-- sys.timerLoopStart(function()
--     log.info("打印占用的内存:", _G.collectgarbage("count"))-- 打印占用的RAM
--     log.info("打印可用的空间", rtos.get_fs_free_size())-- 打印剩余FALSH，单位Byte
-- end, 1000)
