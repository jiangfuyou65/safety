-- 必须在这个位置定义PROJECT和VERSION变量
-- PROJECT：ascii string类型，可以随便定义，只要不使用,就行
-- VERSION：ascii string类型，如果使用Luat物联云平台固件升级的功能，必须按照"X.X.X"定义，X表示1位数字；否则可随便定义
PROJECT = "LUAT_IOT_SERVER_UPDATE"
VERSION = "1.0.0"

--[[
使用Luat物联云平台固件升级的功能，必须按照以下步骤操作：
1、打开Luat物联云平台前端页面：https://iot.openluat.com/
2、如果没有用户名，注册用户
3、注册用户之后，如果没有对应的项目，创建一个新项目
4、进入对应的项目，点击左边的项目信息，右边会出现信息内容，找到ProductKey：把ProductKey的内容，赋值给PRODUCT_KEY变量
]]
PRODUCT_KEY = "jeEtlN6q5kQe474XsfSJ9XBc6Zy3jVD6"

-- 加载日志功能模块，并且设置日志输出等级
-- 如果关闭调用log模块接口输出的日志，等级设置为log.LOG_SILENT即可
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE
--[[
如果使用UART输出日志，打开这行注释的代码"--log.openTrace(true,1,115200)"即可，根据自己的需求修改此接口的参数
如果要彻底关闭脚本中的输出日志（包括调用log模块接口和Lua标准print接口输出的日志），执行log.openTrace(false,第二个参数跟调用openTrace接口打开日志的第二个参数相同)，例如：
1、没有调用过sys.opntrace配置日志输出端口或者最后一次是调用log.openTrace(true,nil,921600)配置日志输出端口，此时要关闭输出日志，直接调用log.openTrace(false)即可
2、最后一次是调用log.openTrace(true,1,115200)配置日志输出端口，此时要关闭输出日志，直接调用log.openTrace(false,1)即可
]]
-- log.openTrace(true,1,115200)

require "sys"

require "net"
-- 每1分钟查询一次GSM信号强度
-- 每1分钟查询一次基站信息
net.startQueryAll(60000, 60000)

-- 此处关闭RNDIS网卡功能
-- 否则，模块通过USB连接电脑后，会在电脑的网络适配器中枚举一个RNDIS网卡，电脑默认使用此网卡上网，导致模块使用的sim卡流量流失
-- 如果项目中需要打开此功能，把ril.request("AT+RNDISCALL=0,1")修改为ril.request("AT+RNDISCALL=1,1")即可
-- 注意：core固件：V0030以及之后的版本、V3028以及之后的版本，才以稳定地支持此功能
ril.request("AT+RNDISCALL=0,1")

-- 加载控制台调试功能模块（此处代码配置的是uart2，波特率115200）
-- 此功能模块不是必须的，根据项目需求决定是否加载
-- 使用时注意：控制台使用的uart不要和其他功能使用的uart冲突
-- 使用说明参考demo/console下的《console功能使用说明.docx》
-- require "console"
-- console.setup(2, 115200)

-- 加载网络指示灯和LTE指示灯功能模块
-- 根据自己的项目需求和硬件配置决定：1、是否加载此功能模块；2、配置指示灯引脚
-- 合宙官方出售的Air720U开发板上的网络指示灯引脚为pio.P0_1，LTE指示灯引脚为pio.P0_4
require 'pins'
require "netLed"
pmd.ldoset(2, pmd.LDO_VLCD)
netLed.setup(true, pio.P0_1, pio.P0_4)
-- 网络指示灯功能模块中，默认配置了各种工作状态下指示灯的闪烁规律，参考netLed.lua中ledBlinkTime配置的默认值
-- 如果默认值满足不了需求，此处调用netLed.updateBlinkTime去配置闪烁时长
-- LTE指示灯功能模块中，配置的是注册上4G网络，灯就常亮，其余任何状态灯都会熄灭

-- 加载错误日志管理功能模块【强烈建议打开此功能】
-- 如下2行代码，只是简单的演示如何使用errDump功能，详情参考errDump的api
require "errDump"
errDump.request("udp://ota.airm2m.com:9072")
require "socketCh395"
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
sys.taskInit(function(...)
    link.openNetwork(link.CH395, date)
end)
-- 加载远程升级功能测试模块
require "testUpdate"

-- 启动系统框架
sys.init(0, 0)
sys.run()