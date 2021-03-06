//
//  MunchViewController.m
//  Munch
//
//  Created by Enoch Ng on 2016-05-31.
//  Copyright © 2016 Enoch Ng. All rights reserved.
//

#import "MunchViewController.h"
#import <MapKit/MapKit.h>
#import "YelpClient.h"
#import "Restaurant.h"
#import "AppDelegate.h"
#import "MNCCategory.h"
#import "RestaurantCardFactory.h"
#import "FilterView.h"
#import "UserSettings.h"
#import "TempRestaurant.h"
#import "Filter.h"
#import "DetailViewController.h"
#import "ContainerClassViewController.h"


@interface MunchViewController () <CLLocationManagerDelegate, RestaurantCardFactoryDataSource>


@property (nonatomic) NSMutableArray *restaurants;
@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) CLLocation *lastLocation;

@property (nonatomic) float buttonShrinkRatio;

@property (weak, nonatomic) IBOutlet RestaurantCardFactory *restaurantFactory;

@property (weak, nonatomic) IBOutlet FilterView *filterView;
@property (weak, nonatomic) IBOutlet UIButton *filterTabButton;
@property (weak, nonatomic) IBOutlet UIView *dimView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *filterHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *line1;
@property (weak, nonatomic) IBOutlet UIView *line2;

@property (nonatomic) NSNumber *offset;

@property (nonatomic) Filter *usingFilter;
@property (nonatomic) TempRestaurant *selectedRestaurant;

@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic) BOOL showMunchButton;

@end




@implementation MunchViewController


-(void)viewDidLoad{
    
    self.buttonShrinkRatio = 0.8;

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.managedObjectContext;
    
    //Taylors stuff//
    self.restaurants = [[NSMutableArray alloc] init];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    self.offset = @0;
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.center.x, self.view.center.y * 0.6);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    //Enochs stuff//
//    self.filterView.layer.cornerRadius = 7;
//    self.filterView.layer.shadowRadius = 4;
//    self.filterView.layer.shadowOpacity = 0.2;
//    self.filterView.layer.shadowOffset = CGSizeMake(0.0f, 3.0);

    NSArray *array;
   [self.filterView setUpCategoryArray:array];
    
    self.restaurantFactory.delegate = self;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if([defaults boolForKey:@"dropFilter"]) {
        [self openFilter];
        [defaults setBool:NO forKey:@"dropFilter"];
    }
   
    
}

-(void)viewDidAppear:(BOOL)animated{
    
    //logic to determine view of mode when starting this view
    NSError *error;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"UserSettings"];
    NSArray *userSettingsDataArray = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    UserSettings *userSettings = [userSettingsDataArray firstObject];

    
    self.usingFilter = userSettings.lastFilter;
    
    self.showMunchButton = NO;

}


-(void)viewWillDisappear:(BOOL)animated{
    [self closeFilter];
}

#pragma mark - Button Action & Animation -

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    }
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    
    CLLocation *currentLocation = [locations firstObject];
    
    if (self.lastLocation == nil) {
        self.lastLocation = currentLocation;
        [self loadRestaurantsFromYelp];
    }
//    
//    self.lastLocation = currentLocation;
    
}

-(void) loadRestaurantsFromYelp {
    
    
    [self.spinner startAnimating];
    
    CLGeocoder *coder = [[CLGeocoder alloc] init];
    
    [coder reverseGeocodeLocation:self.lastLocation completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        //get current coordinates. eventually in seperate function to change search results based on filter
        CLPlacemark *place = [placemarks firstObject];
        
        NSDictionary *paramDictionary = [self getParamDictionaryWithPlace:place];
        
        YelpClient *client = [YelpClient new];
        
        //get the data!
        [client getPath:@"search" parameters:paramDictionary
                success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    NSDictionary *objects = responseObject[@"businesses"];
                    [self.restaurants removeAllObjects];
                    for (NSDictionary *restaurant in objects) {
                        
                        //create restaurant objects
                        TempRestaurant *res = [[TempRestaurant alloc] initWithInfo:restaurant];
                        
                        [self.restaurants addObject:res];
                        
                    }
                    [self.restaurantFactory resetCardsWithData:self.restaurants];
                    self.offset = @([self.offset integerValue] + self.restaurants.count);
                    
                    if (self.restaurants.count == 0) {
                        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"NO MORE?!"
                                                                                       message:@"It seems we've run out of restaurants to show you! Try changing your categories for new options."
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        
                        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"OK FINE" style:UIAlertActionStyleCancel
                                                                             handler:^(UIAlertAction * action) {}];
                        
                        [alert addAction:cancelAction];
                        
                        [self presentViewController:alert animated:YES completion:nil];

                    }
                    
                    [self.spinner stopAnimating];
                }
                failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Oops!"
                                                                                   message:@"It seems the restaurants didn't load properly! Did you want to try again?"
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    
                    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel
                                                                          handler:^(UIAlertAction * action) {}];
                    
                    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"YES" style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {
                                                                      
                                                                          [self loadRestaurantsFromYelp];
                                                                      
                                                                      }];

                    [alert addAction:cancelAction];
                    [alert addAction:yesAction];
                    
                    [self presentViewController:alert animated:YES completion:nil];
                }];
    }];
}

