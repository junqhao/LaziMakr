//
//  SourceEditorCommand.m
//  LazyMaker
//
//  Created by haojunqing on 2021/1/13.
//

#import "SourceEditorCommand.h"

@interface SourceEditorCommand ()
@property (nonatomic, strong) XCSourceEditorCommandInvocation *invocation;
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *inputLines; //输入行信息
@end

@implementation SourceEditorCommand

-(instancetype)init{
    if(self = [super init]){
        self.inputLines = [NSMutableArray array];
    }
    return self;
}

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    self.invocation = invocation;
    XCSourceTextBuffer *buffer = invocation.buffer;
    if(buffer.lines.count == 0) {
        completionHandler(nil);
        return;
    };
    [self parseInputLines:buffer];
    if(self.inputLines.count == 0) {
        completionHandler(nil);
        return;
    }
    
    NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
    if([invocation.commandIdentifier isEqualToString:[NSString stringWithFormat:@"%@.%@", identifier,@"GetterAction"]]){
        [self getterActionByInputLines:self.inputLines];
    }else if([invocation.commandIdentifier isEqualToString:[NSString stringWithFormat:@"%@.%@", identifier,@"SetterAction"]]){
        [self setterActionByInputLines:self.inputLines];
    }else if([invocation.commandIdentifier isEqualToString:[NSString stringWithFormat:@"%@.%@", identifier,@"GetterSetterAction"]]){
        [self setterActionByInputLines:self.inputLines];
        [self getterActionByInputLines:self.inputLines];
    }
    
    completionHandler(nil);
}

-(void)setterActionByInputLines:(NSMutableArray<NSMutableDictionary*>*)inputLines{
    [inputLines enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self genSetterCode:obj];
    }];
}

-(void)getterActionByInputLines:(NSMutableArray<NSMutableDictionary*>*)inputLines{
    [inputLines enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self genGetterCode:obj];
    }];
}

//ctl+shift 可以跨行选中 selection>1
-(void)parseInputLines:(XCSourceTextBuffer*)buffer{
    NSMutableArray <XCSourceTextRange *> *selections = buffer.selections;
    for (XCSourceTextRange *range in selections) {
        NSInteger startLine = range.start.line;
        NSInteger endLine = range.end.line;
        if(startLine >= buffer.lines.count){
            startLine = buffer.lines.count-1;
        }
        if(endLine >= buffer.lines.count){
            endLine = buffer.lines.count-1;
        }
        for (NSInteger i=startLine; i<=endLine;i++){
            NSString *string = [self toString:buffer.lines[i]];
            
            if(![string containsString:@"@property"] || !string.length) continue;
            NSMutableArray *sepLines = [self seperateInputString:string];
            NSArray *names = [self getNameByInput:sepLines];
            NSString *className = names[0];
            NSString *varName = names[1];
            if(names.count == 2 && className.length && varName.length){
                NSMutableDictionary *dic = [NSMutableDictionary dictionary];
                [dic setObject:@(i) forKey:@"line"];
                [dic setObject:string forKey:@"inputLine"];
                [dic setObject:sepLines forKey:@"sepInputLine"];
                [dic setObject:className forKey:@"className"];
                [dic setObject:varName forKey:@"varName"];
                [dic addEntriesFromDictionary:[self getPropertyByInput:sepLines]];
                [self.inputLines addObject:dic];
            }
        }
    }
}

//解析类名和变量名
-(NSArray*)getNameByInput:(NSMutableArray*)sepInputLine{
    NSArray *filterNames = [self filterNameArray:[sepInputLine mutableCopy]];
    //至少应该剩2个元素
    if (filterNames.count >= 2) {
        NSMutableArray *result = [NSMutableArray array];
            NSString *varName = filterNames.lastObject;
            NSMutableArray *muArr = [filterNames mutableCopy];
            [muArr removeLastObject];
            NSString *className = [muArr componentsJoinedByString:@""];
            [result addObject:[self toString:className]];
            [result addObject:[self toString:varName]];
        return [result copy];
    }
    return nil;
}

