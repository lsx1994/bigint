# bigint  
英文: k,m,t,b,aa,ab,ac...az,ba,bb,bc..zz,aaa...  
中文：万,亿,兆,京...  
支持负数丶小数丶科学计数法(尽量多用单位做计算，不要写太多位数)， 可以修改__tostring的默认保留位数。  
注意，只支持number科学计数法，不支持字符串。  
如果需要保存到数据库， 请写入 unitIndex(int) 和 valueNum(定点数)  

英文模式:  
require("bigint")("EN")  
print(bn("123ab") + bn("312aa"))  
print(bn("123m") - bn("312t"))  
print(bn("123ab") \* bn("312aa"))  
print(bn("123ab") / bn("312aa"))  
print(bn("2k") ^ 3)    
中文模式:  
require("bigint")("CN")  
print(bn("123万") + bn("12亿"))  
...  
