//
//  RestaurantCardFactory.m
//  Munch
//
//  Created by Zach Smoroden on 2016-05-30.
//  Copyright © 2016 Enoch Ng. All rights reserved.
//

#import "RestaurantCardFactory.h"
#import "RestaurantCardViewOverlay.h"
#import "Restaurant.h"
#import "MNCCategory.h"
#import "AppDelegate.h"

#define CARD_WIDTH      300
#define CARD_HEIGHT     300
#define MAX_BUFFER_SIZE 3

@interface RestaurantCardFactory () <RestaurantCardViewDelegate>

@property (nonatomic) NSMutableArray *restaurants;
@property (nonatomic) NSMutableArray *loadedRestaurants;


@property (nonatomic) NSInteger restaurantLoadedIndex;
@property (nonatomic) CGFloat verticalOffset;

// UI Stuff
@property (weak, nonatomic) IBOutlet UIButton *munchNowButton;
@property (weak, nonatomic) IBOutlet UIButton *nopeButton;
@property (weak, nonatomic) IBOutlet UIButton *yukButton;

@property (nonatomic) float buttonShrinkRatio;

@property (nonatomic) TempRestaurant *selected;

@property (nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation RestaurantCardFactory

#pragma mark - UIView Lifecycle etc. -

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _restaurants = [NSMutableArray array];
        _loadedRestaurants = [NSMutableArray array];
        _verticalOffset = 0;
        self.buttonShrinkRatio = 0.8;
        [self checkButtons];
    }
    return self;
}

#pragma mark - Card Creation -

-(RestaurantCardView*)createRestaurantCardAtIndex:(NSInteger)index {
    
    RestaurantCardView *newCard = [[RestaurantCardView alloc] init];
    
    TempRestaurant *restaurant = self.data[index];
    
    
    newCard.translatesAutoresizingMaskIntoConstraints = NO;
    
    newCard.overlay.frame = newCard.baseView.frame;
    newCard.titleLabel.text = restaurant.name;

    newCard.distanceLabel.text = restaurant.verbalAddress;
    


    
    
    newCard.cusineLabel.text = restaurant.categories;
    
    [self downloadRatingImageForCard:newCard withURLString:restaurant.ratingURL];
    
    [self downloadImageForCard:newCard withURLString:restaurant.imageURL];
    
    newCard.imageView.image = [UIImage imageNamed:@"defaultImage"];
    
    newCard.delegate = self;
    
    
    [self layoutIfNeeded];
    
    
    return newCard;
    
}

-(void)downloadImageForCard:(RestaurantCardView*)card withURLString:(NSString *)urlString{
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    card.imageView.image = image;
                });
            }
        }
    }];
    [task resume];
    
}

#warning incomplete, get image for rating.
-(void)downloadRatingImageForCard:(RestaurantCardView*)card withURLString:(NSString *)urlString{
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    card.ratingImage.image = image;
                });
            }
        }
    }];
    [task resume];
    
}

-(void)setupConstraintsForCard:(RestaurantCardView*)card {
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:card attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeHeight multiplier:0.5 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:card attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:0.9 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:card attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterX multiplier:1 constant:0]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:card attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1 constant:20]];
}

// This may come in handy later so keep it here
-(void)resetCardsWithData:(NSArray *)data {
    
    // Get rid of the now outdated views
    for (RestaurantCardView *view in self.loadedRestaurants) {
        [view removeFromSuperview];
    }
    
    [self.loadedRestaurants removeAllObjects];
    [self.restaurants removeAllObjects];
    
    [self loadRestaurantCardsWithData:data];
    
}