//过滤后剩下类型和变量名的部分
-(NSArray*)filterNameArray:(NSMutableArray<NSString*>*)nameArray{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    [nameArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if([obj containsString:@"property"] || [obj containsString:@"("] || [obj containsString:@")"]){
            [indexSet addIndex:idx];
        }else if([obj isEqualToString:@"*"]){
            [indexSet addIndex:idx];
        }
    }];
    [nameArray removeObjectsAtIndexes:indexSet];
    return [nameArray copy];
}

-(NSMutableDictionary *)getPropertyByInput:(NSMutableArray<NSString*>*)sepLines{
   __block NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [sepLines enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(idx == sepLines.count - 1){
            *stop = YES;
        }
        if([obj containsString:@"nonnull"]){
            dic[@"nonnull"] = @"1";
        }else if([obj containsString:@"nullable"]){
            dic[@"nullable"] = @"1";
        }else if([obj containsString:@"readonly"]){
            dic[@"readonly"] = @"1";
        }else if([obj isEqualToString:@"*"]){
            dic[@"hasPointer"] = @"1";
        }else if([obj containsString:@"assign"]){
            dic[@"isAssign"] = @"1";
        }
    }];
    return dic;
}

//分词算法
-(NSMutableArray*)seperateInputString:(NSString*)inputString{
    NSInteger length = inputString.length;
    NSMutableArray *nameArr = [NSMutableArray array];
    NSMutableString *string = [NSMutableString string];
    BOOL openFlag = NO;
    for (NSInteger i = 0; i<length; i++){
        char c = [inputString characterAtIndex:i];
        if(c == ';'){
            if(string.length){
                [nameArr addObject:string];
                string = [NSMutableString string];
            }
            break;
        }else if(c == '(' || c == '<'){
            if(openFlag){
                if(string.length){
                    [nameArr addObject:string];
                    string = [NSMutableString string];
                }
            }
            openFlag = YES;
            [string appendString:[NSString stringWithFormat:@"%c",c]];
        }else if(c == ')' || c == '>'){
            [string appendString:[NSString stringWithFormat:@"%c",c]];
            if(openFlag){
                if(string.length){
                    [nameArr addObject:string];
                    string = [NSMutableString string];
                }
            }
            openFlag = NO;
        }else if(c == ' '){
            if(!openFlag){
                if(string.length){
                    [nameArr addObject:string];
                    string = [NSMutableString string];
                }
            }
        }else if(c == '*'){
            if(!openFlag){
                if(string.length){
                    [nameArr addObject:string];
                    string = [NSMutableString string];
                }
                [string appendString:[NSString stringWithFormat:@"%c",c]];
                [nameArr addObject:string];
                string = [NSMutableString string];
            }else{
                [string appendString:[NSString stringWithFormat:@"%c",c]];
            }
        }
        else{
            [string appendString:[NSString stringWithFormat:@"%c",c]];
        }
    }
    //NSLog(@"%@",nameArr);
    return nameArr;
}
 
//找到最近的 @end 位置
-(NSInteger)findNearestEndLine:(NSInteger)inputLine{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSInteger result = inputLine + 1;
    NSInteger totalLineCount = buffer.lines.count;
    if(inputLine >= totalLineCount) return totalLineCount - 1;
    for (NSInteger i = inputLine; i < totalLineCount; i++){
        NSString *lineString = buffer.lines[i];
        if([lineString containsString:@"@end"]){
            result = i;
            break;
        }
    }
    return result;
}

//找到当前最新的line位置
-(NSInteger)findNewestLine:(NSMutableDictionary*)inputLineDic{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSString *inputLine = inputLineDic[@"inputLine"];
    NSInteger start = [inputLineDic[@"line"] integerValue];
    NSInteger result = start;
    NSInteger totalLineCount = buffer.lines.count;
    if(result >= totalLineCount) return totalLineCount - 1;
    for (NSInteger i = start; i < totalLineCount; i++){
        NSString *lineString = buffer.lines[i];
        if([lineString containsString:inputLine]){
            result = i;
            break;
        }
    }
    return result;
}

