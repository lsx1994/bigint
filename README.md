# bigint  
英文: k,m,t,b,aa,ab,ac...az,ba,bb,bc..zz,aaa...  
中文：万,亿,兆,京...  
支持负数丶小数丶科学计数法(尽量多用单位做计算，不要写太多位数)， 可以修改__tostring的默认保留位数    

如果需要保存到数据库， 请写入 unitIndex(int) 和 valueNum(double)

test:  
require("bigint")    

local a = bn("100aa")  
local b = bn("10b")    

local value = nil  
value = a\*b  
print("a\*b", value)  
value = a/b  
print("a/b", value)  
value = a+b  
print("a+b", value)  
value = a-b  
print("a-b", value)  
value = a^10  
print("a^10", value)  
