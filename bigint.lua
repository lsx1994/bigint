--[[
功能: 
英文: k,m,t,b,aa,ab,ac...az,ba,bb,bc..zz,aaa...
中文：万,亿,兆,京...
支持负数丶小数丶科学计数法(尽量多用单位做计算，不要写太多位数)， 可以修改__tostring的默认保留位数
注意，只支持number科学计数法，不支持字符串。
如果需要保存到数据库， 请写入 unitIndex(int) 和 valueNum(定点数)
Email: 407088968@qq.com
Github: https://github.com/lsx1994
create by EOD.LSX
]]--
g_AgentErrorTag = false  --全局错误标记，服务器在处理客户端的消息中出错，需要通知客户端。
--API容错
if not ERROR then
    ERROR = print   
end
--模式定义
local MODE = {
    EN = "EN",
    CN = "CN",
}

bigint = {}             --全局方法
local _mode = nil       --使用的模式 EN CN
local _unit = nil       --大于x进一位
local _unitLen = nil    --单位位数
local _fixed = nil      --固定单位
local _maxGap = nil     --最大相差范围(保留n位小数)

local bigint_ops = {}   --操作符重载
local _maxNumLen = 12   --最大num位数
local _decimal = 26     --单位使用字母二十六进制
local _maxDigit = 4     --最大相差次幂 1000^4
local _infinite = "infinite"        --超出上限了
local _unitMin = string.byte("a")   --最小单位ascii码
local _unitMax = string.byte("z")   --最大单位ascii码

--设置模式
local function _setMode(mode)
    if _mode == mode then return end
    _mode = mode
    if _mode == MODE.CN then
        _unit = 10000
        _fixed = {
            [1]="万",[2]="亿",[3]="兆",[4]="京",[5]="垓",[6]="杼",
            [7]="穰",[8]="沟",[9]="涧",[10]="正",[11]="载",[22]="极",
            [13]="恒河沙",[14]="阿僧祇",[15]="那由它",[16]="不可思议",[17]="无量",[18]="大数",
            ["万"]=1,["亿"]=2,["兆"]=3,["京"]=4,["垓"]=5,["杼"]=6,
            ["穰"]=7,["沟"]=8,["涧"]=9,["正"]=10,["载"]=11,["极"]=12,
            ["恒河沙"]=13,["阿僧祇"]=14,["那由它"]=15,["不可思议"]=16,["无量"]=17,["大数"]=18,
        }
    elseif _mode == MODE.EN then
        _unit = 1000
        _fixed = {[1]="k",[2]="m",[3]="t",[4]="b",k=1,m=2,t=3,b=4}    --固定单位
    end
    _unitLen = string.len(_unit) - 1
    _maxGap = _unit ^ _maxDigit    --最大相差范围(保留9位小数)
end
_setMode(MODE.EN)

--[[
	@desc: 创建
	--@value: 值： 123 "123" "123aa" "123万" (超出的部分自动换算幂)
]]
function bigint.new(value)
    local set = {}
    set.unitIndex = 0
    set.valueNum = 0
    set._isbigint = true
    local t = type(value)
    if t == "number" then
        set.valueNum = value
    elseif t == "string" then
        bigint.StrToBn(set, value)
    elseif t == "table" and value._isbigint then
        set.unitIndex = value.unitIndex
        set.valueNum = value.valueNum
    else
        ERROR("bigint.new type error.", value, t)
    end
    bigint._Trim(set)
    setmetatable(set, bigint_ops)
    return set    
end

--[[
	@desc: 位数裁剪，保留有效小数
	--@obj: 
]]
function bigint._Trim(obj)
    local absV = math.abs(obj.valueNum)
    local strV = tostring(absV)
    local epos = string.find(strV, "e")
    if epos then --科学计数法
        local num = tonumber(string.sub(strV, 1, epos-1))
        local strLen = string.len(strV)
        if string.find(strV, "e+") then
            local pw = tonumber(string.sub(strV, epos+2, strLen))
            local remainder = pw%3
            obj.valueNum = num * 10^remainder
            obj.unitIndex = obj.unitIndex + math.floor(pw/3)
        elseif string.find(strV, "e-") then
            local pw = tonumber(string.sub(strV, epos+2, strLen))
            local remainder = 3-pw%3
            obj.valueNum = num * 10^remainder
            obj.unitIndex = obj.unitIndex - math.ceil(pw/3)
        end
    elseif absV >= _unit then    --升单位
        local len = math.floor((string.len(tostring(math.floor(absV)))-1) / _unitLen) --计算出可以转成多少幂
        obj.valueNum = obj.valueNum / _unit^len
        obj.unitIndex = obj.unitIndex + len
    elseif absV < 1 then    --降单位
        local temp = string.match(strV, ".0+") or "."    --计算出有几个0
        local len = math.ceil((string.len(temp)) / _unitLen)
        obj.valueNum = obj.valueNum * _unit^len
        obj.unitIndex = obj.unitIndex - len
    end
    --保留x位小数
    obj.valueNum = math.floor(obj.valueNum * _maxGap) / _maxGap  
