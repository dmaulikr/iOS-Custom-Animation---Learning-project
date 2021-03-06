//
//  CLGameArea.m
//  Noms
//
//  Created by Colby Ludwig on 11-04-25.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CLGameArea.h"
#import "CLMainViewController.h"



@implementation CLGameArea
@synthesize paused, pausedWhen, won;

- (id)initWithFrame:(CGRect)frame level:(NSDictionary*)lvl {
    self = [super initWithFrame:frame];
    if (self) {
		self.userInteractionEnabled = YES;
		self.clipsToBounds = YES;
		self.backgroundColor = BG_COLOR_NORM;
		
		refresher = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(didTick:) userInfo:nil repeats:YES];
		walls = [[NSMutableArray alloc] init];
		enemies = [[NSMutableArray alloc] init];
		coins = [[NSMutableArray alloc] init];
		
        gotAmount = 0;
        self.won = NO;
        self.paused = NO;
		[self loadLevel:lvl];
		
		UITapGestureRecognizer *ges = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
		[self addGestureRecognizer:ges];
		[ges release];
    }
    return self;
}

-(void)loadLevel:(NSDictionary*)lvl {
	
	// start, end, obs
	NSArray *startInfo = [lvl objectForKey:@"start"];
	NSArray *endInfo = [lvl objectForKey:@"end"];
	NSArray *obsInfo = [lvl objectForKey:@"obs"];
	
	
	end = [[CLFinish alloc] initWithFrame:CGRectMake([[endInfo objectAtIndex:0] floatValue], 
													 [[endInfo objectAtIndex:1] floatValue], 
													 [[endInfo objectAtIndex:2] floatValue], 
													 [[endInfo objectAtIndex:3] floatValue])];
	[self addSubview:end];
	
	initPlayerFrame = CGRectMake([[startInfo objectAtIndex:0] floatValue],
								 [[startInfo objectAtIndex:1] floatValue],
								 PLAYER_SIZE, PLAYER_SIZE);
	me = [[CLPlayer alloc] initWithFrame:initPlayerFrame];
	[self addSubview:me];
	
	for (NSDictionary *obs in obsInfo) {
		NSString *type = [obs objectForKey:@"type"];
		
		CLObs *obj = nil;
		if ([type isEqualToString:@"wall"]) {
			NSArray *rects = [obs objectForKey:@"rect"];
			CGRect rec = CGRectMake([[rects objectAtIndex:0] floatValue], 
									[[rects objectAtIndex:1] floatValue], 
									[[rects objectAtIndex:2] floatValue], 
									[[rects objectAtIndex:3] floatValue]);
			
			obj = [[CLObsWall alloc] initWithFrame:rec];
			[walls addObject:obj];
        } else if ([type isEqualToString:@"coin"]) {
			NSArray *poss = [obs objectForKey:@"point"];
			CGPoint startP = CGPointMake([[poss objectAtIndex:0] floatValue], 
										 [[poss objectAtIndex:1] floatValue]);
			obj = [[CLObsCoin alloc] initWithPoint:startP];
			[coins addObject:obj];
		} else if ([type isEqualToString:@"enemy"]) {
			NSArray *starts = [obs objectForKey:@"start"];
			NSArray *ends = [obs objectForKey:@"end"];
			CGPoint startP = CGPointMake([[starts objectAtIndex:0] floatValue], 
										 [[starts objectAtIndex:1] floatValue]);
			CGPoint endP = CGPointMake([[ends objectAtIndex:0] floatValue],
									   [[ends objectAtIndex:1] floatValue]);
			
			obj = [[CLObsEnemy alloc] initWithStart:startP end:endP];
			[enemies addObject:obj];
        }
		[self addSubview:obj];
		[obj release];
	}
    
    for (CLObsEnemy *enemy in enemies) {
        [self bringSubviewToFront:enemy];
    }
    for (CLObsWall *wall in walls) {
        [self bringSubviewToFront:wall];
    }
}	


-(void)didTap:(UITapGestureRecognizer*)ges {
    if (self.paused == YES) { return; }
	if (ges.state == UIGestureRecognizerStateEnded) {
		CGPoint tap = [ges locationInView:self];
		me.beginPoint = me.center;
		me.gotoPoint = tap;
		me.beginStart = [NSDate date];
	}
}


-(void)didTick:(id)sender {
	[self handlePlayerMove];
	[self handleEnemiesMove];
	[self checkPlayerEnemies];
	[self checkPlayerCoins];
	[self checkPlayerFinished];
	[self checkPlayerWalls];
}