-(void)loadRestaurantCardsWithData:(NSArray*)data {
    // Actual Data
    self.data = data;
    self.restaurantLoadedIndex = 0;
    
    // If we have less than the buffer size of restaurants left we don't want to try to load 3
    NSInteger numLoadedCardsCap;
    if (self.data.count > 0) {
        numLoadedCardsCap = MAX_BUFFER_SIZE;
    } else {
        numLoadedCardsCap = self.data.count;
    }
    
    // For all of the data we got (restaurants to show) create a restaurant object and if applicable
    // add it to the loaded buffer
    for (int i = 0; i < self.data.count; i++) {
        RestaurantCardView *newCard = [self createRestaurantCardAtIndex:i];
        
        [self.restaurants addObject:newCard];
        
        if (i < numLoadedCardsCap) {
            [self.loadedRestaurants addObject:newCard];
        }
        
    }
    
    // Now we load the views onto the screen
    for (int i = 0; i < self.loadedRestaurants.count; i++) {
        
        if (i > 0) {
            [self insertSubview:[self.loadedRestaurants objectAtIndex:i] belowSubview:[self.loadedRestaurants objectAtIndex:i - 1]];
        } else {
            [self addSubview:[self.loadedRestaurants objectAtIndex:i]];
        }
        
        [self setupConstraintsForCard:[self.loadedRestaurants objectAtIndex:i]];
        
        //[self layoutIfNeeded];
        self.restaurantLoadedIndex += 1;
    }
    [self checkButtons];
    [self layoutIfNeeded];
}

#pragma mark - Button Methods -
- (void)munchNowPressed:(UIButton *)sender {

    RestaurantCardView *cardView = [self.loadedRestaurants firstObject];
    [self swipedRightWithCard:cardView];
    
    [cardView.overlay updateMode:RestaurantCardViewOverlayModeRight];
    [UIView animateWithDuration:0.2 animations:^{
        cardView.overlay.alpha = 0.5;
    } completion:^(BOOL finished) {
         [cardView yesClickAction];
    }];
    
}

//-(void)delayYesClickAction:(RestaurantCardView *)cardView{
//    [cardView yesClickAction];
//}

- (void)noPressed:(UIButton *)sender {
    
    RestaurantCardView *cardView = [self.loadedRestaurants firstObject];
    [self swipedLeftWithCard:cardView];
    
    [cardView.overlay updateMode:RestaurantCardViewOverlayModeLeft];
    [UIView animateWithDuration:0.2 animations:^{
        cardView.overlay.alpha = 0.5;
    } completion:^(BOOL finished) {
        [cardView noClickAction];
    }];
    
    
}
- (void)yukPressed:(UIButton *)sender {
    RestaurantCardView *cardView = [self.loadedRestaurants firstObject];
    [self swipedDownWithCard:cardView];
    [cardView.overlay updateMode:RestaurantCardViewOverlayModeLeft];
    [UIView animateWithDuration:0.2 animations:^{
        cardView.overlay.alpha = 0.5;
    } completion:^(BOOL finished) {
        CGPoint finishPoint = CGPointMake(self.yukButton.center.x * 2, self.yukButton.center.y + cardView.frame.size.height);
        [UIView animateWithDuration:0.3 animations:^{
            cardView.transform = CGAffineTransformMakeScale(0.01, 0.01);
            cardView.center = finishPoint;
            cardView.alpha = 0;
        } completion:^(BOOL finished) {
            [cardView yukClickAction];
        }];
    }];

}


-(IBAction)holdDown:(UIButton*) sender{
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(self.buttonShrinkRatio,self.buttonShrinkRatio, 1);
                     }
                     completion:^(BOOL finished) {
                     }];
}

-(IBAction)holdRelease:(UIButton *) sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(1.1,1.1, 1);
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.05
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              
                                              sender.layer.transform = CATransform3DMakeScale(1,1, 1);
                                          }
                                          completion:^(BOOL finished) {
                                              // Tag 1: Munch button
                                              // Tag 2: Nope Button
                                              // Tag 3: Yuk Button
                                              if(sender.tag == 1){
                                                  [self munchNowPressed:sender];
                                              } else if (sender.tag == 2) {
                                                  [self noPressed:sender];
                                              } else if (sender.tag == 3) {
                                                  [self yukPressed:sender];
                                              }
                                          }];
                     }];
}

