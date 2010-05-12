//
//  News.h
//  Ile sans fil
//
//  Created by thomas dobranowski on 10/05/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface News :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * writer;
@property (nonatomic, retain) NSString * summary;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * identifier;
@property (nonatomic, retain) NSDate * CreatedAt;
@property (nonatomic, retain) NSString * link;

+ (News *)findOrCreateContactWithIdentifier:(NSString *)identifier;
+ (NSArray *)findAll;

@end