-(void)handlePlayerMove {
	if (CGPointEqualToPoint(CGPointZero, me.gotoPoint) || CGPointEqualToPoint(me.center, me.gotoPoint)) {
		return;
	}
	
	CGPoint beginPoint = me.beginPoint;
	CGPoint endPoint = me.gotoPoint;
	CGPoint newPoint = CGPointZero;
	
	NSDate *startTime = me.beginStart;
	NSTimeInterval timePassed_ms = [startTime timeIntervalSinceNow] * -1000.0;
	CGFloat timeDiff = timePassed_ms/1000;
	
	CGFloat totalDistance = DistanceBetweenTwoPoints(beginPoint, endPoint);
	CGFloat totalDuration = DurationForPlayerDistance(totalDistance);
	
	CGFloat mRise = (endPoint.y-beginPoint.y);
	CGFloat mRun = (endPoint.x-beginPoint.x);
	
	CGFloat moveY = (timeDiff/totalDuration)*mRise;
	CGFloat moveX = (timeDiff/totalDuration)*mRun;
	
	newPoint = CGPointMake(round(beginPoint.x+moveX), round(beginPoint.y+moveY));
    
	CGFloat newDistance = DistanceBetweenTwoPoints(beginPoint, newPoint);
	if (newDistance >= totalDistance) {
		newPoint = endPoint;
	}
	
	me.lastPoint = me.center;
	me.lastFrame = me.frame;
	me.center = newPoint;
}
-(void)handleEnemiesMove {
	for (CLObsEnemy *enemy in enemies) {
		CGPoint beginPoint = enemy.startPoint;
		CGPoint endPoint = enemy.endPoint;
		
		if (enemy.direction == 1) {
			beginPoint = enemy.endPoint;
			endPoint = enemy.startPoint;
		}
		
		CGPoint newPoint = CGPointZero;
		
		NSDate *startTime = enemy.beginStart;
		NSTimeInterval timePassed_ms = [startTime timeIntervalSinceNow] * -1000.0;
		CGFloat timeDiff = timePassed_ms/1000;
		
		CGFloat totalDistance = DistanceBetweenTwoPoints(beginPoint, endPoint);
		CGFloat totalDuration = DurationForEnemyDistance(totalDistance);
		
		CGFloat mRise = (endPoint.y-beginPoint.y);
		CGFloat mRun = (endPoint.x-beginPoint.x);
		
		CGFloat moveY = (timeDiff/totalDuration)*mRise;
		CGFloat moveX = (timeDiff/totalDuration)*mRun;
		
		newPoint = CGPointMake(round(beginPoint.x+moveX), round(beginPoint.y+moveY));
		
		CGFloat newDistance = DistanceBetweenTwoPoints(beginPoint, newPoint);
		if (newDistance >= totalDistance) {
			newPoint = endPoint;
			enemy.direction = (enemy.direction == 0) ? 1 : 0;
			enemy.beginStart = [NSDate date];
		}
		
		enemy.center = newPoint;		
	}
}

-(void)checkPlayerFinished {
	CGRect finishRect = end.frame;
	CGRect curRect = me.frame;
	
	if (CGRectContainsRect(finishRect, curRect)) {
		for (CLObsCoin *coin in coins) {
			if (coin.didGet == NO) { return; }
		}
		[self didWin];
	}
}
-(void)checkPlayerEnemies {
	for (CLObsEnemy *enemy in enemies) {
		CGRect enemyRect = enemy.frame;
		CGRect playerRect = me.frame;
		
		if (CGRectIntersectsRect(playerRect, enemyRect)) {
			[self didGetOwned];
			break;
		}
	}
}
-(void)checkPlayerCoins {
	for (CLObsCoin *coin in coins) {
		if (coin.didGet == YES) {
            continue;
        }
		
		if (CGRectIntersectsRect(me.frame, coin.frame)) {
            gotAmount++;
            [(CLMainViewController*)vc setNoms:gotAmount fromTotal:[coins count]];
			coin.didGet = YES;
			[coin removeFromSuperview];
		}
	}
}
-(void)checkPlayerWalls {
	CGRect player = me.frame;
	//CGRectIntersection, CGRectIntersectsRect
	for (CLObs *wall in walls) {
		CGRect intersection = CGRectIntersection(player, wall.frame);
		if (!CGRectIsNull(intersection)) {
			
            ObsPosition *pos = RelPositionOfPlayer(me.lastFrame, wall.frame);
			CGRect newPlayer = player;
			if (ObsEqual(pos, ObsRight)) {
				newPlayer.origin.x = wall.frame.origin.x + wall.frame.size.width + 1;
			}
			if (ObsEqual(pos, ObsLeft)) {
				newPlayer.origin.x = wall.frame.origin.x - newPlayer.size.width - 1;
			}
			if (ObsEqual(pos, ObsTop)) {
				newPlayer.origin.y = wall.frame.origin.y - newPlayer.size.height - 1;
			}
			if (ObsEqual(pos, ObsBottom)) {
				newPlayer.origin.y = wall.frame.origin.y + wall.frame.size.height + 1;
			}
			me.frame = newPlayer;
            
            // If we "start" from where we are,
            //  it sortof hacks the duration so that
            //  so it doesn't skip a wall by thinking
            //  it's too far in time and is past it
            me.beginStart = [NSDate date];
            me.beginPoint = me.center;
		}
	}
}