end

--[[
	@desc: 转成number，最多支持12位长度
	--@obj: 
]]
function bigint.BnToNum(obj)
    if obj.unitIndex * _unitLen > _maxNumLen then --超出范围
        ERROR("bigint.BnToNum overflow.")
        g_AgentErrorTag = true
        return _infinite
    end
    return math.floor(obj.valueNum * _unit ^ obj.unitIndex)
end

--[[
	@desc: 转成字符串，只用于渲染
	--@obj: 
	--@digit: 
]]
function bigint.BnToStr(obj, digit)
    local num = obj.valueNum
    if digit then
        --保留指定小数
        num = math.floor(num * digit) / digit
        --无有效小数，直接取整
        local floorNum = math.floor(num)
        if not (floorNum < num) then 
            num = floorNum
        end
    end
    --尝试取固定单位
    local strUnit = ""
    if obj.unitIndex < 0 then   --负次幂
        local absunitIndex = math.abs(obj.unitIndex)
        local len = absunitIndex * _unitLen + 1
        if len > _maxNumLen then --超出范围
            ERROR("bigint.BnToStr overflow 1.")
            g_AgentErrorTag = true
            return _infinite
        end
        num = string.format("%."..len.."f", num * (1/_unit^absunitIndex))
    else    --正次幂
        strUnit = _fixed[obj.unitIndex] or ""
        if strUnit == ""  then
            if _mode == MODE.EN then --中文单位有上限
                local TempIndex = 0
                while obj.unitIndex > 4 do
                    local value = (obj.unitIndex-4) / (_decimal ^ TempIndex) % _decimal
                    if value == 0 then
                        value = 26  --没有余数，字母z
                    end
                    if TempIndex == 1 then  --默认是从aa开始， 所以第二位要+1
                        value = value + 1
                    end
                    if value >= 1 then
                        local ascii = math.floor(value) - 1 + _unitMin
                        if not (ascii >= _unitMin and ascii <= _unitMax) then 
                            ERROR("bigint.BnToStr overflow 2.")
                            g_AgentErrorTag = true
                            return _infinite
                        end
                        strUnit = string.char(ascii)..strUnit
                        TempIndex = TempIndex + 1
                    else
                        break
                    end
                end
            elseif _mode == MODE.CN then
                local maxFixed = #_fixed
                local temp = obj.unitIndex - maxFixed --多余的长度
                num = num * _unit^temp
                strUnit = _fixed[maxFixed]
            end
        end
    end
    return num..strUnit
end

--[[
	@desc: 字符串转幂， 注意默认从aa开始。
	--@obj:
	--@strValue: 
]]
function bigint.StrToBn(obj, strValue)
    obj.valueNum = tonumber(string.match(strValue, "%d+.%d+") or string.match(strValue, "%d+"))  --支持小数点
    if string.sub(strValue, 1, 1) == "-" then
        obj.valueNum = -obj.valueNum
    end
    local strUnit = nil
    if _mode == MODE.EN then
        strUnit = string.match(strValue, "%l+")
    elseif _mode == MODE.CN then
        strUnit = string.match(strValue, "[%z\1-\127\194-\244][\128-\191]+")
    end
    if strUnit then
        obj.unitIndex = _fixed[strUnit] or 0
        if obj.unitIndex == 0 then
            if _mode == MODE.EN then --中文单位有上限
                local maxPow = string.len(strUnit)
                for word in string.gmatch(strUnit, "%a") do
                    maxPow = maxPow - 1
                    local WordByte = string.byte(word)
                    if not (WordByte >= _unitMin and WordByte <= _unitMax) then 
                        ERROR("bigint.StrToBn overflow 1.")
                        g_AgentErrorTag = true
                        return _infinite
                    end
                    obj.unitIndex = obj.unitIndex + (WordByte - _unitMin + 1) * _decimal ^ maxPow
                end
                obj.unitIndex = math.max(1, math.floor(obj.unitIndex-_decimal+4)) --26进制 + kmtb固定4
            elseif _mode == MODE.CN then
                ERROR("bigint.StrToBn overflow 2.")
                g_AgentErrorTag = true
                return _infinite
            end      
        end
    end
