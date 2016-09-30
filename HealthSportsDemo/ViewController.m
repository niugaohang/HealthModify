//
//  ViewController.m
//  HealthSportsDemo
//
//  Created by 牛高航 on 2016/9/28.
//  Copyright © 2016年 牛高航. All rights reserved.
//


#import "ViewController.h"

#import <HealthKit/HealthKit.h>

#import "SVProgressHUD.h"


@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate>
{
    UITextField *_writeTextField;
}

@property(nonatomic,retain)UITableView *tableView;
@property(nonatomic,retain)HKHealthStore *healthStore;
@property(nonatomic,retain)NSString *readBSStr;
@property(nonatomic,retain)NSString *writeBSStr;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title=@"写入健康步数数据";
    
    [self isHealthDataAvailable];
    
    [self initWithTabbleView];
    
}

-(void)isHealthDataAvailable
{
    
    //查看healthKit在设备上是否可用，ipad不支持HealthKit
    if ([HKHealthStore isHealthDataAvailable]) {
//        HKHealthStore —— 关键类（使用HealthKit框架必须创建该类）
        _healthStore= [[HKHealthStore alloc]init];
//        创建步数类型
        NSSet *writeDataTypes = [self dataTypesToWrite];
        NSSet *readDataTypes = [self dataTypesToRead];
//    这里调用了requestAuthorizationToShareTypes:readTypes方法并将之前定义好的读取和写入的种类作为参数传了进去
        [_healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError *error) {
            if (success)
            {
                NSLog(@"获取步数权限成功");
                //获取步数后我们调用获取步数的方法
                [self readStepCount];
            }
            else
            {
             
                NSLog(@"你不允许包来访问这些读/写数据类型。error === %@", error);
                return;
            }
        }];
         //    程序运行到这就回弹出健康的那个提示界面了，选择允许选项。
    }
    else{
        NSLog(@"设备不支持healthKit");
    }
    
}
#pragma mark - 设置写入权限
- (NSSet *)dataTypesToWrite {
    HKQuantityType *stepType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    return [NSSet setWithObjects:stepType, nil];
}

#pragma mark - 设置读取权限
- (NSSet *)dataTypesToRead {
    HKQuantityType *stepType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    return [NSSet setWithObjects:stepType, nil];
}

//查询数据
- (void)readStepCount
{
    [SVProgressHUD setStatus:@"正在读取健康数据..."];
    //查询采样信息
    HKSampleType *sampleType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    //NSSortDescriptors用来告诉healthStore怎么样将结果排序。
    
    NSSortDescriptor *timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:NO];
    /*查询的基类是HKQuery，这是一个抽象类，能够实现每一种查询目标，这里我们需要查询的步数是一个
     HKSample类所以对应的查询类就是HKSampleQuery。
     下面的limit参数传1表示查询最近一条数据,查询多条数据只要设置limit的参数值就可以了
     */
    
    HKSampleQuery *sampleQuery = [[HKSampleQuery alloc] initWithSampleType:sampleType predicate:[self predicateForSamplesToday] limit:HKObjectQueryNoLimit sortDescriptors:@[timeSortDescriptor] resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error) {
        
        if(error)
        {
            NSLog(@"error=====%@",error);
        }
        else
        {
            NSInteger totleSteps = 0;
            for(HKQuantitySample *quantitySample in results)
            {
                HKQuantity *quantity = quantitySample.quantity;
                HKUnit *heightUnit = [HKUnit countUnit];
                double usersHeight = [quantity doubleValueForUnit:heightUnit];
                totleSteps += usersHeight;
            }
            NSLog(@"当天行走步数 = %ld",(long)totleSteps);
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
                _readBSStr=[NSString stringWithFormat:@"%ld",(long)totleSteps];
                [_tableView reloadData];
            });
            
        }
        
        /*打印查询结果
        NSLog(@"resultCount = %ld result = %@",results.count,results);
        //把结果装换成字符串类型
        HKQuantitySample *result = results[0];
        HKQuantity *quantity = result.quantity;
        NSString *stepStr = (NSString *)quantity;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            //查询是在多线程中进行的，如果要对UI进行刷新，要回到主线程中
            NSLog(@"最新步数：%@",stepStr);
        }];
         */
        
    }];
    //执行查询
    [self.healthStore executeQuery:sampleQuery];
}
/*!
 *  @brief  当天时间段 NSPredicate当天时间段的方法实现
 *
 *  @return 时间段
 */
-(NSPredicate *)predicateForSamplesToday {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond: 0];
    
    NSDate *startDate = [calendar dateFromComponents:components];
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionNone];
    return predicate;
}

//写入步数
-(void)writeDataToHealth:(NSString *)writeStr
{
     [SVProgressHUD setStatus:@"正在写入健康数据..."];
    //    4 设置步数并且保存
    //数据看类型为步数.
    HKQuantityType *quantityTypeIdentifier = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    
    //表示步数的数据单位的数量
    HKQuantity *quantity = [HKQuantity quantityWithUnit:[HKUnit countUnit] doubleValue:[writeStr doubleValue]];
    
    //数量样本.
    HKQuantitySample *temperatureSample = [HKQuantitySample quantitySampleWithType:quantityTypeIdentifier quantity:quantity startDate:[NSDate date] endDate:[NSDate date] metadata:nil];
    
    //保存
    [self.healthStore saveObject:temperatureSample withCompletion:^(BOOL success, NSError *error) {
        if (success) {
            [SVProgressHUD dismiss];
            NSString *messageStr=[NSString stringWithFormat:@"成功写入%@步",writeStr];
            
            
            //保存成功
            UIAlertController *alertController=[UIAlertController alertControllerWithTitle:@"保存成功" message:messageStr preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
            [alertController addAction:okAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
            
            NSLog(@"保存成功");
            //读取
            [self readStepCount];
            
        }else {
            //保存失败
            NSLog(@"保存失败");
        }
    }];

}

-(void)initWithTabbleView
{
    _tableView=[[UITableView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) style:UITableViewStyleGrouped];
    _tableView.delegate=self;
    _tableView.dataSource=self;
    _tableView.separatorStyle=UITableViewCellSeparatorStyleSingleLine;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.showsVerticalScrollIndicator=NO;
    
    [self.view addSubview:_tableView];
    
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* indetifier=@"MyCells";
    UITableViewCell*cell=[tableView dequeueReusableCellWithIdentifier:indetifier];
    if (!cell)
    {
        cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:indetifier ];
        cell.selectionStyle=UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    if (indexPath.row == 0)
    {
        cell.textLabel.text =[NSString stringWithFormat:@"当前运动步数：%@",_readBSStr] ;
    }
    if (indexPath.row == 1)
    {
        _writeTextField =[[UITextField alloc]initWithFrame:CGRectMake(20, 2, self.view.frame.size.width-140, 40)];
        _writeTextField.borderStyle = UITextBorderStyleRoundedRect;
         _writeTextField.placeholder =@"写入步数";
        _writeTextField.returnKeyType=UIReturnKeyDone;
        _writeTextField.text =_writeBSStr;
        _writeTextField.font=[UIFont systemFontOfSize:15];
        _writeTextField.delegate = self;
        [cell.contentView addSubview:_writeTextField];
    }
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44;
}
//键盘return按钮
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField.text isEqualToString:@""])
    {
        return NO;
    }
    [textField resignFirstResponder];
    [self writeDataToHealth:textField.text];
    
    return YES;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