-(NSDictionary *) getParamDictionaryWithPlace:(CLPlacemark *)place {
    
    //Get Current Lat & Long//
    NSString *lat = [NSString stringWithFormat:@"%f",place.location.coordinate.latitude];
    NSString *lon = [NSString stringWithFormat:@"%f",place.location.coordinate.longitude];
    NSString *coord = [NSString stringWithFormat:@"%@,%@", lat, lon ];
    
    //Set up basic parameters
    NSMutableDictionary *paramDictionary = [[NSMutableDictionary alloc] init];
    paramDictionary[@"term"] = @"food,restaurant";
    paramDictionary[@"ll"] = coord;
    paramDictionary[@"offset"] = self.offset;
    
    //If the filter includes categories to search for
    
    self.usingFilter.filterByExclusion = NO;
    if (self.usingFilter.filterByExclusion == NO) {
        NSArray *catArray = [self.usingFilter.pickedCategories allObjects];
        
        NSMutableArray *searchableCats = [NSMutableArray new];
        for (MNCCategory *cat in catArray) {
            [searchableCats addObject:cat.searchString];
        }
        NSString *catString = [searchableCats componentsJoinedByString:@","];
        paramDictionary[@"category_filter"] = catString;
    }
    
    return paramDictionary;
}

- (IBAction)pressedFilterTab:(UIButton *)sender {
    
    if(self.filterHeightConstraint.constant == 0.0){
        
        [self openFilter];
        
    } else {
        
        [self closeFilter];
        [self loadRestaurantsFromYelp];
    }
}

//CLOSE FILTER FUNCTION
-(void)closeFilter{
    
    
    self.filterHeightConstraint.constant = 0.0;
    
    [UIView animateWithDuration:0.7
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.dimView.alpha = 0.0;
                         self.line1.alpha = 0.0;
                         self.line2.alpha = 0.0;
                     }
                     completion:^(BOOL finished) {
                         
                     }];

   [UIView animateWithDuration:0.7
                      delay:0
                    options:UIViewAnimationOptionCurveEaseInOut
                 animations:^{
                     [self.view layoutIfNeeded];
                 }
                 completion:^(BOOL finished) {
                     
                 }];
    
    self.offset = @0;
    
}

-(void)openFilter{
    self.filterHeightConstraint.constant = self.view.frame.size.height * 0.8;
    
    [UIView animateWithDuration:0.7
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.dimView.alpha = 0.2;
                         self.line1.alpha = 1.0;
                         self.line2.alpha = 1.0;
                         
                     }
                     completion:^(BOOL finished) {
                         
                     }];
    
    [UIView animateWithDuration:0.7
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self.view layoutIfNeeded];
                     }
                     completion:^(BOOL finished) {
                         
                     }];

}


#pragma mark - RestaurantCardFactoryDatasource methods -

-(void)getMoreRestaurants {
        [self loadRestaurantsFromYelp];
}



//DIM TOUCH CLOSES FILTER
-(void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event //here enable the touch
{
    UITouch *touch = [[event allTouches] anyObject];
    
    CGPoint touchLocation = [touch locationInView:self.view];
    if (self.filterHeightConstraint.constant > 0) {
        if (CGRectContainsPoint(self.dimView.frame, touchLocation))
        {
            [self closeFilter];
            [self loadRestaurantsFromYelp];
        }
    }
    
}

-(void)performSegueToDetailView{
    
    [self performSegueWithIdentifier:@"munchToDetailView" sender:self];
    
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
    if([segue.identifier isEqualToString:@"munchToDetailView"]){
        
        ContainerClassViewController *CCVC = (ContainerClassViewController *)segue.destinationViewController;
        
        CCVC.lastLocation = self.lastLocation;
        CCVC.receivedRestaurant = self.selectedRestaurant;
        CCVC.showMunchNowButton = self.showMunchButton;
        
    }
    
}

-(void)receivedRestaurant:(TempRestaurant *)tempRestaurant;{
    
    self.selectedRestaurant = tempRestaurant;
    
}

-(void)justShowDetails{
     self.showMunchButton = YES;

}

@end