end

--[[
	@desc: 统一对象类型
	--@a:
    --@b: 
    --@IsUnifiedPower: 是否统一幂
]]
function bigint_ops._UnifiedType(a, b, IsUnifiedPower)
    if a then
        local aType = type(a)
        if aType == "number" or aType == "string" or (aType == "table" and a._isbigint) then
            a = bigint.new(a)
        else
            ERROR("bigint_ops a type error.", aType) --打印错误堆栈
            return
        end
    end

    if b then
        local bType = type(b)
        if bType == "number" or bType == "string" or (bType == "table" and b._isbigint) then
            b = bigint.new(b)
        else
            ERROR("bigint_ops b type error.", bType) --打印错误堆栈
            return
        end
    end

    if IsUnifiedPower and a and b then
        local power = math.abs(a.unitIndex - b.unitIndex)
        if a.unitIndex > b.unitIndex then
            if power > _maxDigit then --指数差距太大
                b.valueNum = 0
            else
                b.valueNum = b.valueNum / 1000 ^ power
            end
        elseif a.unitIndex < b.unitIndex then
            if power > _maxDigit then --指数差距太大
                a.valueNum = 0
            else
                a.valueNum = a.valueNum / 1000 ^ power
            end
            a.unitIndex = b.unitIndex
        end
    end

    return a,b
end

--[[
	@desc: +加法运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__add(a, b)
    a,b = bigint_ops._UnifiedType(a, b, true) --统一类型和幂

    a.valueNum = a.valueNum + b.valueNum

    bigint._Trim(a)

    return a
end

--[[
	@desc: -减法运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__sub(a, b)
    a,b = bigint_ops._UnifiedType(a, b, true) --统一类型和幂
    
    a.valueNum = a.valueNum - b.valueNum

    bigint._Trim(a)

    return a
end

--[[
	@desc: *乘法运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__mul(a, b)
    if type(b) == "number" and b == 0 then   --乘以 0 = 0
        return bigint.new(0)
    end
    
    a,b = bigint_ops._UnifiedType(a, b)

    a.valueNum = a.valueNum * b.valueNum
    a.unitIndex = a.unitIndex + b.unitIndex

    bigint._Trim(a)

    return a
end

--[[
	@desc: /除法运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__div(a, b)
    if type(b) == "number" and b == 0 then   --0不能做除数
        return bigint.new(0)
    end

    a,b = bigint_ops._UnifiedType(a, b)

    a.valueNum = a.valueNum / b.valueNum
    a.unitIndex = a.unitIndex - b.unitIndex
    
    bigint._Trim(a)

    return a
end

--[[
	@desc: ^幂运算符重载
	--@a:
	--@b: 只能输入number
]]
function bigint_ops.__pow(a, b)
    local bType = type(b)
    if bType == "number" then   
        if b == 0 then  --任何数的0次幂都为1
            return bigint.new(1)
        end
    else    --b是table或者字符串
        b = bigint.BnToNum(bigint_ops._UnifiedType(b))
    end
    
    a = bigint_ops._UnifiedType(a)

    a.unitIndex = a.unitIndex * b
    a.valueNum = a.valueNum ^ b

    bigint._Trim(a)

    return a
end

--[[
	@desc: -相反数运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__unm(a)
    a.valueNum = -a.valueNum
    return a
end

--[[
	@desc: %求余运算符重载
	--@a:
	--@b: 
]]
function bigint_ops.__mod(a, b)
    ERROR("bigint not support mod(%).")
end

--[[
	@desc: 重载字符串连接符, 默认保留1位小数显示
	--@a: 
]]
function bigint_ops.__tostring(obj)
    return bigint.BnToStr(obj, 10)
end

--[[
	@desc: 创建bigint
	--@value: 值： 123 "123" "123aa" "123万" (超出的部分自动换算幂)
]]
bn = bigint.new

--[[
	@desc: bigint 转 string
	--@obj: bigint对象
	--@digit: 保留几位小数，10表示保留1位
]]
bntostring = bigint.BnToStr

--[[
	@desc: bigint 转 number
	--@obj: bigint对象
]]
bntonumber = bigint.BnToNum

return _setMode