-(IBAction)holdReleaseOutside:(UIButton *)sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(1.1,1.1, 1);
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.05
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              sender.layer.transform = CATransform3DMakeScale(1,1, 1);
                                          }
                                          completion:^(BOOL finished) {
                                              //dont run segue
                                          }];
                     }];
}
// This is so that when there are no items left we cannot press a button and crash the app
-(void)checkButtons {
    if (!self.loadedRestaurants.count) {
        self.yukButton.enabled = NO;
        self.nopeButton.enabled = NO;
        self.munchNowButton.enabled = NO;
    } else {
        self.yukButton.enabled = YES;
        self.nopeButton.enabled = YES;
        self.munchNowButton.enabled = YES;
    }
}

#pragma mark - RestaurantCardViewDelegate Methods -

#warning incomplete - this is where the action should be set
-(void)swipedRightWithCard:(UIView *)card {
    
    // Load the next card
    [self loadNextCard];
    
    //Save the Restaurant
    [self saveRestaurant];
    
    // Go to detailed view of restaurant
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(cardClickedToPerformSegue)
                                   userInfo:nil
                                    repeats:NO];
}

-(void)swipedLeftWithCard:(UIView *)card {
    // Load the next card
    [self loadNextCard];
    
    // Do action
}

#warning incomplete - yuck action needs to be implemented
-(void)swipedDownWithCard:(UIView *)card {
    // Load the next card
    [self loadNextCard];
    
    // Yuck action
    // Add it to list of yucks
    
}

-(void) saveRestaurant {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    Restaurant *res = [NSEntityDescription insertNewObjectForEntityForName:@"Restaurant" inManagedObjectContext:self.managedObjectContext];
    
    res.name = self.selected.name;
    res.phoneNumber = self.selected.phoneNumber;
    res.categories = self.selected.categories;
    res.imageURL = self.selected.imageURL;
    res.rating = self.selected.rating;
    res.ratingURL = self.selected.ratingURL;
    res.latitude = self.selected.latitude;
    res.longitude = self.selected.longitude;
    res.address = self.selected.address;
    res.verbalAddress = self.selected.verbalAddress;
    res.distance = [self.selected.distance doubleValue];
    
    NSError *error;
    [self.managedObjectContext save:&error];
    
}

-(void)loadNextCard {
    // Remove the top card
    [self updateSelectedRestaurant ];
    
    [self.loadedRestaurants removeObjectAtIndex:0];
    
    if(self.restaurantLoadedIndex < self.restaurants.count) {
        // If we have more restaurants to load
        [self.loadedRestaurants addObject:[self.restaurants objectAtIndex:self.restaurantLoadedIndex]];
        self.restaurantLoadedIndex += 1;
        
        // Add the view and set it up
        [self insertSubview:[self.loadedRestaurants objectAtIndex:MAX_BUFFER_SIZE - 1] belowSubview:[self.loadedRestaurants objectAtIndex:MAX_BUFFER_SIZE - 2]];
        [self setupConstraintsForCard:[self.loadedRestaurants objectAtIndex:MAX_BUFFER_SIZE - 1]];
        
        [self layoutIfNeeded];
    }
    else if (self.loadedRestaurants.count == 0) {
        // If we have no more restaurants go get more from the datasource
        [self.delegate getMoreRestaurants];
    }
    // Check to see if the buttons should be enabled or not
    [self checkButtons];

}



-(void)cardClickedToPerformSegue{
    
    [self.delegate receivedRestaurant:self.selected];
    //[self.delegate ]
    [self.delegate performSegueToDetailView];
    

}

-(void)justShowDetails{
    
    [self.delegate justShowDetails];
    
}

-(void)updateSelectedRestaurant{
    self.selected = self.data[self.restaurantLoadedIndex - 3];
    RestaurantCardView *pullImageCard = self.loadedRestaurants[0];
    self.selected.image = pullImageCard.imageView.image;
    self.selected.ratingImage = pullImageCard.ratingImage.image;

}

@end