//找到这个类的@implementation行
-(NSInteger)findImpLine:(NSString*)underClassName inputLine:(NSInteger)inputLine{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSInteger result = -1;
    for (NSInteger i=inputLine; i<buffer.lines.count;i++){
        NSString *lineString = buffer.lines[i];
        if([lineString containsString:@"@implementation"] && [lineString containsString:underClassName]){
            result = i;
            break;
        }
    }
    return result;
}

//是否已存在方法 0:getter 1:setter 2:synthesize
-(NSInteger)findCodeLine:(NSInteger)type impLine:(NSInteger)impLine endLine:(NSInteger)endLine inputLineDic:(NSMutableDictionary*)inputLineDic{
    NSInteger result = -1;
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSString *varName = inputLineDic[@"varName"];
    NSString *className = inputLineDic[@"className"];
    BOOL isNullable = [inputLineDic[@"nullable"] isEqualToString:@"1"];
    BOOL isNonnull = [inputLineDic[@"nonnull"] isEqualToString:@"1"];
    BOOL hasPointer = [inputLineDic[@"hasPointer"] isEqualToString:@"1"];
    NSString *pattern = @"";
    switch (type) {
        case 0:{
            pattern = [NSString stringWithFormat:@"-\\(%@\\)%@\\{",[self escapeString:className],[self escapeString:varName]];
            if(hasPointer){
                pattern = [NSString stringWithFormat:@"-\\(%@\\*\\)%@\\{",[self escapeString:className],[self escapeString:varName]];
            }
        }
            break;
        case 1:
            pattern = [NSString stringWithFormat:@"\\(void\\)set%@:\\(",[self escapeString:[self capVarName:varName]]];
            break;
        case 2:
            pattern = [NSString stringWithFormat:@"@synthesize%@",[self escapeString:varName]];
            break;
        default:
            return -1;
            break;
    }
    if(endLine >= impLine){
        for (NSInteger i = (impLine<0)? 0:impLine; i<endLine;i++){
            NSString *lineString = [self trimWhiteSpace:buffer.lines[i]];
            NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
            if(match){
                result = i;
                break;
            }else{
                if(type == 0){
                    NSString *newPattern = @"";
                    if(isNullable){
                        newPattern = [NSString stringWithFormat:@"-\\(%@\\*\\_Nullable\\)%@\\{",[self escapeString:className],[self escapeString:varName]];
                    }else if(isNonnull){
                        newPattern = [NSString stringWithFormat:@"-\\(%@\\*\\_Nonnull\\)%@\\{",[self escapeString:className],[self escapeString:varName]];
                    }else{
                        continue;
                    }
                    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:newPattern options:0 error:nil];
                    NSTextCheckingResult *match = [regex firstMatchInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
                    if(match){
                        result = i;
                        break;
                    }
                }
            }
        }
        return result;
    }
    return result;
}

//输入行在哪个类下
-(NSMutableDictionary*)getUnderClassInfo:(NSInteger)inputLine{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSInteger result = inputLine;
    NSString *underClassName = @"";
    for (NSInteger i = inputLine; i>=0; i--){
        NSString *lineString = buffer.lines[i];
        if([lineString containsString:@"@interface"]){
            underClassName = [self getUnderClassName:lineString];
            result = i;
            break;
        }
    }
    [dic setObject:@(result) forKey:@"line"];
    [dic setObject:underClassName forKey:@"underClassName"];
    return dic;
}

-(NSString*)getUnderClassName:(NSString*)lineString{
    NSString *patternClassExtension = @"(?<=@interface).*(?=\\()";
    NSString *patternClass = @"(?<=@interface).*(?=\\:)";
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:patternClassExtension options:0 error:nil];
    NSTextCheckingResult *match = [regex firstMatchInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
    if(!match){
        regex = [[NSRegularExpression alloc] initWithPattern:patternClass options:0 error:nil];
        match = [regex firstMatchInString:lineString options:0 range:NSMakeRange(0, lineString.length)];
    }
    if(match){
        NSString *patternString = [lineString substringWithRange:match.range];
        return [self trimWhiteSpace:patternString];
    }
    return @"";
}