-(void)didWin {
    self.won = YES;
	[refresher invalidate], refresher = nil;
	[(CLMainViewController*)vc nextLevel];
}
-(void)didGetOwned {
	[refresher invalidate], refresher = nil;
    [(CLMainViewController*)vc incrementDeaths];
	
	[UIView animateWithDuration:0.4 animations:^{
		me.backgroundColor = PLAYER_COLOR_FADE;
		self.backgroundColor = BG_COLOR_FADE;
	} completion:^(BOOL finished) {
        
		gotAmount = 0;
        [(CLMainViewController*) vc setNoms:gotAmount fromTotal:[coins count]];
        
		for (CLObsCoin *coin in coins) {
			coin.didGet = NO;
			[coin removeFromSuperview];
			[self addSubview:coin];
		}
		for (CLObsEnemy *enemy in enemies) {
            [self bringSubviewToFront:enemy];
        }
        for (CLObsWall *wall in walls) {
            [self bringSubviewToFront:wall];
        }
        
		me.lastFrame = CGRectZero;
		me.gotoPoint = CGPointZero;
		
		[UIView animateWithDuration:0.65 animations:^{
			me.frame = initPlayerFrame;
			self.backgroundColor = BG_COLOR_NORM;
		} completion:^(BOOL finished) {
			me.lastPoint = me.center;
			me.beginPoint = me.center;
			me.backgroundColor = PLAYER_COLOR_NORM;
			
			CGFloat timeSub = (.65 + .4);
			for (CLObsEnemy *enemy in enemies) {
				enemy.beginStart = [enemy.beginStart dateByAddingTimeInterval:timeSub];
			}
			
			refresher = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(didTick:) userInfo:nil repeats:YES];
		}];
	}];
}

-(void)setVC:(UIViewController*)newvc {
    vc = newvc;
    [(CLMainViewController*)vc setNoms:gotAmount fromTotal:[coins count]];
}

-(void)pause {
    if (refresher) {
        self.pausedWhen = [NSDate date];
        [refresher invalidate], refresher = nil;
    }
    self.paused = YES;
    [UIView animateWithDuration:0.4 animations:^{
        self.backgroundColor = BG_COLOR_FADE;
    }];
}
-(void)unpause {
    if (refresher) { return; }
    [UIView animateWithDuration:0.4 animations:^{
        self.backgroundColor = BG_COLOR_NORM;
    } completion:^(BOOL finished) {
        
        CGFloat tDiff = -[self.pausedWhen timeIntervalSinceNow];
        for (CLObsEnemy *enemy in enemies) {
            enemy.beginStart = [enemy.beginStart dateByAddingTimeInterval:tDiff];
        }
        // Me too, because we could be in the middle of moving
        me.beginStart = [me.beginStart dateByAddingTimeInterval:tDiff];
        
        self.pausedWhen = nil;
        self.paused = NO;
        
        refresher = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(didTick:) userInfo:nil repeats:YES];
    }];
}

- (void)dealloc {
	[me release];
	[walls release];
	[enemies release];
    [super dealloc];
}


//-(BOOL)checkPointIntersects:(CGPoint)p {
//    CGRect pRect = CGRectMake(p.x-(PLAYER_SIZE/2), p.y-(PLAYER_SIZE/2), PLAYER_SIZE, PLAYER_SIZE);
//    for (CLObs *wall in walls) {
//        if (!CGRectIsNull(CGRectIntersection(pRect, wall.frame))) {
//            return YES;
//        }
//    }
//    return NO;
//}
@end