-(NSDictionary*)refreshPostionInfo:(NSMutableDictionary*)inputLineDic{
    NSInteger line = [self findNewestLine:inputLineDic];
    NSInteger impLine = -1;
    NSInteger endLine = line;
    NSMutableDictionary *dic = [self getUnderClassInfo:line];
    NSString *underClassName = dic[@"underClassName"];
    
    if(underClassName.length){
        impLine = [self findImpLine:underClassName inputLine:line];
        if (impLine >=0) {
            endLine = [self findNearestEndLine:impLine];
        }else{
            endLine = [self findNearestEndLine:line];
        }
    }else{
        endLine = [self findNearestEndLine:line];
    }
    NSMutableDictionary *resultDic = [NSMutableDictionary dictionary];
    [resultDic setObject:@(line) forKey:@"line"];
    [resultDic setObject:@(endLine) forKey:@"endLine"];
    [resultDic setObject:@(impLine) forKey:@"impLine"];
    return [resultDic copy];
}

//getter code 生成
//找最近的@implementation行,如果找到说明属性应该在.m的extension里面,生成位置在离@implementation行最近的@end行, 否则属性在.h中,直接找书入行所对应的最近的@end行
-(void)genGetterCode:(NSMutableDictionary*)inputLineDic{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSDictionary *posDic = [self refreshPostionInfo:inputLineDic];
    NSInteger impLine = [posDic[@"impLine"] integerValue];
    NSInteger endLine = [posDic[@"endLine"] integerValue];
    NSInteger hasGetter = [self findCodeLine:0 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
    if(hasGetter >=0){
        return;
    }
    
    BOOL isNullable = [inputLineDic[@"nullable"] isEqualToString:@"1"];
    BOOL isNonnull = [inputLineDic[@"nonnull"] isEqualToString:@"1"];
    BOOL hasPointer = [inputLineDic[@"hasPointer"] isEqualToString:@"1"];
    BOOL isAssign = [inputLineDic[@"isAssign"] isEqualToString:@"1"];
    NSString *varName = inputLineDic[@"varName"];
    NSString *className = inputLineDic[@"className"];
    NSString *classNamePointer = hasPointer? [className stringByAppendingString:@" *"]: className;
    
    if(isNullable){
        classNamePointer = [classNamePointer stringByAppendingString:@" _Nullable"];
    }else if(isNonnull){
        classNamePointer = [classNamePointer stringByAppendingString:@" _Nonnull"];
    }
    
    BOOL isIdStruct = [classNamePointer hasPrefix:@"id<"];
    
    NSString *outputFormat = @"\n- (%@)%@ {\n\tif(!_%@) {\n\t\t_%@ = [[%@ alloc] init];\n\t}\n\treturn _%@;\n}";
    NSString *code = [NSString stringWithFormat:outputFormat,classNamePointer,varName,varName,varName,className,varName];
    if(isAssign || isIdStruct){
        outputFormat = @"\n- (%@)%@ {\n\treturn _%@;\n}";
        code = [NSString stringWithFormat:outputFormat,classNamePointer,varName,varName];
    }
    [buffer.lines insertObject:code atIndex:endLine];
    
    posDic = [self refreshPostionInfo:inputLineDic];
    impLine = [posDic[@"impLine"] integerValue];
    endLine = [posDic[@"endLine"] integerValue];
    NSInteger hasSetter = [self findCodeLine:1 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
    if(hasSetter >=0){
        NSInteger hasSynthesize = [self findCodeLine:2 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
        if(hasSynthesize < 0){
            [self genSynthesizeCode:inputLineDic];
        }
    }
}

//setter code 生成
-(void)genSetterCode:(NSMutableDictionary*)inputLineDic{
    BOOL isReadOnly = [inputLineDic[@"readonly"] isEqualToString:@"1"];
    if(isReadOnly) return;
    
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSDictionary *posDic = [self refreshPostionInfo:inputLineDic];
    NSInteger impLine = [posDic[@"impLine"] integerValue];
    NSInteger endLine = [posDic[@"endLine"] integerValue];
    NSInteger hasSetter = [self findCodeLine:1 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
    if(hasSetter >=0){
        return;
    }
    
    BOOL isNullable = [inputLineDic[@"nullable"] isEqualToString:@"1"];
    BOOL isNonnull = [inputLineDic[@"nonnull"] isEqualToString:@"1"];
    BOOL hasPointer = [inputLineDic[@"hasPointer"] isEqualToString:@"1"];
    NSString *varName = inputLineDic[@"varName"];
    NSString *className = inputLineDic[@"className"];
    NSString *capVarName = [self capVarName:varName];
    
    if(hasPointer){
        className = [className stringByAppendingString:@" *"];
    }
    if(isNullable){
        className = [className stringByAppendingString:@" _Nullable"];
    }else if(isNonnull){
        className = [className stringByAppendingString:@" _Nonnull"];
    }
    
    NSString *outputFormat = @"\n- (void)set%@:(%@)%@ {\n\t_%@ = %@;\n}";
    NSString *code = [NSString stringWithFormat:outputFormat,capVarName,className,varName,varName,varName];
    [buffer.lines insertObject:code atIndex:endLine];
    
    posDic = [self refreshPostionInfo:inputLineDic];
    impLine = [posDic[@"impLine"] integerValue];
    endLine = [posDic[@"endLine"] integerValue];
    NSInteger hasGetter = [self findCodeLine:0 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
    if(hasGetter >=0){
        NSInteger hasSynthesize = [self findCodeLine:2 impLine:impLine endLine:endLine inputLineDic:inputLineDic];
        if(hasSynthesize < 0){
            [self genSynthesizeCode:inputLineDic];
        }
    }
}

//@synthesize code 生成
-(void)genSynthesizeCode:(NSMutableDictionary*)inputLineDic{
    XCSourceTextBuffer *buffer = self.invocation.buffer;
    NSInteger line = [self findNewestLine:inputLineDic];
    NSInteger endLine = line;
    NSMutableDictionary *dic = [self getUnderClassInfo:line];
    NSString *underClassName = dic[@"underClassName"];
    if(underClassName.length){
        NSInteger impLine = [self findImpLine:underClassName inputLine:line];
        if (impLine >=0) {
            endLine = impLine + 1;
        }else{
            endLine = [self findNearestEndLine:line];
        }
    }else{
        endLine = [self findNearestEndLine:line];
    }
    
    NSString *varName = inputLineDic[@"varName"];
    NSString *outputFormat = @"@synthesize %@ = _%@;\n";
    NSString *code = [NSString stringWithFormat:outputFormat,varName,varName];
    [buffer.lines insertObject:code atIndex:endLine];
}

//首字母大写
-(NSString*)capVarName:(NSString*)varName{
    return [varName stringByReplacingCharactersInRange:NSMakeRange(0,1) withString:[[varName substringToIndex:1] uppercaseString]];
}

//toString
-(NSString*)toString:(id)x
{
    if ([x isKindOfClass:[NSString class]]) return x;
    else if (!x || [x isKindOfClass:[NSNull class]]) return @"";
    else if ([x isKindOfClass:[NSNumber class]]) return [NSString stringWithFormat:@"%@",x];
    return [x description];
}

//去空字符
-(NSString*)trimWhiteSpace:(NSString*)inputString{
    inputString = [inputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    inputString = [inputString stringByReplacingOccurrencesOfString:@" " withString:@""];
    inputString = [inputString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    inputString = [inputString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    inputString = [inputString stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    return [self toString:inputString];
}

//转义
-(NSString*)escapeString:(NSString*)string{
    string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    string = [string stringByReplacingOccurrencesOfString:@"?" withString:@"\\?"];
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
    string = [string stringByReplacingOccurrencesOfString:@"," withString:@"\\,"];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
    string = [string stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
    string = [string stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
    string = [string stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
    string = [string stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
    string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
    string = [string stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
    string = [string stringByReplacingOccurrencesOfString:@")" withString:@"\\)"];
    string = [string stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
    string = [string stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
    string = [string stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
    string = [string stringByReplacingOccurrencesOfString:@"}" withString:@"\\}"];
    string = [string stringByReplacingOccurrencesOfString:@"<" withString:@"\\<"];
    string = [string stringByReplacingOccurrencesOfString:@">" withString:@"\\>"];
    string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    string = [string stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    return string;
}

@end

